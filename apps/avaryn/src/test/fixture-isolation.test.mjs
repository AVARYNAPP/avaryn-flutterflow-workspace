import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {resolve} from 'node:path';
import {fixtureIsolationPlugin,verifyFixtureInputs} from '../../scripts/build.mjs';
import {dashboardClock} from '../browser-clock.js';

const src=fileURLToPath(new URL('../',import.meta.url));
const source=`
 import * as access from './horse-access.js';
 import * as facilities from './facility-data.js';
 import {INITIAL_STATE} from './data.js';
 export {access,facilities,INITIAL_STATE};
`;
async function compile(demo,contents=source) {
 const result=await build({stdin:{contents,resolveDir:src,sourcefile:'fixture-isolation-entry.js'},bundle:true,write:false,format:'esm',platform:'node',metafile:true,plugins:[fixtureIsolationPlugin(src,demo)]});
 const code=result.outputFiles[0].text;
 return {result,code,module:await import('data:text/javascript;base64,'+Buffer.from(code).toString('base64'))};
}
const demo=await compile(true),release=await compile(false);
const digest=value=>createHash('sha256').update(JSON.stringify(value)).digest('hex');
const copy=value=>structuredClone(value);
const rights=(access,state)=>[access.canManage(state),access.canViewTeam(state),access.canCreateTask(state),access.canPlan(state),access.canEditFeeding(state),access.canShareMoment(state),access.canManageFacilities(state),access.canBookFacilities(state)];

test('release compiler imports exactly empty providers and no demo data modules',()=>{
 const proof=verifyFixtureInputs(release.result.metafile,src,false);
 assert.deepEqual(proof.providers,['empty-state.js','empty-personas.js','empty-facilities.js']);
 assert.deepEqual(proof.demoInputs,[]);
 for(const name of ['data.js','demo-personas.js','demo-facilities.js'])assert(!Object.keys(release.result.metafile.inputs).some(path=>resolve(path)===resolve(src,name)));
 for(const value of ['Emma de Vries','Sophie Bakker','Noor Meijer','arena-orion-morning','arena-private-request','pasture-morning','2026-09-10'])assert(!release.code.includes(value),value);
});

test('demo build keeps the pre-extraction fixture values and facility metadata exactly',()=>{
 verifyFixtureInputs(demo.result.metafile,src,true);
 // Captured from the original modules before the extraction; no new data values.
 assert.equal(digest(demo.module.access.PERSONAS),'a4f5b7b0f508b7f77c0f7700d47c8d727f04e23fed149399570a9682e3950cf4');
 assert.equal(digest(demo.module.facilities.createFacilityFixtures()),'c6f65030b6a8c83bd31e3546763e1ea2e210fff613bdf1320259e33d47b14f43');
 assert.equal(digest(demo.module.facilities.FACILITY_KINDS),'44944bbacacaf256791708962be47e681e1e33357283ecc78369a68840496ab6');
 assert.equal(demo.module.facilities.FACILITY_DAY,'2026-09-10');
});

test('default release startup is empty and a stored demo persona cannot confer rights',()=>{
 const {access,facilities,INITIAL_STATE}=release.module;
 assert.deepEqual(Object.keys(access.PERSONAS),[]);
 for(const persona of [undefined,'manager','owner','rider','groom','unknown']) {
  const state={...copy(INITIAL_STATE),persona};
  facilities.initFacilities(state);
  assert.equal(access.getPersona(state).id,'');
  assert.deepEqual(rights(access,state),Array(8).fill(false));
  assert.deepEqual(access.visibleHorseIds(state),[]);
  assert.deepEqual(state.facilities,facilities.createEmptyFacilities());
  assert.equal(state.facilityDate,dashboardClock().day);
  for(const key of ['horses','tasks','activities','team'])assert.deepEqual(state[key],[]);
 }
});

test('logged-out release projection hides supplied stale fixture records and blank-assignee tasks',()=>{
 const {access}=release.module;
 const state={...copy(demo.module.INITIAL_STATE),persona:'manager'};
 state.tasks.push({id:'blank',horseId:null,assignee:'',title:'No current account'});
 const before=JSON.stringify(state),visible=access.getVisibleState(state);
 for(const key of ['horses','tasks','activities','team'])assert.deepEqual(visible[key],[]);
 assert.deepEqual(visible.feeding,{});
 assert.equal(JSON.stringify(state),before);
});

