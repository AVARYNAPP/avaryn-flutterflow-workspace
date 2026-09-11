const callbacks=new Map([
 ['com.mycompany.avarynalpha://auth/callback','email'],
 ['com.mycompany.avarynalpha://auth/reset-password','recovery'],
 ['https://alpha.avaryn.eu/auth/callback','email'],
 ['https://alpha.avaryn.eu/auth/reset-password','recovery']
]);

/** Parse email token hashes only. A matching link is not proof of authentication:
 * the existing email confirmation UI must still verify it with Auth. */
export function parseNativeAuthCallback(raw){
 if(typeof raw!=='string'||raw.length>4096||/[\s\x00-\x1f\\#]/.test(raw))return null;
 const type=callbacks.get(raw.split('?')[0]);if(!type)return null;
 try{
  const url=new URL(raw),entries=[...url.searchParams];
  if(url.username||url.password||url.port||entries.length!==2||url.searchParams.getAll('type').length!==1||url.searchParams.getAll('token_hash').length!==1||url.searchParams.get('type')!==type)return null;
  const tokenHash=url.searchParams.get('token_hash');
  return /^[a-zA-Z0-9_-]{16,2048}$/.test(tokenHash||'')?{tokenHash,type}:null;
 }catch{return null;}
}

/** Register warm links before reading the cold-start URL. Never navigate to a
 * supplied URL, persist credentials, or use native source-app metadata as trust.
 * Native launch URLs may also remain in OS/plugin memory; this clears our RAM
 * queue and any callback URL in webview history, not the platform's private cache. */
export async function createNativeAuthCallbacks({App,location=globalThis.location,history=globalThis.history}){
 let handler=null,onError=null,pending=null,disposed=false,revision=0,warm=0,processing=Promise.resolve();
 const seen=new Set();
 const report=()=>{try{onError?.({code:'NATIVE_AUTH_CALLBACK_UNAVAILABLE',message:'De bevestigingslink kon niet worden geopend. Gebruik de code uit je e-mail of open de link opnieuw.'});}catch{}};
 function scrub(){
  try{
   if(callbacks.has(String(location?.href||'').split(/[?#]/)[0]))history?.replaceState(null,'','/#/vandaag');
  }catch{ /* No callback URL is ever copied into the webview. */ }
 }
 function deliver(){
  if(disposed||!handler||!pending)return;
  const value=pending,callback=handler;pending=null;
  try{Promise.resolve(callback(value)).catch(report);}catch{report();}
 }
 function receive(raw,isWarm=false){
  scrub();const value=parseNativeAuthCallback(raw);if(!value||disposed)return;
  if(isWarm)warm++;
  const ticket=revision;
  processing=processing.then(async()=>{try{
   if(disposed||revision!==ticket)return;
   const bytes=new TextEncoder().encode(value.type+':'+value.tokenHash);
   const digest=await crypto.subtle.digest('SHA-256',bytes);
   if(disposed||revision!==ticket)return;
   const key=Array.from(new Uint8Array(digest),v=>v.toString(16).padStart(2,'0')).join('');
   if(seen.has(key))return;
   seen.add(key);if(seen.size>32)seen.delete(seen.values().next().value);
   pending=value;deliver();
  }catch{if(!disposed&&revision===ticket)report();}});
  return processing;
 }
 const listener=await App.addListener('appUrlOpen',event=>receive(event?.url,true));
 try{
  const launch=await App.getLaunchUrl();
  if(!warm)await receive(launch?.url);
 }catch{
  disposed=true;revision++;pending=null;await listener.remove();
  throw Error('De native bevestigingslinks konden niet worden voorbereid.');
 }
 return {
  onAuthCallback(callback,errorCallback){
   if(disposed)return ()=>{};
   handler=typeof callback==='function'?callback:null;onError=typeof errorCallback==='function'?errorCallback:null;deliver();
   return ()=>{if(handler===callback){handler=null;onError=null;}};
  },
  clearAuthCallback(){revision++;pending=null;},
  async dispose(){if(disposed)return;disposed=true;revision++;pending=null;handler=null;onError=null;seen.clear();await listener.remove();}
 };
}
