"""Export a clean Windows candidate; never reads the player's APPDATA."""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,tempfile,zipfile
ROOT=Path(__file__).resolve().parents[1]
VERSION='1.0.3-alpha.1'
def run(cmd,env,log):
 r=subprocess.run(cmd,env=env,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=240,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
 text=log.read_text(encoding='utf-8',errors='replace') if log.exists() else r.stdout.decode(errors='replace')
 if r.returncode or 'SCRIPT ERROR:' in text or any(x.startswith('ERROR:') for x in text.splitlines()):raise RuntimeError(text[-10000:])
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--godot',required=True,type=Path);ap.add_argument('--templates',required=True,type=Path);ap.add_argument('--output',type=Path,default=ROOT/'build/windows');a=ap.parse_args()
 for name in ['windows_release_x86_64.exe','windows_debug_x86_64.exe','version.txt']:
  if not (a.templates/name).is_file():ap.error('Missing matching template: '+name)
 if (a.templates/'version.txt').read_text().strip()!='4.7.2.stable':ap.error('Templates must be 4.7.2.stable')
 a.output.mkdir(parents=True,exist_ok=True)
 package=a.output/f'ThroneWars-{VERSION}-candidate';package.mkdir(exist_ok=True)
 with tempfile.TemporaryDirectory(prefix='thronewars-export-') as tmp:
  temp=Path(tmp);stage=temp/'source';stage.mkdir()
  for directory in ['scripts','scenes','Shaders','assets','ui']:
   if (ROOT/directory).exists():shutil.copytree(ROOT/directory,stage/directory)
  for name in ['project.godot','export_presets.cfg','icon.svg','icon.svg.import']:
   if (ROOT/name).exists():shutil.copy2(ROOT/name,stage/name)
  preset=(stage/'export_presets.cfg').read_text(encoding='utf-8')
  preset=preset.replace('custom_template/debug=""','custom_template/debug="'+(a.templates/'windows_debug_x86_64.exe').resolve().as_posix()+'"',1)
  preset=preset.replace('custom_template/release=""','custom_template/release="'+(a.templates/'windows_release_x86_64.exe').resolve().as_posix()+'"',1)
  preset=preset.replace('exclude_filter="*.md,*.txt"','exclude_filter="*.md,*.txt,tests/*,tools/*,.github/*,docs/*"',1)
  # Resource stamping is optional and requires a separately installed rcedit.
  preset=preset.replace('application/modify_resources=true','application/modify_resources=false',1)
  (stage/'export_presets.cfg').write_text(preset,encoding='utf-8')
  env=os.environ.copy();env.update(APPDATA=str(temp/'data'),XDG_DATA_HOME=str(temp/'data'),XDG_CONFIG_HOME=str(temp/'data'))
  common=[str(a.godot.resolve()),'--headless','--audio-driver','Dummy','--path',str(stage)]
  run(common+['--editor','--import','--quit','--log-file',str(a.output/'export-import.log')],env,a.output/'export-import.log')
  exe=package/'ThroneWars.exe'
  run(common+['--export-release','Windows Desktop',str(exe.resolve()),'--log-file',str(a.output/'export.log')],env,a.output/'export.log')
  # Engine itself supplies the complete third-party license inventory.
  helper=stage/'licenses.gd'
  helper.write_text('''extends SceneTree
func _initialize() -> void:
    var path := OS.get_cmdline_user_args()[0]
    var file := FileAccess.open(path, FileAccess.WRITE)
    file.store_string(Engine.get_license_text() + "\\n\\n")
    for name in Engine.get_license_info():
        file.store_string("\\n===== " + name + " =====\\n" + str(Engine.get_license_info()[name]) + "\\n")
    file.store_string("\\nATTRIBUTIONS\\n" + JSON.stringify(Engine.get_copyright_info(), "  "))
    file.close()
    quit()
''',encoding='utf-8')
  run(common+['--script','res://licenses.gd','--log-file',str(a.output/'licenses.log'),'--',str((package/'GODOT_LICENSES.txt').resolve())],env,a.output/'licenses.log')
 for src,dst in [('README_RELEASE.md','README.md'),('RIGHTS.md','RIGHTS.md'),('THIRD_PARTY_NOTICES.md','THIRD_PARTY_NOTICES.md'),('docs/KNOWN_ISSUES.md','KNOWN_ISSUES.md')]:shutil.copy2(ROOT/src,package/dst)
 manifest={'version':VERSION,'status':'candidate-not-approved-for-public-binary-release','godot':'4.7.2.stable','platform':'windows-x86_64','sha256_exe':hashlib.file_digest((package/'ThroneWars.exe').open('rb'),'sha256').hexdigest(),'user_data_included':False,'template_sha256':hashlib.file_digest((a.templates/'windows_release_x86_64.exe').open('rb'),'sha256').hexdigest()}
 (package/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
 archive=a.output/(package.name+'.zip')
 with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  for file in package.iterdir():
   if file.is_file():z.write(file,package.name+'/'+file.name)
 digest=hashlib.file_digest(archive.open('rb'),'sha256').hexdigest()
 (a.output/'SHA256SUMS.txt').write_text(digest+'  '+archive.name+'\n',encoding='utf-8')
 print(json.dumps({'archive':str(archive),'sha256':digest,'manifest':manifest},indent=2))
if __name__=='__main__':main()
