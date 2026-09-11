import {build} from 'esbuild';
import {readFile,writeFile,mkdir,readdir,lstat,realpath,rm} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {resolve,relative,join,dirname,basename,isAbsolute,sep} from 'node:path';
import {fileURLToPath} from 'node:url';

const APP_ROOT=fileURLToPath(new URL('../',import.meta.url));
const WORKER_INPUTS=['capacitor.config.json','config/release.json','config/rpc-routes.json','server/worker.js','src/media-path.js'];
const PROVIDERS=['empty-state.js','empty-personas.js','empty-facilities.js'];
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const check=(condition,code)=>{if(!condition)throw Error(code);};
const inside=(parent,child)=>{const path=relative(parent,child);return path===''||(!isAbsolute(path)&&path!=='..'&&!path.startsWith('..'+sep));};
const sorted=values=>[...values].sort();
const same=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
const json=bytes=>JSON.parse(bytes.toString('utf8'));

function publicPath(path){
 if(typeof path!=='string'||path.length>1024||path.split('/').some(part=>!part||part==='.'||part==='..')||/[\\\x00-\x20%]/.test(path))return false;
 if(['index.html','version.json'].includes(path))return true;
 if(/^[A-Za-z][A-Za-z0-9_-]*-[A-Z0-9]{8}\.js$/.test(path)||/^[a-z][a-z0-9-]*\.css$/.test(path))return true;
 return /^assets\/(?:[A-Za-z0-9_-]+\/)*[A-Za-z0-9][A-Za-z0-9_.-]*\.(png|jpe?g|webp|svg|ttf|woff2?|txt)$/i.test(path)&&!/(?:^|\/)(private|config|test|tests|server|secrets|node_modules)(?:\/|$)/i.test(path);
}

// A bounded packaging check, not a claim to discover arbitrary unknown secrets.
// Runtime keys must be supplied by the host, never baked into either bundle.
export function assertNoEmbeddedCredentials(bytes){
 const text=bytes.toString('utf8');
 check(!/-----BEGIN (?:[A-Z ]*PRIVATE KEY)-----|\bsb_(?:secret|publishable)_[A-Za-z0-9_-]{16,}\b|\b(?:re_|sk_live_)[A-Za-z0-9]{20,}\b/.test(text),'EMBEDDED_CREDENTIAL');
 for(const match of text.matchAll(/\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b/g)){
  let claims;try{claims=JSON.parse(Buffer.from(match[0].split('.')[1],'base64url').toString());}catch{continue;}
  check(!claims.role&&!claims.session_id&&!claims.email,'EMBEDDED_AUTH_TOKEN');
 }
}

async function regularFile(path){
 check((await lstat(path)).isFile(),'NON_REGULAR_FILE');
 return readFile(path);
}
async function inventory(root,path=root){
 check((await lstat(path)).isDirectory(),'NON_REGULAR_DIRECTORY');
 const files=[];
 for(const name of await readdir(path)){
  const current=join(path,name),stat=await lstat(current);
  if(stat.isDirectory())files.push(...await inventory(root,current));
  else{check(stat.isFile(),'NON_REGULAR_FILE');files.push(relative(root,current).split(sep).join('/'));}
 }
 return sorted(files);
}
async function guardedInput(appRoot,path){
 const full=join(appRoot,path);
 check(inside(appRoot,await realpath(full)),'INPUT_OUTSIDE_APP');
 return regularFile(full);
}

/** Stage an already-built release. This never builds or changes the client,
 * writes a Site checkout, reads private configuration, or contacts a provider.
 * output must be a NEW directory outside appRoot; no implicit replacements.
 */
