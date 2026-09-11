export async function retireLegacyPreviewCache(){
  if(!('serviceWorker' in navigator))return;
  try{
    const old=(await navigator.serviceWorker.getRegistrations()).filter(reg=>{
      const worker=reg.active||reg.waiting||reg.installing;
      if(!worker)return false;
      const url=new URL(worker.scriptURL);
      return url.origin===location.origin&&url.pathname==='/flutter_service_worker.js';
    });
    if(!old.length)return;
    for(const reg of old)await reg.unregister();
    for(const name of ['flutter-app-cache','flutter-temp-cache','flutter-app-manifest'])await caches.delete(name);
  }catch{/* A restricted browser can still use the connected app without caching. */}
}
