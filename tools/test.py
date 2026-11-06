"""Godot test driver. Every process has a fresh data directory, never real accounts."""
from pathlib import Path
import argparse,os,subprocess,tempfile,json,time,statistics,concurrent.futures,sys,shutil,hashlib
ROOT=Path(__file__).resolve().parents[1]
def code_fingerprint():
 digest=hashlib.sha256()
 files=[ROOT/'project.godot',ROOT/'tests/autoplay.gd',*sorted((ROOT/'scripts').glob('*.gd')),*sorted((ROOT/'Shaders').glob('*.gdshader'))]
 for path in files:
  digest.update(path.relative_to(ROOT).as_posix().encode()+b'\0');digest.update(path.read_bytes().replace(b'\r\n',b'\n'))
 return digest.hexdigest()
def execute(godot,script=None,args=(),timeout=600,case='test',report_dir=None,import_only=False):
 report_dir=report_dir or ROOT/'artifacts/validation';report_dir.mkdir(parents=True,exist_ok=True)
 log=report_dir/(case+'.log');data=report_dir/(case+'.json')
 log.unlink(missing_ok=True);data.unlink(missing_ok=True);signature=code_fingerprint()
 with tempfile.TemporaryDirectory(prefix='thronewars-test-') as temp:
  env=os.environ.copy();env.update(APPDATA=temp,XDG_DATA_HOME=temp,XDG_CONFIG_HOME=temp,THRONE_WARS_TEST='1')
  cmd=[str(godot),'--headless','--audio-driver','Dummy','--path',str(ROOT),'--log-file',str(log)]
  if import_only:cmd+=['--editor','--import','--quit']
  else:cmd+=['--fixed-fps','60','--script','res://tests/'+script]
  if args:cmd+=['--',*args,'--output='+data.as_posix()]
  started=time.monotonic()
  try:
   result=subprocess.run(cmd,env=env,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=timeout,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
   text=log.read_text(encoding='utf-8',errors='replace') if log.exists() else result.stdout.decode(errors='replace')
   # The auth negative test intentionally loads one corrupt ConfigFile.
   errors=[line for line in text.splitlines() if ('SCRIPT ERROR:' in line or line.startswith('ERROR:')) and not (script=='auth.gd' and 'ConfigFile parse error' in line)]
   if code_fingerprint()!=signature:errors.append('Game source changed while the case was running')
   ok=result.returncode==0 and not errors and (import_only or 'PASS:' in text or 'RESULT ' in text)
   return {'case':case,'ok':ok,'exit':result.returncode,'wall_seconds':round(time.monotonic()-started,2),'code_sha256':signature,'errors':errors,'report':json.loads(data.read_text()) if data.exists() else None}
  except subprocess.TimeoutExpired:
   return {'case':case,'ok':False,'wall_seconds':round(time.monotonic()-started,2),'errors':['Process timed out'], 'report':None}
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--godot',default=os.environ.get('GODOT_BIN') or shutil.which('godot') or shutil.which('godot.exe'))
 ap.add_argument('--suite',choices=['core','balance','stress','acceptance'],default='core');ap.add_argument('--workers',type=int,default=3);ap.add_argument('--count',type=int,default=20);ap.add_argument('--report-dir',type=Path,default=ROOT/'artifacts/validation');a=ap.parse_args()
 if not a.godot:ap.error('Pass --godot or set GODOT_BIN')
 a.report_dir.mkdir(parents=True,exist_ok=True);results=[]
 if a.report_dir.resolve().is_relative_to((ROOT/'artifacts').resolve()):(ROOT/'artifacts/.gdignore').touch(exist_ok=True)
 result=execute(a.godot,case='clean-import',report_dir=a.report_dir,import_only=True,timeout=120);results.append(result);print(json.dumps(result),flush=True)
 if not result['ok']:return 1
 if a.suite in ['core','acceptance']:
  for case in ['auth','core','lifetime','heroes','tutorial','siege']:
   r=execute(a.godot,case+'.gd',case=case,report_dir=a.report_dir,timeout=120);results.append(r);print(json.dumps(r),flush=True)
   if not r['ok']:break
 if all(r['ok'] for r in results) and a.suite in ['balance','acceptance']:
  def match(seed):return execute(a.godot,'autoplay.gd',[f'--seed={seed}','--seconds=1200'],case=f'match-{seed:02}',report_dir=a.report_dir,timeout=900)
  with concurrent.futures.ThreadPoolExecutor(max_workers=max(1,min(a.workers,4))) as pool:
   futures={pool.submit(match,i):i for i in range(1,a.count+1)}
   for f in concurrent.futures.as_completed(futures):
    r=f.result();results.append(r);print(json.dumps(r),flush=True)
 if all(r['ok'] for r in results) and a.suite in ['stress','acceptance']:
  r=execute(a.godot,'autoplay.gd',['--mode=stress','--seconds=1800','--seed=4'],case='stress-30min',report_dir=a.report_dir,timeout=1200);results.append(r);print(json.dumps(r),flush=True)
 matches=[r['report'] for r in results if r['case'].startswith('match-') and r['report']]
 pace=None
 if matches:
  finished=sum(m['finished'] and m['seconds']<1200 for m in matches);median=statistics.median(m['seconds'] for m in matches)
  pace={'count':len(matches),'completed_before_20min':finished,'median_seconds':median,'gate_passed':len(matches)>=20 and finished>=18 and 600<=median<=900}
 runtime_ok=all(r['ok'] for r in results)
 pacing_ok=a.suite not in ['balance','acceptance'] or bool(pace and pace['gate_passed'])
 summary={'suite':a.suite,'cases':results,'pacing':pace,'runtime_checks_passed':runtime_ok,'automatic_checks_passed':runtime_ok and pacing_ok,'external_player_tests':'not performed','public_binary_release_approved':False}
 (a.report_dir/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
 print(json.dumps({k:v for k,v in summary.items() if k!='cases'}),flush=True)
 return 0 if summary['automatic_checks_passed'] else 1
if __name__=='__main__':sys.exit(main())