export async function packagePilotSite({projectId,output,appRoot=APP_ROOT}={}){
 check(/^appgprj_[0-9a-f]{32}$/.test(projectId||''),'EXACT_PROJECT_ID_REQUIRED');
 check(typeof output==='string'&&output.length>0,'OUTPUT_REQUIRED');
 appRoot=await realpath(resolve(appRoot));
 const requested=resolve(output),parent=await realpath(dirname(requested));
 output=join(parent,basename(requested));
 check(!inside(appRoot,output)&&!inside(output,appRoot),'OUTPUT_OVERLAPS_APP');
 try{await lstat(output);throw Error('OUTPUT_ALREADY_EXISTS');}catch(error){if(error.code!=='ENOENT')throw error;}

 const inputBytes=new Map();
 for(const path of WORKER_INPUTS)inputBytes.set(path,await guardedInput(appRoot,path));
 const release=json(inputBytes.get('config/release.json'));
 check(typeof release.candidate==='string'&&/^C010-[A-Z0-9-]+$/.test(release.candidate),'INVALID_CANDIDATE');
 const clientRoot=join(appRoot,'dist');
 check((await lstat(clientRoot)).isDirectory(),'NON_REGULAR_DIRECTORY');
 const manifestBytes=await regularFile(join(clientRoot,'build-manifest.json')),manifest=json(manifestBytes);
 check(manifest.candidate===release.candidate,'CANDIDATE_MISMATCH');
 check(manifest.demo===false&&manifest.apiBase==='/api','WEB_RELEASE_REQUIRED');
 const isolation=manifest.fixtureIsolation;
 check(isolation?.status==='PASS'&&isolation.mode==='release'&&same(sorted(isolation.providers||[]),sorted(PROVIDERS))&&same(isolation.demoInputs,[]),'FIXTURE_ISOLATION_REQUIRED');
 check(Array.isArray(manifest.files)&&manifest.files.length>0,'MANIFEST_FILES_REQUIRED');
 const paths=manifest.files.map(file=>file.path);
 check(paths.every(publicPath)&&new Set(paths).size===paths.length,'UNSAFE_PUBLIC_PATH');
 check(['index.html','version.json'].every(path=>paths.includes(path))&&paths.some(path=>/^app-[A-Z0-9]{8}\.js$/.test(path)),'CLIENT_ENTRY_REQUIRED');
 check(same(await inventory(clientRoot),sorted([...paths,'build-manifest.json'])),'UNLISTED_CLIENT_FILE');
 const client=new Map();
 for(const entry of manifest.files){
  const bytes=await regularFile(join(clientRoot,entry.path));
  check(Number.isSafeInteger(entry.bytes)&&bytes.length===entry.bytes&&sha(bytes)===entry.sha256,'CLIENT_HASH_MISMATCH');
  if(/\.(?:js|css|html|json|svg|txt)$/.test(entry.path))assertNoEmbeddedCredentials(bytes);
  client.set(entry.path,bytes);
 }
 const version=json(client.get('version.json'));
 check(same(version,{...release,apiBase:'/api',demo:false}),'CLIENT_VERSION_MISMATCH');
 const html=client.get('index.html').toString();
 check(paths.some(path=>/^app-[A-Z0-9]{8}\.js$/.test(path)&&html.includes(`src="${path}"`)),'CLIENT_ENTRY_NOT_REFERENCED');

 // Bundle only the permanent product BFF and its public contract inputs. No
 // development server, credentials, environment file or Node API is bundled.
 const result=await build({absWorkingDir:appRoot,entryPoints:['server/worker.js'],bundle:true,write:false,format:'esm',platform:'browser',target:'es2022',metafile:true,logLevel:'silent'});
 check(same(sorted(Object.keys(result.metafile.inputs).map(path=>relative(appRoot,resolve(appRoot,path)).split(sep).join('/'))),sorted(WORKER_INPUTS)),'UNEXPECTED_WORKER_INPUT');
 check(result.outputFiles.length===1,'UNEXPECTED_WORKER_OUTPUT');
 const worker=Buffer.from(result.outputFiles[0].contents);
 assertNoEmbeddedCredentials(worker);
 for(const [path,bytes]of inputBytes)check(sha(await guardedInput(appRoot,path))===sha(bytes),'SOURCE_CHANGED_DURING_PACKAGING');

 const metadata=Buffer.from(JSON.stringify({project_id:projectId},null,2)+'\n');
 const artifacts=new Map([...client].map(([path,bytes])=>['dist/client/'+path,bytes]));
 artifacts.set('dist/server/index.js',worker);
 artifacts.set('dist/.openai/hosting.json',metadata);
 const receipt={status:'PASS',projectId,candidate:release.candidate,sourceManifestSha256:sha(manifestBytes),clientFiles:client.size,
  sourceInputs:[...inputBytes].map(([path,bytes])=>({path,sha256:sha(bytes)})),
  files:[...artifacts].map(([path,bytes])=>({path,bytes:bytes.length,sha256:sha(bytes)})).sort((a,b)=>a.path.localeCompare(b.path)),
  checks:{releaseOnly:true,sameOriginApi:true,fixtureIsolation:true,allManifestHashes:true,explicitPublicPaths:true,closedWorkerInputSet:true,
   credentialScan:'Known key/private-key/token patterns in all emitted text; no private configuration read.',sourceUnchanged:true},
  runtime:{bindings:['ASSETS'],environment:['APP_ORIGIN','SUPABASE_PUBLISHABLE_KEY'],supabaseProject:'rvymglpkttlfwhqpmupp'},
  publication:'NOT TESTED — staging only; root Site metadata, archive, secrets and deployment are separate.'};
 let owned=false;
 try{
  await mkdir(output);owned=true;
  for(const [path,bytes]of artifacts){await mkdir(dirname(join(output,path)),{recursive:true});await writeFile(join(output,path),bytes,{flag:'wx',mode:0o644});}
  // Receipt deliberately lives outside dist and is not part of the public site.
  await writeFile(join(output,'packaging-receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx',mode:0o600});
  check(sha(await regularFile(join(clientRoot,'build-manifest.json')))===sha(manifestBytes),'SOURCE_CHANGED_DURING_PACKAGING');
  check(same(await inventory(clientRoot),sorted([...paths,'build-manifest.json'])),'SOURCE_CHANGED_DURING_PACKAGING');
  for(const [path,bytes]of client)check(sha(await regularFile(join(clientRoot,path)))===sha(bytes),'SOURCE_CHANGED_DURING_PACKAGING');
  for(const [path,bytes]of inputBytes)check(sha(await guardedInput(appRoot,path))===sha(bytes),'SOURCE_CHANGED_DURING_PACKAGING');
  return receipt;
 }catch(error){if(owned)await rm(output,{recursive:true,force:true});throw error;}
}

if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{
  const args=process.argv.slice(2),allowed=new Set(['--project-id','--output']);
  check(args.length===4&&args.every((value,index)=>index%2!==0||allowed.has(value))&&args[0]!==args[2],'USAGE: --project-id appgprj_<id> --output <new-staging-directory>');
  const options=Object.fromEntries([0,2].map(index=>[args[index],args[index+1]]));
  const receipt=await packagePilotSite({projectId:options['--project-id'],output:options['--output']});
  console.log(JSON.stringify({status:receipt.status,projectId:receipt.projectId,candidate:receipt.candidate,clientFiles:receipt.clientFiles,artifactFiles:receipt.files.length,workerSha256:receipt.files.find(file=>file.path==='dist/server/index.js').sha256}));
 }catch(error){
  // Parser/compiler errors can quote input text. Print only our bounded codes.
  const message=error.message||'';
  console.error(/^[A-Z][A-Z0-9_]+$/.test(message)||message.startsWith('USAGE: --project-id ')?message:'PACKAGING_FAILED');
  process.exitCode=1;
 }
}
