// Retire only the legacy Flutter worker/cache on this same preview origin.
// The connected V8 app requires live authenticated reads and has no offline cache.
self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',event=>event.waitUntil((async()=>{
  for(const name of ['flutter-app-cache','flutter-temp-cache','flutter-app-manifest'])await caches.delete(name);
  await self.registration.unregister();
  for(const client of await self.clients.matchAll({type:'window',includeUncontrolled:true})){
    const url=new URL(client.url);
    if(url.origin===self.location.origin)await client.navigate(client.url);
  }
})()));
