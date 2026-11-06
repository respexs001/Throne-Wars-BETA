"""Exercise the packaged runtime from an extracted ZIP, without the editor."""
from pathlib import Path
import argparse,os,subprocess,tempfile,zipfile,json,time,hashlib
ROOT=Path(__file__).resolve().parents[1]
def main():
 ap=argparse.ArgumentParser();ap.add_argument('archive',type=Path);ap.add_argument('--report-dir',type=Path,default=ROOT/'artifacts/windows-runtime');ap.add_argument('--benchmark',action='store_true');a=ap.parse_args()
 a.report_dir.mkdir(parents=True,exist_ok=True);a.report_dir=a.report_dir.resolve()
 with tempfile.TemporaryDirectory(prefix='thronewars-runtime-') as tmp:
  temp=Path(tmp)
  with zipfile.ZipFile(a.archive) as package:
   for name in package.namelist():
    if not (temp/name).resolve().is_relative_to(temp.resolve()):raise RuntimeError('Invalid ZIP path')
   package.extractall(temp)
  exes=list(temp.rglob('ThroneWars.exe'))
  if len(exes)!=1:raise RuntimeError('Expected one game executable')
  exe=exes[0];env=os.environ.copy();env.update(APPDATA=str(temp/'data'),XDG_DATA_HOME=str(temp/'data'),XDG_CONFIG_HOME=str(temp/'data'),THRONE_WARS_TEST='1')
  manifest=json.loads((exe.parent/'manifest.json').read_text(encoding='utf-8'))
  exe_sha256=hashlib.file_digest(exe.open('rb'),'sha256').hexdigest()
  if exe_sha256!=manifest['sha256_exe']:raise RuntimeError('Executable does not match manifest')
  log=a.report_dir/'packaged-core.log';data=a.report_dir/'packaged-result.json';data.unlink(missing_ok=True);start=time.monotonic()
  try:
   cmd=[str(exe),'--audio-driver','Dummy','--log-file',log.as_posix()]
   cmd+=['--','--benchmark-runtime'] if a.benchmark else ['--headless','--fixed-fps','60','--','--verify-runtime']
   result=subprocess.run(cmd,cwd=exe.parent,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=240 if a.benchmark else 120,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
  except subprocess.TimeoutExpired as error:
   result=subprocess.CompletedProcess(error.cmd,-1,stdout=b'Runtime verification timed out')
  reports=list((temp/'data').rglob('runtime-benchmark.json' if a.benchmark else 'runtime-verification.json'))
  if len(reports)==1:data.write_bytes(reports[0].read_bytes())
  text=log.read_text(encoding='utf-8',errors='replace') if log.exists() else result.stdout.decode(errors='replace')
  errors=[line for line in text.splitlines() if 'SCRIPT ERROR:' in line or line.startswith('ERROR:')]
  runtime=json.loads(data.read_text(encoding='utf-8')) if data.exists() else {'passed':False,'errors':['Runtime did not produce verification report']}
  if runtime.get('version')!=manifest['version']:runtime['errors'].append('Runtime and manifest versions differ')
  errors+=runtime['errors'];ok=result.returncode==0 and not errors and runtime['passed']
  report={'passed':ok,'exit':result.returncode,'wall_seconds':round(time.monotonic()-start,2),'editor_used':False,'data_isolated':True,'errors':errors,'archive':a.archive.name,'exe_sha256':exe_sha256,'source_sha256':manifest['source_sha256'],'benchmark':a.benchmark,'runtime':runtime}
  (a.report_dir/'summary.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps(report));return 0 if ok else 1
if __name__=='__main__':raise SystemExit(main())
