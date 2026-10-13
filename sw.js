const C='abc-lek-v4';
const FILES=['./','index.html','manifest.webmanifest','icons/icon-192.png','icons/icon-512.png'];
self.addEventListener('install',e=>{e.waitUntil(caches.open(C).then(c=>c.addAll(FILES)));self.skipWaiting()});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(x=>x!==C).map(x=>caches.delete(x)))));self.clients.claim()});
self.addEventListener('fetch',e=>{if(e.request.method!=='GET')return;
  e.respondWith(caches.match(e.request).then(r=>r||fetch(e.request).then(res=>{
    if(res.ok&&(e.request.url.startsWith(self.location.origin)||e.request.url.includes('fonts.g'))){const cp=res.clone();caches.open(C).then(c=>c.put(e.request,cp))}
    return res}).catch(()=>caches.match('index.html'))))});
