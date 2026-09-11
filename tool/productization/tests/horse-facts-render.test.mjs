import test from 'node:test';
import assert from 'node:assert/strict';
import {normalizeLoad} from '../../../apps/avaryn/src/backend-client.js';
import {renderHorseOverview,renderHorseHeader} from '../../../apps/avaryn/src/horses.js';
import {renderHorseLocation} from '../../../apps/avaryn/src/facilities.js';
import {createEmptyFacilities} from '../../../apps/avaryn/src/facility-data.js';
import {createContext} from '../../../apps/avaryn/src/components.js';
import {raw,uid,horse,org,actor,DAY} from '../../../apps/avaryn/src/test/feeding-fixture.mjs';
const NOW=Date.parse('2026-09-11T10:00:00Z'),PAST='2026-09-10T10:00:00Z',FUTURE='2026-09-12T10:00:00Z';
function input(){const data=raw();data.horses[0].is_primary_authority=false;data.day.items=[];data.schedules[horse]=[];data.workspace.memberships.push({status:'active',profile_id:uid(99),profile_name:'Unrelated selected-stable groom',role_code:'groom'});data.details[horse]={residencies:[],relationships:[],person_ownerships:[]};return data;}
function view(data=input()){const s=normalizeLoad(data,{day:DAY,organizationId:org});return {...s,today:DAY,facilityDate:DAY,horseId:horse,route:'horse-overview',theme:'light',facilities:createEmptyFacilities()};}
const overview=s=>renderHorseOverview(s,createContext(s));
const location=s=>renderHorseLocation(s,createContext(s),horse);

