import {build} from 'esbuild';
import {readFile,writeFile,mkdir,readdir,copyFile,rm} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {resolve,relative,join} from 'node:path';
import {createHash} from 'node:crypto';
const root=fileURLToPath(new URL('../',import.meta.url)),src=join(root,'src'),out=join(root,'dist');
const fixtureProviders = Object.freeze({
 'data.js':'empty-state.js',
 'demo-personas.js':'empty-personas.js',
 'demo-facilities.js':'empty-facilities.js',
});

// Match exact local modules, including alternate relative import spellings.
export function fixtureIsolationPlugin(sourceDirectory, demo) {
 const replacements=new Map(Object.entries(fixtureProviders).map(([from,to])=>[resolve(sourceDirectory,from),resolve(sourceDirectory,to)]));
 return {name:'avaryn-fixture-isolation',setup(b){
  if(demo)return;
  b.onResolve({filter:/(?:^|\/)(?:data|demo-personas|demo-facilities)\.js$/},args=>{
   const path=replacements.get(resolve(args.resolveDir,args.path));
   return path?{path}:undefined;
  });
 }};
}

export function verifyFixtureInputs(metafile, sourceDirectory, demo) {
 const inputs=new Set(Object.keys(metafile.inputs).map(path=>resolve(path)));
 const included=Object.keys(fixtureProviders).filter(name=>inputs.has(resolve(sourceDirectory,name)));
 if(!demo&&included.length)throw Error(`Release imports demo-only modules: ${included.join(', ')}`);
 const selected=demo?Object.keys(fixtureProviders):Object.values(fixtureProviders);
 if(selected.some(name=>!inputs.has(resolve(sourceDirectory,name))))throw Error('Build omitted an expected fixture-isolation provider.');
 return {status:'PASS',mode:demo?'demo':'release',providers:selected,demoInputs:included};
}

export async function buildClient({demo=process.argv.includes('--demo')}={}) {
const release=JSON.parse(await readFile(join(root,'config/release.json'),'utf8'));
const apiBase=process.env.AVARYN_PUBLIC_API_BASE||'/api';
if(apiBase!=='/api'){
 const url=new URL(apiBase);
 if(url.protocol!=='https:'||url.username||url.password||url.search||url.hash||url.pathname!=='/api'||/(localhost|127\.0\.0\.1|\.local)$/.test(url.hostname))throw Error('Release API must use a public HTTPS /api endpoint.');
}
await mkdir(out,{recursive:true});
// Only this derived build directory is disposable; source and local drafts remain intact.
for(const name of await readdir(out))await rm(join(out,name),{recursive:true,force:true});
const publicConfig={candidate:release.candidate,apiBase,demo};
const result=await build({entryPoints:[join(src,'app.js')],outdir:out,entryNames:'app-[hash]',bundle:true,format:'esm',splitting:true,target:['es2022','safari15'],minify:true,metafile:true,
 plugins:[fixtureIsolationPlugin(src,demo),{name:'avaryn-environment',setup(b){
  b.onResolve({filter:/\/product-config\.js$/},()=>({path:'product-config',namespace:'avaryn-config'}));
  b.onLoad({filter:/.*/,namespace:'avaryn-config'},()=>({contents:`export const PRODUCT=Object.freeze(${JSON.stringify(publicConfig)});`,loader:'js'}));
 }}]});
const fixtureIsolation=verifyFixtureInputs(result.metafile,src,demo);
const entry=Object.entries(result.metafile.outputs).find(([,value])=>value.entryPoint?.endsWith('/app.js')||value.entryPoint==='src/app.js')?.[0];
if(!entry)throw Error('Client entrypoint missing');
const entryName=relative(out,resolve(entry));
let html=await readFile(join(src,'index.html'),'utf8');
html=html.replace('src="app.js"',`src="${entryName}"`).replace('Testpreview','AVARYN pilot');
await writeFile(join(out,'index.html'),html);
for(const name of await readdir(src))if(name.endsWith('.css'))await copyFile(join(src,name),join(out,name));
async function copyPublic(dir,target){await mkdir(target,{recursive:true});for(const item of await readdir(dir,{withFileTypes:true})){if(item.isDirectory())await copyPublic(join(dir,item.name),join(target,item.name));else if(/\.(png|jpg|jpeg|svg|webp|ttf|woff2?|txt)$/i.test(item.name))await copyFile(join(dir,item.name),join(target,item.name));}}
await copyPublic(join(src,'assets'),join(out,'assets'));
await writeFile(join(out,'version.json'),JSON.stringify({...release,apiBase,demo},null,2)+'\n');
const files=[];
async function manifest(dir){for(const item of await readdir(dir,{withFileTypes:true})){const path=join(dir,item.name);if(item.isDirectory())await manifest(path);else{const bytes=await readFile(path);files.push({path:relative(out,path),bytes:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex')});}}}
await manifest(out);files.sort((a,b)=>a.path.localeCompare(b.path));
await writeFile(join(out,'build-manifest.json'),JSON.stringify({candidate:release.candidate,apiBase,demo,fixtureIsolation,files},null,2)+'\n');
console.log(JSON.stringify({candidate:release.candidate,demo,entry:entryName,files:files.length,fixtureIsolation}));
}

if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url))await buildClient();
