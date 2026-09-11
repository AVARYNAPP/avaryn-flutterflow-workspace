import test from 'node:test';
import assert from 'node:assert/strict';
import {getActiveStableView} from '../stable-view.js';
import {createContext} from '../components.js';
import {renderStable,renderToday,feedPreview} from '../daily-ui.js';
import {renderStableFeeding,renderHorseFeeding} from '../feeding.js';
import {INITIAL_STATE} from '../data.js';
const fixture=()=>{
 const day='2026-09-11',h=(id,name)=>({id,name,image:'assets/orion.png',stable:'Stal A',box:'',imageIsPlaceholder:true});
 const activity=(id,horseId,organizationId,time)=>({id,horseId,organizationId,title:id,date:day,time,end:'17:00',status:'planned',type:'Training',person:'Bevoegde actor',location:'',note:''});
 const meal=(id)=>({status:'Basisvoeding actief',note:'',meals:[{name:'Ochtend',code:'morning',time:'08:00',items:[{product:id+' product',amount:'1 kg',note:id+' volledige instructie'}]},{name:'Middag',code:'afternoon',items:[]},{name:'Avond',code:'evening',items:[]}]});
 return {route:'stable',today:day,selectedDay:day,theme:'light',horseId:'personal',horseFilter:'personal',stableName:'Stal A',stableLocation:'',
  horses:[h('orion','Orion'),h('nova','Nova'),h('personal','Persoonlijk paard')],
  activities:[activity('Stal algemeen',null,'A','07:00'),activity('Orion afspraak','orion',null,'08:00'),activity('Nova afspraak','nova','A','09:00'),activity('Persoonlijke afspraak','personal',null,'10:00'),activity('Andere stal algemeen',null,'B','11:00')],
  tasks:[{id:'task-a',organizationId:'A',title:'Taak in A',date:day,time:'09:00',location:'Stal A',assignee:'Actor',note:'A taak',status:'open'},{id:'task-b',organizationId:'B',title:'Taak in B',date:day,time:'09:00',location:'Stal B',assignee:'Actor',note:'B taak',status:'open'}],
  feeding:{orion:meal('Orion'),nova:meal('Nova'),personal:meal('Persoonlijk')},team:[{name:'Lid van A',initials:'LA'}],
  facilities:{schema:1,arenaSetupVersion:1,resources:[],placements:[],bookings:[],arenaBookings:[],tackRoom:false},
  backend:{connected:true,organizationId:'A',stableHorseIds:['orion','nova'],todayDate:day,todayTasks:[],todayActivities:[],
   actor:{id:'actor',name:'Bevoegde actor',initials:'BA',roleKind:'manager',roleLabel:'Manager',personalHorseIds:['personal'],accessibleHorseIds:['orion','nova','personal'],assignedHorseIds:[]},
   capabilities:{canManage:true,canViewTeam:true,canPlan:true},horseCapabilities:{orion:{view:true},nova:{view:true},personal:{view:true,feeding:true}},p2:{connected:true,canManage:true,canBook:true}}
 };
};
test('active stable has exactly its two server-listed horses, activities/feeding and current-organization tasks',()=>{
 const s=fixture(),before=structuredClone(s),view=getActiveStableView(s);assert.deepEqual(view.horses.map(h=>h.id),['orion','nova']);assert.deepEqual(view.activities.map(a=>a.id),['Stal algemeen','Orion afspraak','Nova afspraak']);assert.deepEqual(view.tasks.map(t=>t.id),['task-a']);assert.deepEqual(Object.keys(view.feeding),['orion','nova']);assert.equal(view.team,s.team);assert.deepEqual(s,before,'Presentation filtering never mutates the global accessible state');
 const ctx=createContext(s),stable=renderStable(s,ctx),feeding=renderStableFeeding(s,ctx),preview=feedPreview(s,ctx);
 assert.match(stable,/<strong>2<\/strong><span>Paarden op stal/);assert.match(stable,/<strong>3<\/strong><span>Afspraken vandaag/);assert.match(stable,/<strong>1<\/strong><span>Open taken/);assert(stable.includes('Stal algemeen'));assert(stable.includes('>Lid</small>'));assert(stable.includes('data-action="team"'));assert(!stable.includes('Persoonlijke afspraak'));assert(!stable.includes('Taak in B'));
 for(const html of [stable,feeding,preview]){assert(html.includes('Orion'));assert(html.includes('Nova'));assert(!html.includes('Persoonlijk'));}
 assert(feeding.includes('Orion volledige instructie'));assert(preview.includes('data-route="stable-feed"'));
 // Today still shows the user's personal horses; only its feed summary follows the active stable.
 const today=renderToday(s,ctx);assert(today.includes('Persoonlijk paard'));const feedFragment=today.slice(today.indexOf('<div class="feed-preview">'),today.indexOf('</aside>'));assert(!feedFragment.includes('Persoonlijk product'));
 assert(renderHorseFeeding(s,ctx).includes('Persoonlijk volledige instructie'),'Direct personal horse feeding remains available');
});
test('null organization retains personal overview and its feeding instead of applying stale stable IDs',()=>{
 const s=fixture();s.backend.organizationId=null;s.backend.capabilities.canManage=false;assert.equal(getActiveStableView(s),s);const ctx=createContext(s);
 for(const html of [renderStable(s,ctx),renderStableFeeding(s,ctx),feedPreview(s,ctx)]){assert(html.includes('Persoonlijk'));assert(html.includes('Orion'));assert(html.includes('Nova'));}
 assert.match(renderStable(s,ctx),/<strong>3<\/strong><span>Paarden voor jou/);
});
test('demo scope remains unchanged; empty active stable never falls back to personal horses',()=>{
 const demo=structuredClone(INITIAL_STATE);assert.equal(getActiveStableView(demo),demo);
 const s=fixture();s.backend.stableHorseIds=[];const v=getActiveStableView(s);assert.equal(v.horses.length,0);assert.deepEqual(v.feeding,{});assert.deepEqual(v.activities.map(a=>a.id),['Stal algemeen']);const html=renderStableFeeding(s,createContext(s));assert(html.includes('Stal A'));assert(!html.includes('Persoonlijk'));assert(!html.includes('Orion'));
});