test('unlinked horse renders neither selected stable nor its team as horse facts',()=>{
 const s=view(),html=overview(s);assert.equal(s.horses[0].organizationId,null);assert.equal(s.horses[0].stable,'');assert.deepEqual(s.horses[0].team,[]);
 assert.match(html,/Nog geen verblijfplaats gekoppeld/);assert.match(html,/Er zijn nog geen betrokkenen aan dit paard gekoppeld/);assert.doesNotMatch(html,/Unrelated selected-stable groom|Teststal|<dt>Stal<\/dt>|<dt>Eigenaar<\/dt>/);assert.doesNotMatch(html,/data-action="horse-placement"/);
 assert.equal(s.horses[0].image,'assets/horse-placeholder.svg');assert.doesNotMatch(html,/assets\/(?:orion|nova)\.png/);
});
test('missing per-horse team cannot borrow current or stale global team members',()=>{
 const s=view();delete s.horses[0].team;s.team=[{name:'Private cached person',role:'Owner'}];s.stableName='Private cached stable';const html=overview(s);assert.doesNotMatch(html,/Private cached person|Private cached stable/);assert.match(html,/nog geen betrokkenen/);
});
test('canonical current horse team, owner and actual other residency remain visible',()=>{
 const data=input();data.details[horse]={residencies:[{status:'active',organization_id:uid(40),organization_name:'Actual residence'}],relationships:[{status:'active',profile_id:uid(41),profile_name:'Actual horse rider',relationship_type:'rider'}],person_ownerships:[{status:'active',profile_name:'Recorded horse owner'}]};const s=view(data),html=overview(s);
 assert.match(html,/Actual residence/);assert.match(html,/Actual horse rider/);assert.match(html,/Recorded horse owner/);assert.doesNotMatch(html,/Unrelated selected-stable groom|Teststal/);assert.doesNotMatch(html,/data-action="horse-placement"/);assert.match(renderHorseHeader(s,createContext(s)),/Actual residence/);
});
test('future, ended and elapsed facts never replace the currently valid records',t=>{
 t.mock.method(Date,'now',()=>NOW);const data=input(),validity=[{label:'Future',status:'active',valid_from:FUTURE},{label:'Ended',status:'ended',valid_from:PAST},{label:'Expired',status:'active',valid_from:PAST,valid_until:new Date(NOW).toISOString()},{label:'Malformed',status:'active',valid_from:'invalid'},{label:'Current',status:'active',valid_from:new Date(NOW).toISOString(),valid_until:FUTURE}];
 data.details[horse]={residencies:validity.map((r,i)=>({...r,organization_id:uid(40+i),organization_name:r.label+' residence'})),relationships:validity.map((r,i)=>({...r,profile_id:uid(50+i),profile_name:r.label+' rider',relationship_type:'rider'})),person_ownerships:validity.map(r=>({...r,profile_name:r.label+' owner'}))};
 const s=view(data),html=overview(s);assert.equal(s.horses[0].stable,'Current residence');assert.deepEqual(s.horses[0].team.map(r=>r.name),['Current rider']);assert.equal(s.horses[0].owner,'Current owner');assert.doesNotMatch(html,/(Future|Ended|Expired|Malformed) (residence|rider|owner)/);
});
test('primary authority is identified as administrator, never invented as legal owner',()=>{
 const data=input();data.horses[0].is_primary_authority=true;const s=view(data),html=overview(s);assert.deepEqual(s.horses[0].team,[{id:actor,name:'Testactor',role:'Hoofdbeheerder'}]);assert.equal(s.horses[0].owner,'');assert.match(html,/Hoofdbeheerder/);assert.doesNotMatch(html,/<dt>Eigenaar<\/dt>/);
});
test('canonical self relationship is retained without a duplicate inferred team member',()=>{
 const data=input();data.horses[0].is_primary_authority=true;data.details[horse].relationships=[{status:'active',profile_id:actor,profile_name:'Canonical self name',relationship_type:'rider'}];const s=view(data);assert.equal(s.horses[0].team.length,1);assert.equal(s.horses[0].team[0].name,'Canonical self name');assert.match(overview(s),/Canonical self name/);
});
for(const [name,horseOrg,currentOrg,permission,manager,expected] of [
 ['exact permission and same organization',org,org,true,false,true],
 ['manager role alone',org,org,false,true,false],
 ['missing exact permission',org,org,undefined,true,false],
 ['string true is not permission',org,org,'true',true,false],
 ['different active organization',uid(40),org,true,true,false],
 ['unlinked horse',null,org,true,true,false],
 ['personal current context',org,null,true,true,false],
])test('placement action: '+name,()=>{
 const s=view();s.horses[0].organizationId=horseOrg;s.horses[0].stable=horseOrg?'Actual horse stable':'';s.backend.organizationId=currentOrg;s.backend.permissionCodes['organization.residencies.manage']=permission;s.backend.capabilities.canManage=manager;s.backend.p2={connected:true,canManage:manager};
 assert.equal(location(s).includes('data-action="horse-placement"'),expected);
});
test('canonical existing box and outdoor location remain associated with this horse only',()=>{
 const s=view();s.horses[0].organizationId=org;s.horses[0].stable='Actual residence';s.backend.p2={connected:true,canManage:true};s.facilities.resources=[{id:'box',name:'Box 04',kind:'stall',status:'available'},{id:'pasture',name:'Weide 1',kind:'pasture',status:'available'}];s.facilities.placements=[{horseId:horse,resourceId:'box'}];s.facilities.bookings=[{horseIds:[horse],resourceId:'pasture',date:DAY,start:'08:00',end:'12:00',status:'approved'}];
 const html=location(s);assert.match(html,/Box 04/);assert.match(html,/Weide 1/);assert.match(html,/08:00.*12:00/);assert.match(html,/Actual residence/);assert.doesNotMatch(html,/Teststal/);
});
test('unavailable horse renders no private facts or placement controls',()=>{
 const s=view();s.horseId=uid(200);const html=overview(s);assert.match(html,/Dit paard staat niet in jouw overzicht/);assert.doesNotMatch(html,/Testactor|Testpaard|horse-placement|Unrelated/);assert.equal(renderHorseLocation(s,createContext(s),uid(200)),'');
});
test('canonical names stay HTML escaped in person, owner and residence templates',()=>{
 const data=input(),danger='<img src=x onerror="private()">';data.details[horse]={residencies:[{status:'active',organization_id:org,organization_name:danger}],relationships:[{status:'active',profile_id:uid(50),profile_name:danger,relationship_type:'rider'}],person_ownerships:[{status:'active',profile_name:danger}]};const html=overview(view(data));assert.doesNotMatch(html,/<img src=x|onerror="private/);assert.match(html,/&lt;img src=x onerror=&quot;private\(\)&quot;&gt;/);
});
