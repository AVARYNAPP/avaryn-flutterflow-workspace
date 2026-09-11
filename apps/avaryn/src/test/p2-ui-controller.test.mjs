import test from 'node:test';
import assert from 'node:assert/strict';
import {createConnectedP2Controller} from '../connected-p2-controller.js';
import {FACILITY_KINDS} from '../facility-data.js';

const uuid=n=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const actor=uuid(1),org=uuid(2),horse=uuid(3),resource=uuid(4),booking=uuid(5),rid=uuid(99);
const copy=v=>structuredClone(v);
const bookingReply=()=>({booking_id:booking,row_version:4,status:'approved'});
const deferred=()=>{let resolve,reject;const promise=new Promise((r,j)=>{resolve=r;reject=j});return {promise,resolve,reject};};
function state(){return {
  today:'2026-09-11',facilityDate:'2026-09-11',selectedDay:'2026-09-11',horses:[{id:horse,name:'Eigen paard',organizationId:org}],
  functionProfiles:{[actor]:['rider']},functionProfileRowVersion:4,
  backend:{connected:true,actor:{id:actor},organizationId:org,todayDate:'2026-09-11',p2:{connected:true,organizationId:org,canManage:true,canBook:true}},
  facilities:{schema:1,configuration:{rowVersion:6},resources:[{id:resource,kind:'pasture',rowVersion:3,name:'Weide',capacity:4,status:'available'}],placementVersions:{[horse]:7},placements:[],arenaBookings:[],bookings:[{id:booking,resourceId:resource,horseIds:[horse],rowVersion:3,status:'approved'}]}
};}
function setup(t){
  let current=state(),epoch=0;const calls=[],events=[];let last;
  const oldFormData=globalThis.FormData;
  globalThis.FormData=class{constructor(form){this.rows=form.rows;}get(name){return this.rows.find(r=>r[0]===name)?.[1]??null;}getAll(name){return this.rows.filter(r=>r[0]===name).map(r=>r[1]);}has(name){return this.rows.some(r=>r[0]===name);}};
  t.after(()=>globalThis.FormData=oldFormData);
  const backend={reply:async name=>name==='configure_c010_facilities'?{organization_id:org,row_version:7}:name==='set_c010_horse_place'?{horse_id:horse,resource_id:resource,row_version:8,status:'active'}:name==='save_my_c010_function_profile'?{profile_id:actor,row_version:5}:bookingReply(),apiRequest:async(...args)=>{calls.push(args);return backend.reply(...args);},reload:async()=>events.push(['reload']),perform(form,operation,message){const ticket=epoch;last=Promise.resolve().then(()=>operation(rid,()=>ticket===epoch));last.catch(()=>{});events.push(['perform',message]);return last;}};
  const controller=createConnectedP2Controller({getState:()=>current,getBackend:()=>backend,closeModal:()=>events.push(['close']),toast:m=>events.push(['toast',m])});
  function form(id,fields){const error={textContent:'',hidden:true,scrollIntoView(){}};return{id,dataset:{},rows:Object.entries(fields).flatMap(([k,v])=>Array.isArray(v)?v.map(item=>[k,item]):[[k,v]]),error,querySelector:()=>error};}
  const event={preventDefault(){events.push(['prevent']);}};
  return {controller,backend,calls,events,form,event,get:()=>current,set:s=>current=s,bump:()=>epoch++,done:()=>last};
}
const bookingFields={bookingId:booking,resourceId:resource,horseIds:[horse],date:'2026-09-12',start:'08:00',end:'09:00',note:'Exacte volledige instructie'};

