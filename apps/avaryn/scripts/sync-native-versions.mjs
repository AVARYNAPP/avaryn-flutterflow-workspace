/** Synchronize only native version fields; identifiers, signing and assets stay intact. */
import {readFile,writeFile,lstat,realpath} from 'node:fs/promises';
import {resolve,join,sep} from 'node:path';
import {fileURLToPath} from 'node:url';
const ROOT=fileURLToPath(new URL('../',import.meta.url));
const FILES={release:'config/release.json',android:'android/app/build.gradle',ios:'ios/App/App.xcodeproj/project.pbxproj',plist:'ios/App/App/Info.plist'};
const need=(condition,code)=>{if(!condition)throw Error(code);};
function replaceOne(source,pattern,value){
 need([...source.matchAll(pattern)].length===1,'NATIVE_VERSION_SHAPE_CHANGED');
 return source.replace(pattern,(_match,before,after)=>before+value+after);
}
export function planNativeVersions({release,android,ios,plist}){
 need(typeof release?.version==='string'&&release.version.length<=32&&/^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/.test(release.version),'NATIVE_VERSION_INVALID');
 need(Number.isSafeInteger(release.buildNumber)&&release.buildNumber>0&&release.buildNumber<=2100000000,'NATIVE_BUILD_NUMBER_INVALID');
 for(const [key,variable] of [['CFBundleShortVersionString','MARKETING_VERSION'],['CFBundleVersion','CURRENT_PROJECT_VERSION']]){
  const pattern=new RegExp(`<key>${key}</key>\\s*<string>\\$\\(${variable}\\)</string>`,'g');
  need([...plist.matchAll(pattern)].length===1,'NATIVE_PLIST_VERSION_BINDING_CHANGED');
 }
 const defaultBlock=/^([ \t]+)defaultConfig\s*\{\r?\n([\s\S]*?)^\1\}/gm;
 need([...android.matchAll(defaultBlock)].length===1,'NATIVE_ANDROID_CONFIG_CHANGED');
 const androidNext=android.replace(defaultBlock,block=>{
  let next=replaceOne(block,/^([ \t]*versionCode[ \t]+)\d+([ \t]*\r?)$/gm,String(release.buildNumber));
  return replaceOne(next,/^([ \t]*versionName[ \t]+["'])\d+(?:\.\d+){0,2}(["'][ \t]*\r?)$/gm,release.version);
 });
 // Refuse a second version source outside the known defaultConfig as well.
 need([...android.matchAll(/^\s*versionCode\s+/gm)].length===1&&[...android.matchAll(/^\s*versionName\s+/gm)].length===1,'NATIVE_ANDROID_CONFIG_CHANGED');
 const names=[];
 const iosNext=ios.replace(/^([ \t]+)[A-Fa-f0-9]{24} \/\* (Debug|Release) \*\/ = \{\r?\n([\s\S]*?)^\1\};/gm,(block,_indent,name)=>{
  if(!/INFOPLIST_FILE = App\/Info\.plist;/.test(block))return block;
  need([...block.matchAll(/PRODUCT_BUNDLE_IDENTIFIER = [^;]+;/g)].length===1,'NATIVE_IOS_CONFIG_CHANGED');
  names.push(name);
  let next=replaceOne(block,/^([ \t]*CURRENT_PROJECT_VERSION = )\d+(;[ \t]*\r?)$/gm,String(release.buildNumber));
  return replaceOne(next,/^([ \t]*MARKETING_VERSION = )\d+(?:\.\d+){0,2}(;[ \t]*\r?)$/gm,release.version);
 });
 need(names.length===2&&new Set(names).size===2,'NATIVE_IOS_CONFIG_CHANGED');
 need([...ios.matchAll(/^\s*MARKETING_VERSION = /gm)].length===2&&[...ios.matchAll(/^\s*CURRENT_PROJECT_VERSION = /gm)].length===2,'NATIVE_IOS_CONFIG_CHANGED');
 return {version:release.version,buildNumber:release.buildNumber,android:androidNext,ios:iosNext};
}
export async function syncNativeVersions({root=ROOT,check=false}={}){
 root=await realpath(resolve(root));const original={};
 for(const [key,relative] of Object.entries(FILES)){
  const path=join(root,relative),info=await lstat(path);
  need(info.isFile()&&!info.isSymbolicLink()&&(await realpath(path)).startsWith(root+sep),'NATIVE_VERSION_FILE_INVALID');
  original[key]=await readFile(path,'utf8');
 }
 const plan=planNativeVersions({...original,release:JSON.parse(original.release)});
 const changed=['android','ios'].filter(key=>plan[key]!==original[key]);
 if(check)need(changed.length===0,'NATIVE_VERSION_STALE');
 // Check every input before the first write, including release metadata.
 for(const [key,relative] of Object.entries(FILES))need(await readFile(join(root,relative),'utf8')===original[key],'NATIVE_VERSION_INPUT_CHANGED');
 if(!check)for(const key of changed)await writeFile(join(root,FILES[key]),plan[key]);
 return {status:changed.length?'SYNCED':'CURRENT',version:plan.version,buildNumber:plan.buildNumber,changedFiles:changed.map(key=>FILES[key])};
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{
  const args=process.argv.slice(2);need(args.length===0||args.length===1&&args[0]==='--check','NATIVE_VERSION_ARGUMENTS_INVALID');
  console.log(JSON.stringify(await syncNativeVersions({check:args.includes('--check')})));
 }catch(error){console.error(/^NATIVE_[A-Z_]+$/.test(error.message)?error.message:'NATIVE_VERSION_SYNC_FAILED');process.exitCode=1;}
}
