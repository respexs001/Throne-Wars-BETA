"""Build an installable experimental APK in an isolated editor/data directory."""
from pathlib import Path
import argparse,os,shutil,tempfile,subprocess,json,hashlib,re
ROOT=Path(__file__).resolve().parents[1]
VERSION=re.search(r'const VERSION: String = "([^"]+)"',(ROOT/'scripts/AppVersion.gd').read_text(encoding='utf-8')).group(1)
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--godot',type=Path,required=True);ap.add_argument('--templates',type=Path,required=True);ap.add_argument('--sdk',type=Path,required=True);ap.add_argument('--java',type=Path,required=True);ap.add_argument('--keystore',type=Path,required=True);ap.add_argument('--output',type=Path,default=ROOT/'build/android');a=ap.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=True);(out/'.gdignore').touch()
 key=a.keystore.resolve();key.parent.mkdir(parents=True,exist_ok=True)
 # This is a test certificate, not a production signing identity. Never publish its key.
 if not key.exists():
  subprocess.run([str(a.java/'bin'/('keytool.exe' if os.name=='nt' else 'keytool')),'-genkeypair','-keystore',str(key),'-storepass','android','-keypass','android','-alias','androiddebugkey','-dname','CN=Throne Wars Alpha Test','-keyalg','RSA','-keysize','2048','-validity','10000'],check=True,capture_output=True)
 with tempfile.TemporaryDirectory(prefix='thronewars-android-') as temp:
  temp=Path(temp);stage=temp/'source';stage.mkdir();data=temp/'data';settings=data/('Godot' if os.name=='nt' else 'godot');settings.mkdir(parents=True)
  for directory in ['scripts','scenes','Shaders','assets','ui']:
   if (ROOT/directory).exists():shutil.copytree(ROOT/directory,stage/directory)
  for name in ['project.godot','export_presets.cfg','icon.svg','icon.svg.import']:shutil.copy2(ROOT/name,stage/name)
  preset=(stage/'export_presets.cfg').read_text(encoding='utf-8');head,android=preset.split('[preset.3.options]',1)
  android=android.replace('custom_template/debug=""','custom_template/debug="'+(a.templates/'android_debug.apk').resolve().as_posix()+'"',1)
  android=android.replace('architectures/x86_64=false','architectures/x86_64=true').replace('version/name="1.0.2"',f'version/name="{VERSION}"').replace('version/code=3','version/code=100302').replace('com.thronewars.game','com.thronewars.alpha')
  preset=head+'[preset.3.options]'+android
  preset=preset.replace('exclude_filter="*.md,*.txt"','exclude_filter="*.md,*.txt,tests/*,tools/*,.github/*,docs/*"')
  (stage/'export_presets.cfg').write_text(preset,encoding='utf-8')
  config='[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
  for name,value in [('android_sdk_path',a.sdk.resolve().as_posix()),('java_sdk_path',a.java.resolve().as_posix()),('debug_keystore',key.as_posix()),('debug_keystore_user','androiddebugkey'),('debug_keystore_pass','android')]:config+=f'export/android/{name} = "{value}"\n'
  (settings/'editor_settings-4.7.tres').write_text(config,encoding='utf-8')
  env=os.environ.copy();env.update(APPDATA=str(data),XDG_CONFIG_HOME=str(data),XDG_DATA_HOME=str(data),JAVA_HOME=str(a.java.resolve()),ANDROID_HOME=str(a.sdk.resolve()))
  common=[str(a.godot.resolve()),'--headless','--audio-driver','Dummy','--path',str(stage)]
  apk=out/f'ThroneWars-{VERSION}-android-test.apk'
  for name,args in [('import',['--editor','--import','--quit']),('export',['--export-debug','Android',str(apk)])]:
   result=subprocess.run(common+args,env=env,capture_output=True,timeout=240)
   text=(result.stdout+result.stderr).decode('utf-8',errors='replace');(out/(name+'.log')).write_text(text,encoding='utf-8')
   if result.returncode or 'ERROR:' in text:raise RuntimeError(text[-6000:])
 manifest={'version':VERSION,'platform':'android-arm64-and-x86_64','package':'com.thronewars.alpha','signing':'test certificate; not a store release','sha256':hashlib.file_digest(apk.open('rb'),'sha256').hexdigest(),'user_data_included':False}
 (out/'manifest.json').write_text(json.dumps(manifest,indent=2));print(json.dumps(manifest))
if __name__=='__main__':main()
