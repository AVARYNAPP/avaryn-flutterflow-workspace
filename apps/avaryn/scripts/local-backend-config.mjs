/** Private bridge from an explicitly owned local backend to the official client.
 * No Docker lifecycle, SQL, network request, credential output or remote target. */
import {readFile,lstat,realpath,writeFile,rename,unlink} from 'node:fs/promises';
import {resolve,dirname,basename,join,sep} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash,createHmac,timingSafeEqual,randomUUID} from 'node:crypto';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
const execute=promisify(execFile);
const PRODUCT_ROOT=fileURLToPath(new URL('../',import.meta.url));
const OWNER='avaryn-route-b-v1',LINEAGE='a-v-a-r-y-n-alpha-ynvyuq';
const SCHEMA='avaryn-product-local-v1';
const SERVICES=['db','mail','auth','rest','storage','realtime','edge','gateway'];
const TARGET=/^avaryn-c010-[a-z0-9][a-z0-9-]{3,45}$/;
const sha=value=>createHash('sha256').update(value).digest('hex');
const fail=code=>{throw Error(code);};
const need=(condition,code)=>{if(!condition)fail(code);};
const errorCode=error=>/^(?:LOCAL|PRODUCT)_[A-Z_]+$/.test(error?.message||'')?error.message:'LOCAL_CONFIG_VALIDATION_FAILED';
const same=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
async function jsonFile(path,{privateFile=false}={}){
 const info=await lstat(path);
 need(info.isFile()&&!info.isSymbolicLink()&&info.size<=1024*1024,'LOCAL_CONFIG_FILE_INVALID');
 if(privateFile)need((info.mode&0o777)===0o600,'LOCAL_CONFIG_MODE_INVALID');
 const bytes=await readFile(path);return {value:JSON.parse(bytes),hash:sha(bytes)};
}
export async function productProvenance(productRoot=PRODUCT_ROOT){
 const root=await realpath(resolve(productRoot)),paths=['package.json','capacitor.config.json','config/release.json'];
 const loaded=await Promise.all(paths.map(async path=>{
  need((await realpath(join(root,path))).startsWith(root+sep),'PRODUCT_SOURCE_PATH_INVALID');
  return jsonFile(join(root,path));
 }));
 const [pkg,cap,release]=loaded.map(x=>x.value);
 need(pkg.name==='@avaryn/client'&&pkg.private===true&&pkg.type==='module','PRODUCT_IDENTITY_INVALID');
 need(cap.appName==='AVARYN'&&cap.webDir==='dist'&&/^[a-zA-Z][\w]*(?:\.[a-zA-Z][\w]*){2,}$/.test(cap.appId||'')&&cap.server?.iosScheme==='capacitor'&&cap.server?.androidScheme==='https'&&!cap.server?.url,'PRODUCT_PLATFORM_INVALID');
 need(/^C010-V8-[A-Z0-9-]{1,140}$/.test(release.candidate||'')&&/^\d+\.\d+\.\d+$/.test(release.version||'')&&release.version===pkg.version&&Number.isSafeInteger(release.buildNumber)&&release.buildNumber>0,'PRODUCT_RELEASE_INVALID');
 return {packageName:pkg.name,applicationId:cap.appId,candidate:release.candidate,files:Object.fromEntries(paths.map((path,i)=>[path,loaded[i].hash]))};
}
function environmentShape(env){
 need(TARGET.test(env.target||'')&&env.owner===OWNER&&env.project_id===LINEAGE,'LOCAL_TARGET_OWNERSHIP_INVALID');
 need(!env.hosted_preview_origin,'LOCAL_HOSTED_TARGET_REFUSED');
 const ports=env.ports;
 need(ports&&same(Object.keys(ports).sort(),['api','db','mail','web'])&&Object.values(ports).every(p=>Number.isSafeInteger(p)&&p>=1024&&p<=65535)&&new Set(Object.values(ports)).size===4,'LOCAL_PORTS_INVALID');
 const key=env.anon_key;
 need(typeof key==='string'&&key.length<4096&&/^[A-Za-z0-9_.-]+$/.test(key)&&typeof env.jwt_secret==='string'&&env.jwt_secret.length>=32,'LOCAL_ANON_KEY_INVALID');
 const parts=key.split('.');need(parts.length===3,'LOCAL_ANON_KEY_INVALID');
 let header,payload;try{header=JSON.parse(Buffer.from(parts[0],'base64url'));payload=JSON.parse(Buffer.from(parts[1],'base64url'));}catch{fail('LOCAL_ANON_KEY_INVALID');}
 need(header.alg==='HS256'&&payload.role==='anon'&&payload.iss==='supabase-local'&&Number.isFinite(payload.exp)&&payload.exp>Date.now()/1000,'LOCAL_ANON_KEY_INVALID');
 const signature=createHmac('sha256',env.jwt_secret).update(parts[0]+'.'+parts[1]).digest(),actual=Buffer.from(parts[2],'base64url');
 need(actual.length===signature.length&&timingSafeEqual(actual,signature),'LOCAL_ANON_KEY_INVALID');
 return env;
}
async function readEnvironment(environmentFile){
 const path=resolve(environmentFile),env=environmentShape((await jsonFile(path,{privateFile:true})).value);
 need(basename(path)==='environment.json'&&basename(dirname(path))===env.target,'LOCAL_STATE_PATH_INVALID');
 const dir=await lstat(dirname(path));need(dir.isDirectory()&&!dir.isSymbolicLink()&&(dir.mode&0o777)===0o700,'LOCAL_STATE_MODE_INVALID');
 return env;
}
async function dockerInspect(names){
 const {stdout}=await execute('docker',['container','inspect',...names],{timeout:10000,maxBuffer:2*1024*1024});
 return JSON.parse(stdout);
}
async function backendFingerprint(env,productRoot,inspectImpl){
 const images=await jsonFile(resolve(productRoot,'../../tool/route_b/images.json'));
 need(images.value.architecture==='arm64','LOCAL_IMAGE_ARCHITECTURE_UNSUPPORTED');
 const objects=await inspectImpl(SERVICES.map(service=>env.target+'-'+service));
 need(Array.isArray(objects)&&objects.length===SERVICES.length,'LOCAL_CONTAINER_COUNT_INVALID');
 const containers=SERVICES.map(service=>{
  const name=env.target+'-'+service,obj=objects.find(o=>o.Name==='/'+name),labels=obj?.Config?.Labels||{};
  need(obj&&/^[a-f0-9]{64}$/.test(obj.Id||'')&&/^sha256:[a-f0-9]{64}$/.test(obj.Image||'')&&obj.State?.Running===true,'LOCAL_CONTAINER_IDENTITY_INVALID');
  need(labels['io.avaryn.local.owner']===OWNER&&labels['io.avaryn.local.target']===env.target&&labels['io.avaryn.local.project']===LINEAGE&&obj.Config.Image===images.value[service],'LOCAL_CONTAINER_OWNERSHIP_INVALID');
  const hc=obj.HostConfig;
  need(hc&&hc.NetworkMode===env.target&&!hc.Privileged&&!hc.PublishAllPorts&&same(Object.keys(obj.NetworkSettings?.Networks||{}),[env.target]),'LOCAL_CONTAINER_NETWORK_INVALID');
  const spec={db:['5432/tcp','db'],mail:['8025/tcp','mail'],gateway:['8000/tcp','api']}[service];
  const expected=spec?{[spec[0]]:[{HostIp:'127.0.0.1',HostPort:String(env.ports[spec[1]])}]}:{};
  const actual=Object.fromEntries(Object.entries(obj.NetworkSettings?.Ports||{}).filter(([,v])=>v?.length));
  need(same(hc.PortBindings||{},expected)&&same(actual,expected),'LOCAL_CONTAINER_PORTS_INVALID');
  return {service,id:obj.Id,image:obj.Image};
 });
 return {imageManifestSha256:images.hash,containers};
}
export async function createProductConfig(environmentFile,{productRoot=PRODUCT_ROOT,inspectImpl=dockerInspect}={}){
 const env=await readEnvironment(environmentFile),product=await productProvenance(productRoot);
 const backend=await backendFingerprint(env,productRoot,inspectImpl);
 return {schema:SCHEMA,projectId:env.target,upstream:`http://127.0.0.1:${env.ports.api}`,origin:`http://127.0.0.1:${env.ports.web}`,anonKey:env.anon_key,allowAuthRegistration:true,product,backend};
}
export async function loadDevelopmentConfig(path,{origin,release,productRoot=PRODUCT_ROOT,inspectImpl=dockerInspect}={}){
 try{
 const config=(await jsonFile(resolve(path),{privateFile:true})).value;
 if(config.schema===SCHEMA){
  const expected=await createProductConfig(join(dirname(resolve(path)),'environment.json'),{productRoot,inspectImpl});
  need(same(config,expected),'LOCAL_CONFIG_FINGERPRINT_MISMATCH');
  need(config.origin===origin&&release?.candidate===config.product.candidate&&release.demo===false&&release.apiBase==='/api','LOCAL_CLIENT_BINDING_MISMATCH');
 }else{
  need(!config.schema,'LOCAL_CONFIG_SCHEMA_INVALID');
  const url=new URL(config.upstream),targets={'avaryn-c010-rc-20260908-a':['56581'],'avaryn-c010-vitality-20260911-a':['56801']};
  need(url.hostname==='127.0.0.1'&&url.protocol==='http:'&&!url.username&&!url.password&&!url.search&&!url.hash&&url.pathname==='/'&&targets[config.projectId]?.includes(url.port)&&config.anonKey,'LOCAL_LEGACY_TARGET_INVALID');
 }
 return config;
 }catch(error){throw Error(errorCode(error));}
}
export async function writeProductConfig(environmentFile,options={}){
 const path=resolve(dirname(environmentFile),'product-bff.json'),config=await createProductConfig(environmentFile,options);
 try{const old=(await jsonFile(path,{privateFile:true})).value;need(old.schema===SCHEMA&&old.projectId===config.projectId&&old.upstream===config.upstream&&old.origin===config.origin,'LOCAL_CONFIG_REPLACEMENT_REFUSED');}catch(error){if(error.code!=='ENOENT')throw error;}
 const temporary=path+'.'+randomUUID()+'.tmp';
 try{await writeFile(temporary,JSON.stringify(config,null,2)+'\n',{mode:0o600,flag:'wx'});await rename(temporary,path);}finally{await unlink(temporary).catch(error=>{if(error.code!=='ENOENT')throw error;});}
 return {status:'PASS',configWritten:true};
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{
  const args=process.argv.slice(2);
  if(args.length===1&&args[0]==='--provenance-only')console.log(JSON.stringify(await productProvenance()));
  else{need(args.length===2&&args[0]==='--environment','LOCAL_CONFIG_ARGUMENTS_INVALID');console.log(JSON.stringify(await writeProductConfig(args[1])));}
 }catch(error){console.error(errorCode(error));process.exitCode=1;}
}
