import test from 'node:test';
import assert from 'node:assert/strict';
import {renderPastures,renderFacilities,renderStalls,createFacilityController} from '../facilities.js';
import {renderArenaPlanning,createArenaController} from '../arena.js';
import {createContext} from '../components.js';
import {getFunctions,getProfileQuickActions,renderRoleProfile} from '../role-profile.js';
import {renderMenu} from '../menu-ui.js';
import {MENU_GROUPS} from '../product-structure.js';

const actorId='00000000-0000-4000-8000-000000000001';
function fixture(){return {
  route:'pastures',today:'2026-09-11',facilityDate:'2026-09-11',horseId:'h1',theme:'light',stableName:'Eigen stal',
  horses:[{id:'h1',name:'Orion',image:'assets/orion.png',stable:'Eigen stal'}],activities:[],tasks:[],feeding:{},team:[],
  backend:{connected:true,organizationId:'org-a',actor:{id:actorId,roleKind:'rider',name:'Eigen ruiter',initials:'ER',roleLabel:'Ruiter',accessibleHorseIds:['h1'],personalHorseIds:[],assignedHorseIds:['h1']},capabilities:{canPlan:true},horseCapabilities:{h1:{planning:true}},stableHorseIds:['h1'],p2:{connected:true,canManage:false,canBook:true}},
  facilities:{schema:1,arenaSetupVersion:1,tackRoom:false,placements:[],
    resources:[{id:'pasture-a',kind:'pasture',name:'Eigen weide',capacity:4,status:'available',description:''},{id:'arena-a',kind:'arena',name:'Binnenbak',type:'Binnenbak',capacity:4,status:'available',description:''}],
    bookings:[{id:'booking-a',resourceId:'pasture-a',horseIds:['h1'],date:'2026-09-11',start:'08:00',end:'10:00',status:'approved',note:'Volledige eigen instructie',rowVersion:3,canEdit:true,canCancel:true}],
    arenaBookings:[]}
};}
function controller(state,create){const events=[];return {events,controller:create({getState:()=>state,save:()=>events.push(['save']),render:()=>events.push(['render']),navigate:r=>events.push(['navigate',r]),showModal:(...args)=>events.push(['modal',...args]),closeModal:()=>events.push(['close']),toast:m=>events.push(['toast',m])})};}

