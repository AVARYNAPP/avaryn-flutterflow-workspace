import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {registerHooks} from 'node:module';
import {parseNativeAuthCallback,createNativeAuthCallbacks} from '../../../apps/avaryn/src/native-callback.js';
const TOKEN='a'.repeat(64),NEXT='b'.repeat(64),base='com.mycompany.avarynalpha://auth/callback';
const url=(token=TOKEN)=>`${base}?token_hash=${token}&type=email`;
const defer=()=>{let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});return {promise,resolve,reject};};
const tick=()=>new Promise(r=>setImmediate(r));
function app({launch,launchGate}={}){
 const listeners={},order=[],removed=[];
 return {listeners,order,removed,async addListener(name,fn){order.push(name);listeners[name]=fn;return {remove:async()=>{removed.push(name);delete listeners[name];}};},async getLaunchUrl(){order.push('launch');return launchGate?launchGate.promise:launch?{url:launch}:undefined;},emit(raw){return listeners.appUrlOpen?.({url:raw});}};
}
for(const [address,type] of [[base,'email'],['com.mycompany.avarynalpha://auth/reset-password','recovery'],['https://alpha.avaryn.eu/auth/callback','email'],['https://alpha.avaryn.eu/auth/reset-password','recovery']])test('exact allowed native callback '+address,()=>{
 const value=parseNativeAuthCallback(`${address}?token_hash=${TOKEN}&type=${type}`);assert.equal(value?.type,type);assert.equal(value?.tokenHash===TOKEN,true);assert.deepEqual(Object.keys(value).sort(),['tokenHash','type']);
});
const rejected=[
 ['foreign host',`https://alpha.avaryn.eu.attacker.invalid/auth/callback?token_hash=${TOKEN}&type=email`],
 ['foreign scheme',url().replace('com.mycompany.avarynalpha:','other:')],
 ['insecure HTTP',`http://alpha.avaryn.eu/auth/callback?token_hash=${TOKEN}&type=email`],
 ['userinfo',`https://alpha.avaryn.eu@attacker.invalid/auth/callback?token_hash=${TOKEN}&type=email`],
 ['explicit port',`https://alpha.avaryn.eu:443/auth/callback?token_hash=${TOKEN}&type=email`],
 ['normalized traversal',`https://alpha.avaryn.eu/other/../auth/callback?token_hash=${TOKEN}&type=email`],
 ['encoded path',`https://alpha.avaryn.eu/auth/%63allback?token_hash=${TOKEN}&type=email`],
 ['wrong host custom scheme',url().replace('://auth/','://account/')],
 ['wrong route',url().replace('/callback','/else')],
 ['extra query',url()+'&redirect_to=https://attacker.invalid'],
 ['duplicate token',url()+'&token_hash='+NEXT],
 ['duplicate type',url()+'&type=recovery'],
 ['OAuth implicit hash',base+'#access_token=synthetic&refresh_token=synthetic'],
 ['fragment',url()+'#'],
 ['wrong purpose',url().replace('type=email','type=recovery')],
 ['OAuth code',base+'?code=synthetic&type=email'],
 ['short token',url('short')],
 ['token whitespace',url(encodeURIComponent('invalid token'.repeat(3)))],
 ['oversized token',url('a'.repeat(2049))]
];
test('foreign, ambiguous and non-email callbacks are rejected without token output',()=>{for(const [name,raw] of rejected)assert.equal(parseNativeAuthCallback(raw),null,name);});
test('warm listener is installed before cold launch lookup; pending callback is memory-only',async()=>{
 const source=app({launch:url()}),historyCalls=[],seen=[];const bridge=await createNativeAuthCallbacks({App:source,location:{href:'capacitor://localhost/'},history:{replaceState(...args){historyCalls.push(args);}}});
 assert.deepEqual(source.order,['appUrlOpen','launch']);assert.equal(seen.length,0);bridge.onAuthCallback(v=>seen.push(v));assert.equal(seen.length,1);assert.equal(seen[0].tokenHash===TOKEN,true);assert.deepEqual(historyCalls,[]);await bridge.dispose();assert.deepEqual(source.removed,['appUrlOpen']);
});
test('warm event during cold startup takes precedence over retained older launch URL',async()=>{
 const gate=defer(),source=app({launchGate:gate}),seen=[];const initializing=createNativeAuthCallbacks({App:source});await tick();await source.emit(url(NEXT));gate.resolve({url:url()});const bridge=await initializing;bridge.onAuthCallback(v=>seen.push(v));assert.equal(seen.length,1);assert.equal(seen[0].tokenHash===NEXT,true);await bridge.dispose();
});
test('same cold/warm callback is delivered once, including duplicate before subscriber',async()=>{
 const source=app({launch:url()}),seen=[],bridge=await createNativeAuthCallbacks({App:source});await source.emit(url());bridge.onAuthCallback(v=>seen.push(v));await source.emit(url());assert.equal(seen.length,1);await bridge.dispose();
});
test('latest distinct pending callback replaces earlier one before controller is ready',async()=>{
 const source=app({launch:url()}),seen=[],bridge=await createNativeAuthCallbacks({App:source});await source.emit(url(NEXT));bridge.onAuthCallback(v=>seen.push(v));assert.equal(seen.length,1);assert.equal(seen[0].tokenHash===NEXT,true);await bridge.dispose();
});
test('account/logout clear prevents delivery of old queued callback, including hashing in flight',async()=>{
 const source=app(),seen=[],bridge=await createNativeAuthCallbacks({App:source});const receiving=source.emit(url());bridge.clearAuthCallback();await receiving;bridge.onAuthCallback(v=>seen.push(v));assert.equal(seen.length,0);await source.emit(url(NEXT));assert.equal(seen.length,1);assert.equal(seen[0].tokenHash===NEXT,true);await bridge.dispose();
});
test('unsubscribed handler cannot receive another token; disposal removes only owned listener',async()=>{
 const source=app(),first=[],second=[],bridge=await createNativeAuthCallbacks({App:source});const unsubscribe=bridge.onAuthCallback(v=>first.push(v));unsubscribe();await source.emit(url());bridge.onAuthCallback(v=>second.push(v));assert.equal(first.length,0);assert.equal(second.length,1);await bridge.dispose();await bridge.dispose();assert.deepEqual(source.removed,['appUrlOpen']);await source.emit(url(NEXT));assert.equal(second.length,1);
});
test('callback webview query and fragment are scrubbed even when token is malformed',async()=>{
 const historyCalls=[],location={href:base+'?access_token=synthetic#refresh_token=synthetic'},source=app({launch:location.href});const bridge=await createNativeAuthCallbacks({App:source,location,history:{replaceState(...args){historyCalls.push(args);location.href='capacitor://localhost/#/vandaag';}}});assert.deepEqual(historyCalls,[[null,'','/#/vandaag']]);let called=false;bridge.onAuthCallback(()=>{called=true;});assert.equal(called,false);await bridge.dispose();
});
test('foreign callback never navigates or invokes auth handler',async()=>{
 const source=app(),seen=[],historyCalls=[],bridge=await createNativeAuthCallbacks({App:source,location:{href:'capacitor://localhost/'},history:{replaceState(...args){historyCalls.push(args);}}});bridge.onAuthCallback(v=>seen.push(v));for(const [,raw] of rejected)await source.emit(raw);assert.equal(seen.length,0);assert.equal(historyCalls.length,0);await bridge.dispose();
});
test('handler failure emits only static explanation, with no token or raw error leakage',async()=>{
 const source=app(),errors=[],bridge=await createNativeAuthCallbacks({App:source});bridge.onAuthCallback(()=>{throw Error(TOKEN);},v=>errors.push(v));await source.emit(url());assert.equal(errors.length,1);assert.equal(JSON.stringify(errors).includes(TOKEN),false);assert.equal(errors[0].code,'NATIVE_AUTH_CALLBACK_UNAVAILABLE');await bridge.dispose();
});
test('launch failure removes callback listener and never includes raw native error',async()=>{
 const gate=defer(),source=app({launchGate:gate}),initializing=createNativeAuthCallbacks({App:source});await tick();gate.reject(Error(TOKEN));await assert.rejects(initializing,error=>!error.message.includes(TOKEN));assert.deepEqual(source.removed,['appUrlOpen']);
});
test('native configuration preserves exact callback routing alongside scoped camera purpose strings',async()=>{
 const root=new URL('../../../',import.meta.url),manifest=await readFile(new URL('apps/avaryn/android/app/src/main/AndroidManifest.xml',root),'utf8'),plist=await readFile(new URL('apps/avaryn/ios/App/App/Info.plist',root),'utf8');
 assert.match(manifest,/android:scheme="com\.mycompany\.avarynalpha" android:host="auth" android:path="\/callback"/);assert.match(manifest,/android:path="\/reset-password"/);assert.doesNotMatch(manifest,/pathPrefix|scheme="http|CAMERA/);assert.match(plist,/<key>CFBundleURLSchemes<\/key>[\s\S]*?<string>com\.mycompany\.avarynalpha<\/string>/);assert.match(plist,/<string>\$\(PRODUCT_BUNDLE_IDENTIFIER\)<\/string>/);assert.match(plist,/<key>NSCameraUsageDescription<\/key>\s*<string>[^<]+<\/string>/);assert.match(plist,/<key>NSPhotoLibraryUsageDescription<\/key>\s*<string>[^<]+<\/string>/);assert.doesNotMatch(plist,/NSPhotoLibraryAddUsageDescription|associated-domains/);
});

let imports=0;
async function platformFixture({apiBase='/api',native=true}={},run){
 const names=['document','window','history','location','sessionStorage','__nativeCallbackMocks'],saved=Object.fromEntries(names.map(n=>[n,Object.getOwnPropertyDescriptor(globalThis,n)])),calls=[],listeners=new Map(),domEvents=new Map(),storageValues=new Map();
 const App={async addListener(name,fn){listeners.set(name,fn);return {remove:async()=>{listeners.delete(name);}};},async getLaunchUrl(){return {url:url()};},async minimizeApp(){}};
 const mocks={'@capacitor/core':{Capacitor:{isNativePlatform:()=>native,getPlatform:()=> 'ios'}},'@aparajita/capacitor-secure-storage':{SecureStorage:{async setKeyPrefix(v){calls.push(['prefix',v]);},async setSynchronize(v){calls.push(['sync',v]);},async setDefaultKeychainAccess(v){calls.push(['access',v]);},async getItem(k){return storageValues.get(k);},async setItem(k,v){storageValues.set(k,v);},async removeItem(k){storageValues.delete(k);}},KeychainAccess:{whenUnlockedThisDeviceOnly:1}},'@capacitor/app':{App},'@capacitor/browser':{Browser:{async open(){throw Error('Unexpected external browser');}}},'./product-config.js':{PRODUCT:{apiBase}}};
 Object.assign(globalThis,{__nativeCallbackMocks:mocks,document:{documentElement:{dataset:{}},querySelector:()=>null,addEventListener:(name,fn)=>domEvents.set(name,fn),removeEventListener:name=>domEvents.delete(name)},window:{dispatchEvent(){}},history:{back(){}},location:{href:'capacitor://localhost/',origin:'capacitor://localhost'},sessionStorage:{fixture:'web-only'}});
 const hooks=registerHooks({resolve(specifier,context,next){if(Object.hasOwn(mocks,specifier))return {url:'native-callback-mock:'+encodeURIComponent(specifier)+'?'+imports,shortCircuit:true};return next(specifier,context);},load(value,context,next){if(value.startsWith('native-callback-mock:')){const name=decodeURIComponent(value.split(':')[1].split('?')[0]);return {format:'module',source:Object.keys(mocks[name]).map(k=>`export const ${k}=globalThis.__nativeCallbackMocks[${JSON.stringify(name)}][${JSON.stringify(k)}];`).join('\n'),shortCircuit:true};}return next(value,context);}});
 try{const module=await import('../../../apps/avaryn/src/platform.js?native-callback-test='+ ++imports);await run({initialize:module.initializePlatform,calls,listeners,domEvents,storageValues});}finally{hooks.deregister();for(const n of names){if(saved[n])Object.defineProperty(globalThis,n,saved[n]);else delete globalThis[n];}}
}
test('native missing or malformed HTTPS /api config gives blockstate before native imports/storage',async()=>{
 for(const apiBase of ['/api','http://alpha.avaryn.eu/api','https://user:pass@alpha.avaryn.eu/api','https://alpha.avaryn.eu/api?query=1','https://alpha.avaryn.eu/other','not a URL'])await platformFixture({apiBase},async h=>{const p=await h.initialize();assert.equal(p.blocked?.code,'NATIVE_API_CONFIGURATION_REQUIRED');assert.equal(p.apiBase,null);assert.equal(p.storage,null);assert.equal(h.calls.length,0);assert.equal(h.listeners.size,0);});
});
test('native adapter preserves device-only secure storage and exposes callback/cleanup hooks',()=>platformFixture({apiBase:'https://alpha.avaryn.eu/api'},async h=>{
 const p=await h.initialize();assert.equal(p.blocked,undefined);assert.equal(typeof p.horsePhoto.takePhoto,'function');h.listeners.get('appRestoredResult')({pluginId:'Camera',methodName:'takePhoto',get data(){throw Error('Restored image must not be read');}});assert.match(p.horsePhoto.getRecoveryNotice(),/Er is niets opgeslagen/);assert.deepEqual(h.calls,[['prefix','avaryn.session.'],['sync',false],['access',1]]);await p.storage.setItem('session','synthetic-only');assert.equal(await p.storage.getItem('session'),'synthetic-only');await p.storage.removeItem('session');assert.equal(h.storageValues.size,0);let count=0;p.onAuthCallback(v=>{count++;assert.equal(v.type,'email');});assert.equal(count,1);assert.deepEqual([...h.listeners.keys()],['appUrlOpen','appRestoredResult','backButton','appStateChange']);await p.dispose();assert.equal(h.listeners.size,0);assert.equal(h.domEvents.size,0);
}));
test('web adapter keeps existing sessionStorage and loads no native listener',()=>platformFixture({native:false},async h=>{const p=await h.initialize();assert.equal(p.apiBase,'/api');assert.equal(p.horsePhoto,undefined);assert.equal(p.storage,globalThis.sessionStorage);assert.equal(h.calls.length,0);assert.equal(h.listeners.size,0);}));
