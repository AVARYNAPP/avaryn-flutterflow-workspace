import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,mkdir,writeFile,readFile,rm,chmod,stat,symlink} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join,dirname} from 'node:path';
import {createHmac} from 'node:crypto';
import {productProvenance,createProductConfig,loadDevelopmentConfig,writeProductConfig} from '../../../apps/avaryn/scripts/local-backend-config.mjs';
const services=['db','mail','auth','rest','storage','realtime','edge','gateway'];
const target='avaryn-c010-portable-fixture';
const release={candidate:'C010-V8-SYNTHETIC-FIXTURE-01',version:'0.10.8',buildNumber:1,apiBase:'/api',demo:false};
const origin='http://127.0.0.1:57960';
function key(secret,role='anon'){
 const encode=v=>Buffer.from(JSON.stringify(v)).toString('base64url');
 const body=encode({alg:'HS256',typ:'JWT'})+'.'+encode({role,iss:'supabase-local',exp:Math.floor(Date.now()/1000)+600});
 return body+'.'+createHmac('sha256',secret).update(body).digest('base64url');
}
async function fixture(t){
 const root=await mkdtemp(join(tmpdir(),'avaryn-product-config-'));t.after(()=>rm(root,{recursive:true,force:true}));
 const productRoot=join(root,'apps/avaryn'),state=join(root,'.avaryn-local',target),environmentFile=join(state,'environment.json'),configFile=join(state,'product-bff.json');
 await mkdir(join(productRoot,'config'),{recursive:true});await mkdir(join(root,'tool/route_b'),{recursive:true});await mkdir(state,{recursive:true,mode:0o700});
 const pkg={name:'@avaryn/client',version:'0.10.8',private:true,type:'module'};
 const cap={appName:'AVARYN',appId:'com.mycompany.avarynalpha',webDir:'dist',server:{iosScheme:'capacitor',androidScheme:'https'}};
 const images={architecture:'arm64',...Object.fromEntries(services.map(s=>[s,`example.invalid/${s}@sha256:${'a'.repeat(64)}`]))};
 const env={target,owner:'avaryn-route-b-v1',project_id:'a-v-a-r-y-n-alpha-ynvyuq',ports:{api:57901,db:57902,mail:57904,web:57960},jwt_secret:'synthetic-local-secret-for-tests-only-0123456789'};env.anon_key=key(env.jwt_secret);env.service_key=key(env.jwt_secret,'service_role');env.db_password='synthetic-never-export';
 const save=async(path,value,mode)=>writeFile(path,JSON.stringify(value,null,2)+'\n',mode?{mode}:{});
 await save(join(productRoot,'package.json'),pkg);await save(join(productRoot,'capacitor.config.json'),cap);await save(join(productRoot,'config/release.json'),release);await save(join(root,'tool/route_b/images.json'),images);await save(environmentFile,env,0o600);
 let inspected=0;const objects=services.map((s,i)=>{
  const spec={db:['5432/tcp','db'],mail:['8025/tcp','mail'],gateway:['8000/tcp','api']}[s],ports=spec?{[spec[0]]:[{HostIp:'127.0.0.1',HostPort:String(env.ports[spec[1]])}]}:{};
  return {Name:'/'+target+'-'+s,Id:String(i+1).padStart(64,'0'),Image:'sha256:'+String(i+1).padStart(64,'a'),State:{Running:true},Config:{Image:images[s],Labels:{'io.avaryn.local.owner':env.owner,'io.avaryn.local.target':target,'io.avaryn.local.project':env.project_id}},HostConfig:{NetworkMode:target,Privileged:false,PublishAllPorts:false,PortBindings:ports},NetworkSettings:{Networks:{[target]:{}},Ports:structuredClone(ports)}};
 });
 const options={productRoot,inspectImpl:async names=>{inspected++;assert.deepEqual(names,services.map(s=>target+'-'+s));return structuredClone(objects);}};
 return {root,productRoot,environmentFile,configFile,state,pkg,cap,images,env,objects,options,save,get inspected(){return inspected;},create:()=>createProductConfig(environmentFile,options),write:()=>writeProductConfig(environmentFile,options),load:(extra={})=>loadDevelopmentConfig(configFile,{...options,origin,release,...extra})};
}
test('fresh public product provenance requires no FlutterFlow binding or generated snapshot',async t=>{
 const f=await fixture(t),p=await productProvenance(f.productRoot);assert.equal(p.packageName,'@avaryn/client');assert.equal(p.candidate,release.candidate);assert.deepEqual(Object.keys(p.files),['package.json','capacitor.config.json','config/release.json']);assert.equal(f.inspected,0);await assert.rejects(stat(join(f.root,'.flutterflow')),{code:'ENOENT'});
});
test('config creation and startup recheck all exact containers and export only an anon key',async t=>{
 const f=await fixture(t);await f.write();assert.equal((await stat(f.configFile)).mode&0o777,0o600);const config=await f.load();assert.equal(f.inspected,2);assert.equal(config.upstream,'http://127.0.0.1:57901');assert.equal(config.origin,origin);assert.equal(config.anonKey,f.env.anon_key);const text=await readFile(f.configFile,'utf8');for(const secret of [f.env.jwt_secret,f.env.service_key,f.env.db_password])assert.equal(text.includes(secret),false);assert.equal(config.backend.containers.length,8);
});
for(const [name,mutate] of [
 ['wrong owner',f=>{f.objects[0].Config.Labels['io.avaryn.local.owner']='other';}],
 ['foreign network',f=>{f.objects[0].NetworkSettings.Networks.other={};}],
 ['wildcard publish',f=>{f.objects[0].HostConfig.PortBindings['5432/tcp'][0].HostIp='0.0.0.0';}],
 ['runtime port mismatch',f=>{f.objects[7].NetworkSettings.Ports['8000/tcp'][0].HostPort='59999';}],
 ['extra published port',f=>{f.objects[2].HostConfig.PortBindings['9999/tcp']=[{HostIp:'127.0.0.1',HostPort:'57999'}];}],
 ['privileged container',f=>{f.objects[0].HostConfig.Privileged=true;}],
 ['wrong pinned image',f=>{f.objects[0].Config.Image='unreviewed:latest';}],
 ['stopped service',f=>{f.objects[2].State.Running=false;}],
])test(name+' prevents config output before any server starts',async t=>{const f=await fixture(t);mutate(f);await assert.rejects(f.write(),/LOCAL_CONTAINER_/);await assert.rejects(stat(f.configFile),{code:'ENOENT'});});
test('replaced container identity invalidates an already generated config',async t=>{const f=await fixture(t);await f.write();f.objects[0].Id='f'.repeat(64);await assert.rejects(f.load(),/FINGERPRINT_MISMATCH/);});
test('changed public product source invalidates config until explicit regeneration',async t=>{const f=await fixture(t);await f.write();f.pkg.overrides={xcode:{uuid:'11.1.1'}};await f.save(join(f.productRoot,'package.json'),f.pkg);await assert.rejects(f.load(),/FINGERPRINT_MISMATCH/);await f.write();assert.equal((await f.load()).product.candidate,release.candidate);});
for(const [name,extra] of [['wrong origin',{origin:'http://127.0.0.1:59960'}],['different candidate',{release:{...release,candidate:'C010-V8-DIFFERENT'}}],['demo build',{release:{...release,demo:true}}],['external API build',{release:{...release,apiBase:'https://other.invalid/api'}}]])test(name+' cannot use the product local backend',async t=>{const f=await fixture(t);await f.write();await assert.rejects(f.load(extra),/CLIENT_BINDING_MISMATCH/);});
for(const [name,mutate] of [['service key',f=>{f.env.anon_key=f.env.service_key;}],['bad signature',f=>{f.env.anon_key=key('other-synthetic-secret-value-0123456789');}],['foreign target',f=>{f.env.target='unrelated-project';}],['hosted target',f=>{f.env.hosted_preview_origin='https://other.invalid';}],['overlapping ports',f=>{f.env.ports.web=f.env.ports.api;}]])test(name+' is refused before any Docker inspection',async t=>{const f=await fixture(t);mutate(f);await f.save(f.environmentFile,f.env);await assert.rejects(f.create(),/LOCAL_/);assert.equal(f.inspected,0);});
test('private state and config must be regular private files',async t=>{const f=await fixture(t);await chmod(f.environmentFile,0o644);await assert.rejects(f.write(),/MODE_INVALID/);await chmod(f.environmentFile,0o600);await f.write();await chmod(f.configFile,0o644);await assert.rejects(f.load(),/MODE_INVALID/);await chmod(f.configFile,0o600);await rm(f.configFile);await symlink(f.environmentFile,f.configFile);await assert.rejects(f.write(),/FILE_INVALID/);});
test('arbitrary upstream and unrecognized replacement file are rejected',async t=>{const f=await fixture(t);await f.write();const config=JSON.parse(await readFile(f.configFile));config.upstream='http://127.0.0.1:59999';await f.save(f.configFile,config);await assert.rejects(f.load(),/FINGERPRINT_MISMATCH/);await assert.rejects(f.write(),/REPLACEMENT_REFUSED/);});
test('historical config remains restricted to its two original target-port pairs',async t=>{const f=await fixture(t);const legacy={projectId:'avaryn-c010-vitality-20260911-a',upstream:'http://127.0.0.1:56801',anonKey:'synthetic-public-key'};await f.save(f.configFile,legacy,0o600);assert.equal((await f.load()).projectId,legacy.projectId);assert.equal(f.inspected,0);for(const upstream of ['http://127.0.0.1:57901','https://example.invalid','http://user@127.0.0.1:56801','http://127.0.0.1:56801/path','http://127.0.0.1:56801/?x=y']){await f.save(f.configFile,{...legacy,upstream});await assert.rejects(f.load(),/LOCAL_LEGACY_TARGET_INVALID/);}});
test('wrong public product identity and a remote native shell cannot produce provenance',async t=>{const f=await fixture(t);f.pkg.name='@other/client';await f.save(join(f.productRoot,'package.json'),f.pkg);await assert.rejects(f.create(),/PRODUCT_IDENTITY_INVALID/);f.pkg.name='@avaryn/client';await f.save(join(f.productRoot,'package.json'),f.pkg);f.cap.server.url='https://other.invalid';await f.save(join(f.productRoot,'capacitor.config.json'),f.cap);await assert.rejects(f.create(),/PRODUCT_PLATFORM_INVALID/);assert.equal(f.inspected,0);});
test('startup diagnostics never include malformed private JSON or Docker output',async t=>{
 const f=await fixture(t),secret='synthetic-private-should-not-log';await writeFile(f.configFile,'{"anonKey":"'+secret+'", invalid}',{mode:0o600});await assert.rejects(f.load(),e=>e.message==='LOCAL_CONFIG_VALIDATION_FAILED'&&!e.stack.includes(secret));await rm(f.configFile);await f.write();await assert.rejects(f.load({inspectImpl:async()=>{throw Object.assign(Error(secret),{stdout:secret,stderr:secret});}}),e=>e.message==='LOCAL_CONFIG_VALIDATION_FAILED'&&!e.stack.includes(secret)&&!e.stdout&&!e.stderr);
});
test('public provenance read and regeneration use hashes of current files, never embedded personal paths',async t=>{
 const f=await fixture(t),p=await productProvenance(f.productRoot);assert.equal(JSON.stringify(p).includes(f.root),false);assert.ok(Object.values(p.files).every(h=>/^[a-f0-9]{64}$/.test(h)));
});
