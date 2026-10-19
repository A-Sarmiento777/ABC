const C='abc-lek-v8';
const FILES=['./','index.html','manifest.webmanifest','icons/icon-192.png','icons/icon-512.png'];
// Optional files (the app works without them), cached for offline use when they exist.
const EXTRA=Array.from({length:10},(_,i)=>`audio/numbers/${i+1}.mp3`);
self.addEventListener('install',e=>{e.waitUntil(caches.open(C).then(c=>c.addAll(FILES)
  .then(()=>Promise.all(EXTRA.map(f=>c.add(f).catch(()=>{}))))));self.skipWaiting()});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(x=>x!==C).map(x=>caches.delete(x)))));self.clients.claim()});
const put=(req,res)=>{if(res.ok){const cp=res.clone();caches.open(C).then(c=>c.put(req,cp))}return res};
self.addEventListener('fetch',e=>{const r=e.request;if(r.method!=='GET')return;const u=new URL(r.url);
  // <audio>/<video> playback (e.g. opening an mp3 link) goes straight to the network: Safari mishandles
  // media streamed from a service worker. The app itself loads sounds with fetch(), which is cached below.
  if(r.headers.has('range')||r.destination==='audio'||r.destination==='video')return;
  // The page and the clip list change on every deploy: try the network first, use the cache offline.
  if(r.mode==='navigate'||u.pathname.endsWith('.html')||u.pathname.endsWith('voices/index.json')){
    e.respondWith(fetch(r,{cache:'no-cache'}).then(res=>put(r,res)).catch(()=>caches.match(r).then(x=>x||caches.match('index.html'))));return}
  // Everything else (icons, fonts, sounds) doesn't change under the same name: cache first.
  e.respondWith(caches.match(r).then(x=>x||fetch(r).then(res=>
    u.origin===self.location.origin||u.hostname.includes('fonts.g')?put(r,res):res)).catch(()=>
    r.destination==='document'?caches.match('index.html'):new Response('',{status:504})))});
