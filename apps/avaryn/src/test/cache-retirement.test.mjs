import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {retireLegacyPreviewCache} from '../cache-refresh.js';

const origin='https://preview.example.invalid';
const oldNames=['flutter-app-cache','flutter-temp-cache','flutter-app-manifest'];
function globals(t,registrations){const events=[];for(const [name,value]of Object.entries({navigator:{serviceWorker:{getRegistrations:async()=>registrations}},location:{origin},caches:{delete:async key=>{events.push(key);return true;}}})){const old=Object.getOwnPropertyDescriptor(globalThis,name);Object.defineProperty(globalThis,name,{value,configurable:true});t.after(()=>old?Object.defineProperty(globalThis,name,old):delete globalThis[name]);}return events;}
function registration(scriptURL){return {active:{scriptURL},unregistered:0,async unregister(){this.unregistered++;return true;}};}
test('retirement removes only same-origin root legacy worker and its three exact caches',async t=>{
  const legacy=registration(`${origin}/flutter_service_worker.js`),other=registration(`${origin}/unrelated-worker.js`),foreign=registration('https://other.invalid/flutter_service_worker.js'),nested=registration(`${origin}/another/flutter_service_worker.js`);
  const events=globals(t,[legacy,other,foreign,nested]);await retireLegacyPreviewCache();assert.equal(legacy.unregistered,1);for(const r of[other,foreign,nested])assert.equal(r.unregistered,0);assert.deepEqual(events,oldNames);
});
test('no matching registration leaves every cache and unrelated worker alone',async t=>{
  const other=registration(`${origin}/other.js`),events=globals(t,[other]);await retireLegacyPreviewCache();assert.equal(other.unregistered,0);assert.deepEqual(events,[]);
});
test('waiting legacy worker is retired without touching unrelated waiting registrations',async t=>{
  const old=registration(`${origin}/flutter_service_worker.js`);old.waiting=old.active;old.active=null;const events=globals(t,[old]);await retireLegacyPreviewCache();assert.equal(old.unregistered,1);assert.deepEqual(events,oldNames);
});
test('restricted serviceworker access is bounded and does not clear browser storage',async t=>{
  const events=globals(t,[]);navigator.serviceWorker.getRegistrations=async()=>{throw new Error('Denied');};await retireLegacyPreviewCache();assert.deepEqual(events,[]);
});
test('replacement worker activation preserves unrelated caches and only reloads same-origin clients',async()=>{
  const events=[],handlers={},clients=[{url:`${origin}/#/paarden`,navigate:async url=>events.push(['navigate',url])},{url:'https://other.invalid/private',navigate:async()=>assert.fail('Foreign client must not navigate')}];
  const context={URL,caches:{delete:async name=>events.push(['delete',name])},self:{location:{origin},addEventListener:(name,fn)=>handlers[name]=fn,skipWaiting:()=>events.push(['skipWaiting']),registration:{unregister:async()=>events.push(['unregister'])},clients:{matchAll:async()=>clients}}};
  vm.runInNewContext(fs.readFileSync(new URL('../flutter_service_worker.js',import.meta.url),'utf8'),context);handlers.install();let pending;handlers.activate({waitUntil:p=>pending=p});await pending;
  assert.deepEqual(events.filter(e=>e[0]==='delete').map(e=>e[1]),oldNames);assert.deepEqual(events.filter(e=>e[0]==='navigate'),[['navigate',clients[0].url]]);assert.equal(events.filter(e=>e[0]==='unregister').length,1);
});