test('actual controller and adapter keep captured booking CAS after a newer workspace read',async t=>{
  const h=setup(t),form=h.form('fac-booking-form',bookingFields);h.controller.capture(form);
  const newer=copy(h.get());newer.facilities.bookings[0].rowVersion=4;h.set(newer);
  assert.equal(h.controller.handleSubmit(form,h.event),true);await h.done();
  const [name,params,options]=h.calls[0];assert.equal(name,'save_c010_facility_booking');assert.equal(params.p_expected_row_version,3);assert.equal(params.p_note,bookingFields.note);assert.equal(params.p_request_id,rid);assert.deepEqual(options,{write:true});
  assert.equal(h.get().facilities.bookings[0].rowVersion,4,'No local fake mutation replaces authoritative row');
});
test('configuration submits captured configuration CAS, complete counts and tack-room flag',async t=>{
  const h=setup(t),fields={...Object.fromEntries(Object.keys(FACILITY_KINDS).map(k=>[k,'2'])),walkerCapacity:'4',tackRoom:'on'},form=h.form('fac-config-form',fields);h.controller.capture(form);
  const next=copy(h.get());next.facilities.configuration.rowVersion=8;h.set(next);h.controller.handleSubmit(form,h.event);await h.done();
  assert.equal(h.calls[0][0],'configure_c010_facilities');assert.equal(h.calls[0][1].p_expected_row_version,6);assert.equal(h.calls[0][1].p_has_tack_room,true);assert.equal(h.calls[0][1].p_counts.arena,2);
});
test('placement uses ended-assignment version from captured server version map',async t=>{
  const h=setup(t),form=h.form('fac-placement-form',{horseId:horse,resourceId:resource,note:'Halster bij de deur'});h.controller.capture(form);h.controller.handleSubmit(form,h.event);await h.done();
  assert.equal(h.calls[0][0],'set_c010_horse_place');assert.equal(h.calls[0][1].p_expected_row_version,7);assert.equal(h.calls[0][1].p_horse_id,horse);assert.equal(h.get().facilities.placements.length,0);
});
test('captured form from another organization cannot call any API',async t=>{
  const h=setup(t),form=h.form('fac-booking-form',bookingFields);h.controller.capture(form);const next=copy(h.get());next.backend.organizationId=uuid(22);next.backend.p2.organizationId=uuid(22);h.set(next);h.controller.handleSubmit(form,h.event);
  assert.equal(h.calls.length,0);assert.ok(!h.events.some(e=>e[0]==='perform'));assert.match(form.error.textContent,/stal of account is veranderd/);
});
test('successful current booking chooses its saved day only after server confirmation',async t=>{
  const h=setup(t),d=deferred();h.backend.reply=()=>d.promise;const form=h.form('fac-booking-form',bookingFields);h.controller.capture(form);h.controller.handleSubmit(form,h.event);await Promise.resolve();assert.equal(h.get().facilityDate,'2026-09-11');d.resolve(bookingReply());await h.done();assert.equal(h.get().facilityDate,'2026-09-12');
});
test('late success after actor round trip cannot alter the newer current day',async t=>{
  const h=setup(t),d=deferred();h.backend.reply=()=>d.promise;const form=h.form('fac-booking-form',bookingFields);h.controller.capture(form);h.controller.handleSubmit(form,h.event);await Promise.resolve();
  h.bump();const next=copy(h.get());next.facilityDate='2026-09-15';h.set(next);d.resolve(bookingReply());await h.done();assert.equal(h.get().facilityDate,'2026-09-15');
});
test('server refusal keeps form values and local day untouched',async t=>{
  const h=setup(t);h.backend.reply=async()=>{throw Object.assign(new Error('Conflict'),{code:'C010_FACILITY_CAPACITY_CONFLICT'});};const form=h.form('fac-booking-form',bookingFields);const before=copy(form.rows);h.controller.capture(form);h.controller.handleSubmit(form,h.event);await assert.rejects(h.done(),/onvoldoende ruimte/);assert.deepEqual(form.rows,before);assert.equal(h.get().facilityDate,'2026-09-11');assert.ok(!h.events.some(e=>e[0]==='close'));
});
test('invalid calendar date is rejected before closing form or reloading',t=>{
  const h=setup(t),form=h.form('arena-date-form',{date:'2026-02-30'});h.controller.handleSubmit(form,h.event);assert.ok(form.error.textContent);assert.ok(!h.events.some(e=>['close','reload'].includes(e[0])));
});
test('date outside existing server range stays in form without a login-triggering reload',t=>{
  const h=setup(t),form=h.form('fac-date-form',{date:'2030-01-01'});h.controller.handleSubmit(form,h.event);assert.ok(form.error.textContent,'The existing ±366-day server constraint needs a readable validation message');assert.ok(!h.events.some(e=>['close','reload'].includes(e[0])));assert.equal(h.get().facilityDate,'2026-09-11');
});
test('day step uses a civil day across month and Amsterdam DST boundaries',t=>{
  const h=setup(t);h.get().facilityDate='2026-10-25';h.controller.handleAction('arena-shift-day',{dataset:{direction:'1'}});assert.equal(h.get().facilityDate,'2026-10-26');assert.equal(h.events.filter(e=>e[0]==='reload').length,1);
});
test('forward step at the server range boundary neither mutates the day nor reloads',t=>{
  const h=setup(t),d=new Date(`${h.get().today}T12:00:00Z`);d.setUTCDate(d.getUTCDate()+366);const max=d.toISOString().slice(0,10);h.get().facilityDate=max;h.controller.handleAction('arena-shift-day',{dataset:{direction:'1'}});assert.equal(h.get().facilityDate,max);assert.equal(h.events.filter(e=>e[0]==='reload').length,0);assert.ok(h.events.some(e=>e[0]==='toast'));
});
test('capturing lookup and reservation forms sets the actual date input bounds',t=>{
  const h=setup(t),lookup=h.form('arena-date-form',{}),reservation=h.form('arena-reserve-form',{});const a={},b={};lookup.querySelector=()=>a;reservation.querySelector=()=>b;h.controller.capture(lookup);h.controller.capture(reservation);
  assert.equal(b.min,h.get().today);assert.equal(a.max,b.max);assert.ok(a.min<h.get().today);const days=(Date.parse(`${a.max}T12:00:00Z`)-Date.parse(`${h.get().today}T12:00:00Z`))/86400000;assert.equal(days,366);
});
test('profile selection saves preferences with its CAS and leaves actor authority unchanged',async t=>{
  const h=setup(t),before=copy(h.get().backend),form=h.form('role-profile-form',{functions:['trainer','manager','manager','sponsor']});h.controller.capture(form);h.controller.handleSubmit(form,h.event);await h.done();assert.equal(h.calls[0][0],'save_my_c010_function_profile');assert.deepEqual(h.calls[0][1].p_functions,['trainer','manager']);assert.equal(h.calls[0][1].p_expected_row_version,4);assert.deepEqual(h.get().backend,before);
});
test('personal actor without a stable loads only their preferences and no fixture facilities',async t=>{
  const h=setup(t),s=h.get();s.backend.organizationId=null;s.backend.p2.organizationId=null;h.backend.reply=async()=>({profile_id:actor,functions:['owner'],row_version:2});const loaded=await h.controller.load(s);assert.equal(h.calls.length,1);assert.equal(h.calls[0][0],'get_my_c010_function_profile');assert.deepEqual(loaded.facilities.resources,[]);assert.equal(loaded.backend.p2.canManage,false);assert.equal(loaded.backend.p2.canBook,false);assert.deepEqual(loaded.functionProfiles,{[actor]:['owner']});
});
