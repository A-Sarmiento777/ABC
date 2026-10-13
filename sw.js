const C='abc-lek-v7';
const FILES=['./','index.html','manifest.webmanifest','icons/icon-192.png','icons/icon-512.png'];
self.addEventListener('install',e=>{e.waitUntil(caches.open(C).then(c=>c.addAll(FILES)));self.skipWaiting()});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(x=>x!==C).map(x=>caches.delete(x)))));self.clients.claim()});
const put=(req,res)=>{if(res.ok){const cp=res.clone();caches.open(C).then(c=>c.put(req,cp))}return res};
self.addEventListener('fetch',e=>{const r=e.request;if(r.method!=='GET')return;const u=new URL(r.url);
  // Voice clips go straight to the network: Safari mishandles media served from a service worker.
  if(u.pathname.endsWith('.mp3'))return;
  // The page and the clip list change on every deploy: try the network first, use the cache offline.
  if(r.mode==='navigate'||u.pathname.endsWith('.html')||u.pathname.endsWith('voices/index.json')){
    e.respondWith(fetch(r,{cache:'no-cache'}).then(res=>put(r,res)).catch(()=>caches.match(r).then(x=>x||caches.match('index.html'))));return}
  // Everything else (icons, fonts) never changes: cache first.
  e.respondWith(caches.match(r).then(x=>x||fetch(r).then(res=>
    u.origin===self.location.origin||u.hostname.includes('fonts.g')?put(r,res):res)).catch(()=>caches.match('index.html')))});