test('every existing demo persona still scopes horses and operations through the same contract',()=>{
 const {access,INITIAL_STATE}=demo.module;
 const expected={manager:{horses:['orion','nova'],rights:[true,true,true,true,true,true,true,true]},owner:{horses:['orion','nova'],rights:[false,false,true,true,true,true,false,true]},rider:{horses:['nova'],rights:[false,false,false,true,false,true,false,true]},groom:{horses:['orion'],rights:[false,false,false,false,false,false,false,false]}};
 for(const [persona,value] of Object.entries(expected)) {
  const state={...copy(INITIAL_STATE),persona};
  assert.deepEqual(access.visibleHorseIds(state),value.horses);
  assert.deepEqual(rights(access,state),value.rights);
 }
});

test('connected production actors and server capabilities override all demo-like labels',()=>{
 const {access}=release.module;
 const actor={id:'9cd709cd-9bb1-43a6-aaf1-2b860d03e2dd',name:'Actuele gebruiker',initials:'AG',roleKind:'groom',personalHorseIds:[],accessibleHorseIds:['h1'],assignedHorseIds:['h1']};
 const state={persona:'manager',horses:[{id:'h1',name:'Eigen paard'}],tasks:[],backend:{connected:true,actor,capabilities:{canManage:false,canViewTeam:true,canCreateTask:false,canPlan:true,canEditFeeding:false,canShareMoment:false},horseCapabilities:{h1:{planning:true,feeding:false}},p2:{connected:true,canManage:false,canBook:true}}};
 assert.equal(access.getPersona(state),actor);
 assert.deepEqual(rights(access,state),[false,true,false,true,false,false,false,true]);
 assert.deepEqual(access.visibleHorseIds(state),['h1']);
 assert.equal(access.canPlan(state,'h1'),true);
 assert.equal(access.canPlan(state,'other'),false);
 assert.equal(access.canEditFeeding(state,'h1'),false);
 assert.deepEqual(access.getVisibleState(state),state);
 assert.notEqual(access.getVisibleState(state),state);
});

test('connected facility data survives initialization and partial data never receives demo resources',()=>{
 const {facilities}=release.module;
 const state={backend:{connected:true},facilityDate:'2026-09-20',facilities:{schema:1,arenaSetupVersion:1,tackRoom:true,resources:[{id:'real-place',kind:'stall',name:'Eigen box'}],placements:[],bookings:[],arenaBookings:[]}};
 const before=copy(state.facilities);
 facilities.initFacilities(state);assert.deepEqual(state.facilities,before);assert.equal(state.facilityDate,'2026-09-20');
 const partial={backend:{connected:true},facilityDate:'2026-09-20',facilities:{schema:1,resources:[]}};
 facilities.initFacilities(partial);assert.deepEqual(partial.facilities,facilities.createEmptyFacilities());
});

test('release retains real facility types, resource construction and adjacent-slot capacity rules',()=>{
 const {facilities}=release.module;
 assert.deepEqual(Object.keys(facilities.FACILITY_KINDS),['stall','pasture','paddock','arena','walker','wash','locker']);
 assert(Object.values(facilities.FACILITY_KINDS).every(value=>value.count===0));
 const pasture=facilities.newResource('pasture',1,1),fac={...facilities.createEmptyFacilities(),resources:[pasture],bookings:[{id:'existing',resourceId:pasture.id,horseIds:['other'],date:'2026-09-20',start:'08:00',end:'09:00'}]};
 const draft={id:'new',resourceId:pasture.id,horseIds:['own'],date:'2026-09-20',start:'09:00',end:'10:00'};
 assert.equal(facilities.bookingError(fac,draft,['own']),'');
 assert.match(facilities.bookingError(fac,{...draft,start:'08:59'},['own']),/te weinig vrije plaatsen/);
 assert.match(facilities.bookingError(fac,draft,[]),/eigen overzicht/);
});

test('alternate relative imports are also isolated and proof rejects any residual demo input',async()=>{
 const alternate=await compile(false,source.replaceAll("'./data.js'","'./../src/data.js'")+"\nimport {PERSONAS as probe} from '././demo-personas.js';export {probe};");
 assert.deepEqual(alternate.module.probe,{});
 verifyFixtureInputs(alternate.result.metafile,src,false);
 const poisoned={inputs:{...release.result.metafile.inputs,[resolve(src,'demo-facilities.js')]:{bytes:1}}};
 assert.throws(()=>verifyFixtureInputs(poisoned,src,false),/demo-only modules/);
 assert.throws(()=>verifyFixtureInputs({inputs:{}},src,false),/expected fixture-isolation provider/);
});
