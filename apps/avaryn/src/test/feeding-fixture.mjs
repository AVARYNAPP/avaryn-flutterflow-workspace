import {createBackendClient} from '../backend-client.js';
const uid=n=>`10000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const actor=uid(1),horse=uid(2),org=uid(3),task=uid(4),activity=uid(5),plan=uid(6),item=uid(7),versionId=uid(8);
const DAY='2026-09-10', response=(data,status=200)=>({ok:status>=200&&status<300,status,json:async()=>data});
const session=(user=actor,expires=Date.now()/1000+3600)=>({access_token:'access-'+user,refresh_token:'refresh-'+user,user:{id:user},expires_at:expires});
const defer=()=>{let resolve;const promise=new Promise(r=>resolve=r);return {promise,resolve};};
const next=()=>new Promise(r=>setImmediate(r));
function raw(){return {
 profile:[{profile_status:'active',profile_id:actor,display_name:'Testactor',row_version:2,theme_mode:'light'}],
 day:{on_date:DAY,calendar:{today_date:DAY},items:[{source_type:'stable_task',source_id:task,task_id:task,title:'Mijn taak',organization_id:org,horse_id:horse,due_date:DAY,status:'open',row_version:2,can_complete:true},{source_type:'horse_activity',source_id:activity,schedule_item_id:activity,horse_id:horse,item_kind:'training',title:'Training',scheduled_start_at:DAY+'T08:00:14.321Z',scheduled_end_at:DAY+'T09:00:14.321Z',status:'planned',row_version:3,can_complete:true,participant_profile_ids:[actor]}]},
 horses:[{horse_id:horse,display_name:'Testpaard',lifecycle_status:'active',can_edit:true,can_manage:true,can_manage_planning:true,can_manage_feeding:true,is_primary_authority:true,row_version:1}],
 stables:[{organization_id:org,name:'Teststal',lifecycle_status:'active',role_codes:['primary_admin']}],
 workspace:{organization:{id:org,name:'Teststal'},capabilities:{'organization.edit':true,'organization.memberships.view':true},horses:[{horse_id:horse}],memberships:[{status:'active',profile_id:actor,profile_name:'Testactor',role_code:'primary_admin',role_name:'Beheerder'}]},
 round1:{can_manage_tasks:true,task_candidates:[{profile_id:actor,display_name:'Testactor'}],places:[],activities:[{activity_kind:'stable_task',activity_id:task,horse_id:horse,title:'Nieuwste taak',due_date:DAY,status:'open',row_version:3,can_complete:false,assignee_profile_id:uid(9)}]},
 schedules:{[horse]:[{schedule_item_id:activity,horse_id:horse,item_kind:'training',title:'Training',scheduled_start_at:DAY+'T08:00:14.321Z',scheduled_end_at:DAY+'T09:00:14.321Z',state:'planned',row_version:3,is_mine:true,participant_profile_ids:[actor,uid(10)],participant_names:['Testactor','Andere deelnemer'],source_timezone:'Europe/Amsterdam'}]},
 details:{[horse]:{residencies:[{status:'active',organization_id:org,organization_name:'Teststal'}]}},
 feeding:{[horse]:{plans:[{feeding_plan_id:plan,plan_type:'standard',status:'active',effective_from:'2026-01-01',active_version_id:versionId,row_version:5,versions:[{feeding_plan_version_id:versionId,items:[{feeding_plan_item_id:item,row_version:2,product_brand:'Beschrijvend product',product_name:'roughage',product_variant:'roughage',planned_quantity:0.25,unit_code:'kg',instruction:'Volledige notitie',round_code:'morning'}]}]}]}}
};}
function harness({data=raw(),override,timeoutMs=5000,expires}={}){
 const calls=[],memory=new Map();let currentUser=actor;
 const routes={get_current_account_profile:()=>data.profile,get_c010_personal_day:()=>data.day,list_c010_horses:()=>data.horses,list_c010_stables:()=>data.stables,get_c010_stable_workspace:()=>data.workspace,get_c010_stable_round1_workspace:()=>data.round1,list_c010_horse_schedule:p=>data.schedules[p.p_horse_id]||[],get_canonical_horse_workspace:p=>data.details[p.p_horse_id]||{},get_canonical_horse_feeding:p=>data.feeding[p.p_horse_id]||{plans:[]}};
 const fetchImpl=async(path,options)=>{const body=options.body?JSON.parse(options.body):null;calls.push({path,body,headers:options.headers});if(override){const result=await override(path,body,options);if(result!==undefined)return result;}
  if(path.includes('grant_type=password')){currentUser=body.email==='second'?uid(20):actor;return response(session(currentUser,expires));}
  if(path.includes('grant_type=refresh_token'))return response(session(currentUser));
  if(path.endsWith('/auth/v1/user'))return response({id:currentUser});
  if(path.endsWith('/auth/v1/logout?scope=local'))return response(null,204);
  const name=path.split('/').at(-1);if(routes[name])return response(routes[name](body));
  return response(name.includes('feeding')?{feeding_plan_id:plan,plan_row_version:6}:name.includes('activity')||name.includes('schedule')?{schedule_item_id:activity,row_version:4,state:'completed'}:{task_id:task,row_version:4,status:'completed'});
 };
 const storage={getItem:k=>memory.get(k),setItem:(k,v)=>memory.set(k,v),removeItem:k=>memory.delete(k)};
 const client=createBackendClient({fetchImpl,storage,timeoutMs});
 return {client,calls,memory,data,ready:async()=>{await client.login('first','test');return client.load();}};
}


export {uid,actor,horse,org,plan,item,versionId,DAY,response,raw,harness,defer,next};