test('server-granted own booking edit is both rendered and opens its existing form',()=>{
  const s=fixture(),html=renderPastures(s,createContext(s));
  assert.match(html,/data-action="fac-edit-booking" data-id="booking-a"/);
  const h=controller(s,createFacilityController);h.controller.handleAction('fac-edit-booking',{dataset:{id:'booking-a'}});
  const modal=h.events.find(e=>e[0]==='modal');assert.ok(modal,'Visible authorized edit must open a form');
  assert.match(modal[2],/id="fac-booking-form"/);assert.match(modal[2],/Volledige eigen instructie/);
  assert.ok(!h.events.some(e=>e[0]==='save'),'Opening a server form must not mutate local data');
});
test('server-granted own cancellation is both rendered and opens a confirmation',()=>{
  const s=fixture();s.facilities.bookings[0].canEdit=false;
  const html=renderPastures(s,createContext(s));assert.doesNotMatch(html,/fac-edit-booking/);assert.match(html,/fac-release-booking/);
  const h=controller(s,createFacilityController);h.controller.handleAction('fac-release-booking',{dataset:{id:'booking-a'}});
  const modal=h.events.find(e=>e[0]==='modal');assert.ok(modal,'Visible authorized cancel must open confirmation');
  assert.match(modal[2],/name="releaseId"[^>]*value="booking-a"/);assert.ok(!h.events.some(e=>e[0]==='save'));
});
test('no row capabilities means no booking mutation action, including a manager preference',()=>{
  const s=fixture();s.functionProfiles={[actorId]:['manager']};Object.assign(s.facilities.bookings[0],{canEdit:false,canCancel:false});
  const html=renderPastures(s,createContext(s));assert.doesNotMatch(html,/fac-edit-booking|fac-release-booking|fac-config/);
  const h=controller(s,createFacilityController);h.controller.handleAction('fac-edit-booking',{dataset:{id:'booking-a'}});
  assert.ok(!h.events.some(e=>e[0]==='modal'));
});
test('terminal facility bookings do not show active occupancy or old private instructions',()=>{
  const s=fixture();Object.assign(s.facilities.bookings[0],{status:'cancelled',note:'TERMINAL_ONLY_NOTE',canEdit:false,canCancel:false});
  const html=renderPastures(s,createContext(s));assert.doesNotMatch(html,/TERMINAL_ONLY_NOTE|fac-edit-booking|fac-release-booking/);
});
test('redacted occupied stall stays visibly occupied without a targetless horse action',()=>{
  const s=fixture();s.backend.p2.canManage=true;s.facilities.resources=[{id:'stall-hidden',kind:'stall',name:'Stal 2',number:2,capacity:1,status:'available',occupied:true}];s.facilities.placements=[{resourceId:'stall-hidden',horseId:null,note:'',rowVersion:null,redacted:true}];s.facilities.bookings=[];
  const html=renderStalls(s,createContext(s));assert.match(html,/Deze stalplaats is bezet/);assert.doesNotMatch(html,/data-action="fac-assign-stall"|data-action="fac-release-stall"|Een vrije plek op stal/);assert.match(html,/data-action="fac-edit-resource"/);
});
test('anonymous approved arena occupancy does not invent identities or private notes',()=>{
  const s=fixture();s.facilities.arenaBookings=[{id:'b-hidden',resourceId:'arena-a',date:s.today,start:'12:00',end:'13:00',participants:2,status:'approved',exclusive:false,horseId:null,requesterId:null,requesterName:'',activity:'',note:'',decisionNote:'',canCancel:false,canDecide:false}];
  const html=renderArenaPlanning(s,createContext(s));assert.match(html,/Gedeelde reservering/);assert.match(html,/2 van 4 plekken bezet/);assert.doesNotMatch(html,/arena-review|arena-cancel/);
});
test('own pending arena request is visible but does not consume approved capacity',()=>{
  const s=fixture();s.facilities.arenaBookings=[{id:'own-request',resourceId:'arena-a',date:s.today,start:'12:00',end:'13:00',participants:4,status:'requested',exclusive:true,horseId:'h1',requesterId:actorId,requesterName:'Eigen ruiter',activity:'Rustig oefenen',note:'Een volledige aanvraagreden',decisionNote:'',canCancel:true,canDecide:false}];
  const html=renderArenaPlanning(s,createContext(s));assert.match(html,/Een volledige aanvraagreden/);assert.match(html,/De plek is pas gereserveerd na goedkeuring/);assert.doesNotMatch(html,/4 van 4 plekken bezet|data-action="arena-review"/);
  assert.match(html,/data-action="arena-cancel" data-id="own-request"/);
});
test('server-disabled terminal arena row has no approval or cancel action',()=>{
  const s=fixture();s.facilities.arenaBookings=[{id:'closed',resourceId:'arena-a',date:s.today,start:'12:00',end:'13:00',participants:1,status:'cancelled',exclusive:false,horseId:'h1',requesterId:actorId,requesterName:'Eigen ruiter',activity:'Training',note:'',decisionNote:'',canCancel:false,canDecide:false}];
  const html=renderArenaPlanning(s,createContext(s));assert.match(html,/Geannuleerd/);assert.doesNotMatch(html,/data-action="arena-cancel"|data-action="arena-review"/);
});
test('groom selecting management and trainer preferences cannot create booking rights',()=>{
  const s=fixture();s.backend.actor.roleKind='groom';s.backend.capabilities={};s.backend.p2.canBook=false;s.functionProfiles={[actorId]:['manager','trainer']};
  const actions=getProfileQuickActions(s);assert.ok(actions.some(a=>a.route==='arena-planning'));assert.ok(!actions.some(a=>['arena-reserve','manage-stable','team-invite','new-task','new-activity'].includes(a.action)));
  const h=controller(s,createArenaController);h.controller.handleAction('arena-reserve',{dataset:{}});assert.ok(!h.events.some(e=>e[0]==='modal'));
});
test('UUID identity uses role defaults and profile keeps later functions unavailable',()=>{
  const s=fixture();assert.deepEqual(getFunctions(s),['rider','trainer']);const html=renderRoleProfile(s,createContext(s));
  for(const id of ['breeder','partner','organizer','sponsor'])assert.match(html,new RegExp(`value="${id}" disabled`));
  assert.match(html,/Een functie kiezen geeft geen extra toegang/);
});
test('connected menu covers every catalog item once and preserves availability of unrelated proposals',()=>{
  const s=fixture();s.menuMode='all';const html=renderMenu(s,createContext(s));const ids=[...html.matchAll(/data-action="menu-item" data-id="([^"]+)"/g)].map(m=>m[1]);
  assert.deepEqual(ids.sort(),MENU_GROUPS.flatMap(g=>g.items.map(i=>i.id)).sort());
  const arena=html.match(/<button class="menu-item"[^>]*data-id="arenas"[\s\S]*?<\/button>/)?.[0];assert.ok(arena);assert.doesNotMatch(arena,/Prototype|Binnenkort/);
  assert.match(html,/Binnenkort/);
});
test('resource name and instruction output escape markup rather than injecting it',()=>{
  const s=fixture();s.facilities.resources[0].name='<img src=x onerror=alert(1)>';s.facilities.bookings[0].note='<script>not executable</script>';
  const html=renderPastures(s,createContext(s))+renderFacilities(s,createContext(s));
  assert.doesNotMatch(html,/<script>|<img src=x onerror=/);assert.match(html,/&lt;script&gt;/);assert.match(html,/&lt;img src=x onerror=/);
});
