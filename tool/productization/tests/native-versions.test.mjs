import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile,mkdtemp,mkdir,writeFile,rm,stat,symlink} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {planNativeVersions,syncNativeVersions} from '../../../apps/avaryn/scripts/sync-native-versions.mjs';
const root=fileURLToPath(new URL('../../../apps/avaryn/',import.meta.url));
const paths={release:'config/release.json',android:'android/app/build.gradle',ios:'ios/App/App.xcodeproj/project.pbxproj',plist:'ios/App/App/Info.plist'};
const base={release:{version:'0.10.8',buildNumber:2},android:await readFile(join(root,paths.android),'utf8'),ios:await readFile(join(root,paths.ios),'utf8'),plist:await readFile(join(root,paths.plist),'utf8')};
base.android=base.android.replace(/versionCode \d+/,'versionCode 1').replace(/versionName "[\d.]+"/,'versionName "1.0"');
base.ios=base.ios.replace(/CURRENT_PROJECT_VERSION = \d+;/g,'CURRENT_PROJECT_VERSION = 1;').replace(/MARKETING_VERSION = [\d.]+;/g,'MARKETING_VERSION = 1.0;');
const maskAndroid=s=>s.replace(/(versionCode )\d+/g,'$1#').replace(/(versionName ")[\d.]+/g,'$1#');
const maskIos=s=>s.replace(/(CURRENT_PROJECT_VERSION = )\d+/g,'$1#').replace(/(MARKETING_VERSION = )[\d.]+/g,'$1#');
async function fixture(t,input=base){
 const temp=await mkdtemp(join(tmpdir(),'avaryn-native-versions-'));t.after(()=>rm(temp,{recursive:true,force:true}));
 for(const [key,path] of Object.entries(paths)){await mkdir(dirname(join(temp,path)),{recursive:true});await writeFile(join(temp,path),key==='release'?JSON.stringify(input.release):input[key]);}
 return temp;
}
test('real native scaffold receives version and build in Android and both iOS app configurations',()=>{
 const p=planNativeVersions(base);assert.match(p.android,/versionCode 2\b/);assert.match(p.android,/versionName "0\.10\.8"/);assert.equal([...p.ios.matchAll(/MARKETING_VERSION = 0\.10\.8;/g)].length,2);assert.equal([...p.ios.matchAll(/CURRENT_PROJECT_VERSION = 2;/g)].length,2);
 assert.equal(maskAndroid(p.android),maskAndroid(base.android));assert.equal(maskIos(p.ios),maskIos(base.ios));
});
test('successive release values are read from metadata instead of hardcoded 0.10.8/build2',()=>{
 const p=planNativeVersions({...base,release:{version:'0.11.2',buildNumber:17}});assert.match(p.android,/versionCode 17\b/);assert.match(p.android,/versionName "0\.11\.2"/);assert.equal([...p.ios.matchAll(/MARKETING_VERSION = 0\.11\.2;/g)].length,2);assert.equal([...p.ios.matchAll(/CURRENT_PROJECT_VERSION = 17;/g)].length,2);
});
for(const version of ['1.0','0.10.8-beta','01.2.3','1.2.3; bad','1.2.3\n',null])test('invalid marketing version is refused: '+JSON.stringify(version),()=>assert.throws(()=>planNativeVersions({...base,release:{...base.release,version}}),/NATIVE_VERSION_INVALID/));
for(const buildNumber of [0,-1,1.5,'2',2100000001,null])test('invalid build number is refused: '+JSON.stringify(buildNumber),()=>assert.throws(()=>planNativeVersions({...base,release:{...base.release,buildNumber}}),/NATIVE_BUILD_NUMBER_INVALID/));
test('check mode detects stale metadata without modifying any input',async t=>{
 const f=await fixture(t),before=await Promise.all(Object.values(paths).map(p=>readFile(join(f,p),'utf8')));await assert.rejects(syncNativeVersions({root:f,check:true}),/NATIVE_VERSION_STALE/);assert.deepEqual(await Promise.all(Object.values(paths).map(p=>readFile(join(f,p),'utf8'))),before);
});
test('actual file sync is repeatable, read-only inputs stay identical and an already-current run does not rewrite',async t=>{
 const f=await fixture(t),release=await readFile(join(f,paths.release)),plist=await readFile(join(f,paths.plist));
 const first=await syncNativeVersions({root:f});assert.deepEqual(first.changedFiles,[paths.android,paths.ios]);assert.equal(first.status,'SYNCED');
 const time=await stat(join(f,paths.ios));assert.equal((await syncNativeVersions({root:f})).status,'CURRENT');assert.equal((await stat(join(f,paths.ios))).mtimeMs,time.mtimeMs);assert.equal((await syncNativeVersions({root:f,check:true})).status,'CURRENT');assert.deepEqual(await readFile(join(f,paths.release)),release);assert.deepEqual(await readFile(join(f,paths.plist)),plist);
});
test('unrecognized iOS version binding fails before Android is written',async t=>{
 const input={...base,plist:base.plist.replace('$(MARKETING_VERSION)','1.0')},f=await fixture(t,input);await assert.rejects(syncNativeVersions({root:f}),/NATIVE_PLIST_VERSION_BINDING_CHANGED/);assert.equal(await readFile(join(f,paths.android),'utf8'),base.android);
});
test('duplicate Android version source or expression fails closed',()=>{
 for(const android of [base.android+'\nversionCode 99\n',base.android.replace('versionCode 1','versionCode computeVersion()'),base.android.replace('versionName "1.0"','versionName VERSION_FROM_ELSEWHERE')])assert.throws(()=>planNativeVersions({...base,android}),/NATIVE_.*(?:SHAPE|CONFIG)_CHANGED/);
});
test('missing iOS app configuration or duplicate version field fails closed',()=>{
 for(const ios of [base.ios.replace('INFOPLIST_FILE = App/Info.plist;','INFOPLIST_FILE = Different/Info.plist;'),base.ios.replace('MARKETING_VERSION = 1.0;','MARKETING_VERSION = 1.0;\n                MARKETING_VERSION = 9.0;')])assert.throws(()=>planNativeVersions({...base,ios}),/NATIVE_.*(?:SHAPE|CONFIG)_CHANGED/);
});
test('version sync does not follow a scaffold file symlink',async t=>{
 const f=await fixture(t),path=join(f,paths.android),copy=join(f,'other.gradle');await writeFile(copy,base.android);await rm(path);await symlink(copy,path);await assert.rejects(syncNativeVersions({root:f}),/NATIVE_VERSION_FILE_INVALID/);assert.equal(await readFile(copy,'utf8'),base.android);
});
test('existing native sync invokes version synchronization first and never needs a dependency install',async()=>{
 const pkg=JSON.parse(await readFile(join(root,'package.json')));assert.equal(pkg.scripts['native:versions'],'node scripts/sync-native-versions.mjs');assert.equal(pkg.scripts['native:sync'],'npm run native:versions && cap sync');
});
