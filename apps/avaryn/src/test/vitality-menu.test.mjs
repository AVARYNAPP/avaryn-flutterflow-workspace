import test from 'node:test';
import assert from 'node:assert/strict';
import {MENU_GROUPS,PLAN_DEFINITIONS,SUBSCRIPTION_ROWS,findMenuItem} from '../product-structure.js';
import {getProfileQuickActions,getPreferredMenuIds} from '../role-profile.js';
import {renderMenu,renderQuickActions,renderPlans} from '../menu-ui.js';
import {createContext} from '../components.js';
import {INITIAL_STATE} from '../data.js';
import {canManage,canPlan,canShareMoment} from '../horse-access.js';

const group=MENU_GROUPS.find(g=>g.id==='rider-vitality');
const create=(persona,functions)=>({...structuredClone(INITIAL_STATE),persona,functionProfiles:{[persona]:functions}});
const personalActions=['vitality-warmup','vitality-reflection','vitality-focus','vitality-share'];

test('eight requested sections including exercise library resolve into the same module contract',()=>{assert.deepEqual(group.items.map(i=>i.target.value),['exercises','warmup','cooldown','mobility','focus','goals','feeling','journal']);assert(group.items.every(i=>i.target.kind==='vitality'));assert(group.items.every(i=>i.description&&i.label));assert.equal(new Set(MENU_GROUPS.flatMap(g=>g.items.map(i=>i.id))).size,MENU_GROUPS.flatMap(g=>g.items).length);});
test('goals is honestly later while implemented lightweight views are prototype',()=>{assert.equal(findMenuItem('vitality-goals').status,'Binnenkort');assert(group.items.filter(i=>i.id!=='vitality-goals').every(i=>i.status==='Prototype'));});

for(const persona of ['manager','groom','owner','rider'])for(const functions of [['manager'],['groom'],['owner'],['rider'],['trainer'],['groom','trainer']]){
 test(`${persona} preferences ${functions.join('+')} control only personal vitality entries`,()=>{
  const state=create(persona,functions),before=JSON.stringify(state),rights=[canManage(state),canPlan(state),canShareMoment(state)];
  const eligible=functions.some(f=>['owner','rider','trainer'].includes(f));
  const actions=getProfileQuickActions(state),vitality=actions.filter(a=>a.group==='rider-vitality');
  assert.equal(vitality.length,eligible?4:0);
  if(eligible){assert.deepEqual(vitality.map(a=>a.action),personalActions);assert.equal(vitality.find(a=>a.action==='vitality-reflection').label,'Trainingsreflectie');assert.deepEqual(vitality.map(a=>a.status),['Prototype','Prototype','Prototype','Voorbeeld']);assert(vitality.every(a=>!a.coming));assert(!actions.some(a=>a.action==='share-moment'||a.action==='quick-note'||a.feature==='goals'));}
  assert.equal(getPreferredMenuIds(state).includes('vitality-warmup'),eligible);
  assert.equal(getPreferredMenuIds(state).includes('vitality-exercises'),eligible);
  assert.deepEqual([canManage(state),canPlan(state),canShareMoment(state)],rights);
  assert.equal(JSON.stringify(state),before);
 });
}

test('real actor UUID with rider preference gets connected personal actions and a share example without new rights',()=>{
 const state=create('groom',[]);
 state.backend={connected:true,actor:{id:'10000000-0000-4000-8000-000000000001',roleKind:'groom',name:'Ruiter',initials:'R',roleLabel:'Groom',accessibleHorseIds:[],personalHorseIds:[],assignedHorseIds:[]},capabilities:{canManage:false,canPlan:false,canShareMoment:false}};
 state.functionProfiles={[state.backend.actor.id]:['groom','rider']};
 const actions=getProfileQuickActions(state);
 const personal=actions.filter(a=>a.group==='rider-vitality');assert.deepEqual(personal.map(a=>a.action),personalActions);assert.deepEqual(personal.map(a=>a.status),['','','','Voorbeeld']);assert(personal.every(a=>!a.coming));
 assert(!actions.some(a=>['new-activity','new-task','arena-reserve','team-invite','manage-stable','share-moment'].includes(a.action)));
 assert.equal(canShareMoment(state),false);assert.equal(canPlan(state),false);assert.equal(canManage(state),false);
});
test('ordinary non-vitality sharing guard stays in force',()=>{const state=create('groom',['groom']);assert(!getProfileQuickActions(state).some(a=>a.action==='share-moment'||a.action==='vitality-share'));});
test('collapsed demo plus group shows its three prototypes and share example once',()=>{
 const state=create('manager',['owner','manager']),html=renderQuickActions(state,createContext(state));
 assert.match(html,/<details class="menu-group">/);assert.doesNotMatch(html,/<details class="menu-group" open/);
 for(const action of personalActions)assert.equal((html.match(new RegExp('data-action="'+action+'"','g'))||[]).length,1);
 assert.match(html,/>Trainingsreflectie<\/strong>/);assert.doesNotMatch(html,/Trainingsnotitie toevoegen/);
 assert.match(html,/Persoonlijke voorbereiding en terugblik · Prototype/);assert.match(html,/Dit deelvoorbeeld verstuurt niets/);assert.doesNotMatch(html,/data-action="share-moment"/);
});
test('personal menu shows privacy text; manager-only profile sees group through Everything',()=>{
 const eligible=create('owner',['owner']),ownerHtml=renderMenu(eligible,createContext(eligible));
 assert.match(ownerHtml,/Jouw ruitergegevens zijn persoonlijk\. Deel alleen wat jij kiest\./);assert.match(ownerHtml,/data-id="vitality-journal"/);assert.match(ownerHtml,/data-id="vitality-exercises"/);
 const manager=create('manager',['manager']);assert.doesNotMatch(renderMenu(manager,createContext(manager)),/data-id="vitality-warmup"/);
 manager.menuMode='all';assert.match(renderMenu(manager,createContext(manager)),/data-id="vitality-warmup"/);
});
test('plans retain proposal/no-paywall privacy distinction and all requested levels',()=>{
 const state=create('owner',['owner']),html=renderPlans(state,createContext(state));
 for(const name of ['Free / Starter','Rider Plus','Stable Pro','Business / Elite'])assert(html.includes(name));
 assert.match(html,/geen prijzen, betalingen of blokkades/);assert.match(html,/geven geen toegang tot je warming-ups/);assert(!/checkout|type="submit"/i.test(html));
 assert(SUBSCRIPTION_ROWS.some(r=>r.feature==='Ruiter-teamprogramma’s en clinics'&&r.business.includes('Later')));
 assert(SUBSCRIPTION_ROWS.some(r=>r.feature==='Rider Journal en trainingshistorie'&&r.free.includes('beperkt')));
 const library=SUBSCRIPTION_ROWS.find(r=>r.feature==='Oefenbibliotheek, video’s en routines per discipline');
 assert(library);assert.match(library.plus,/Volledige bibliotheek, video’s en disciplineroutines — voorstel/);assert.match(library.pro,/toestemming/);assert.match(library.reason,/geen upload, streaming of huidige betaalgrens/);
 assert(SUBSCRIPTION_ROWS.some(r=>r.feature==='Focuspunten en trainingsdoelen'&&r.free.includes('beperkt')));
 const starter=PLAN_DEFINITIONS.find(p=>p.name==='Free / Starter'),plus=PLAN_DEFINITIONS.find(p=>p.name==='Rider Plus');
 assert.match(starter.description,/beperkt aantal reflecties en focuspunten als voorstel/);assert.match(plus.description,/video’s, routines per discipline, trainingshistorie, doelen en voortgang als voorstel/);
 assert.match(html,/Echte video’s, uitgebreide trainingshistorie en personalisatie volgen later/);

});
