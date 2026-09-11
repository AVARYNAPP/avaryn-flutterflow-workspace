/** Real authenticated P1 adapter. No PERSONAS, service credentials or fixture data.
 * Server /api injects the publishable key and private gateway header. Only the
 * user's Auth session is retained in sessionStorage; domain state stays in RAM.
 */
import {horseMediaPath} from './media-path.js';
const ZONE = 'Europe/Amsterdam';
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const KINDS = {training:'Training',care:'Verzorging',farrier:'Hoefsmid',veterinary:'Dierenarts',competition:'Wedstrijd',feeding:'Voeding',task:'Taak',transport:'Vervoer',other:'Overig'};
const MEALS = {morning:'Ochtend',afternoon:'Middag',evening:'Avond'};
const UNITS = {g:'g',kg:'kg',ml:'ml',l:'l',scoop:'schep',portion:'portie',piece:'stuk',bale:'baal'};
const ROLES = {primary_admin:'Beheerder',manager:'Stalmanager',rider:'Ruiter',trainer:'Trainer',groom:'Groom',beheerder:'Beheerder'};
const rows = value => Array.isArray(value) ? value : [];
const initials = value => String(value||'').split(/\s+/).filter(Boolean).slice(0,2).map(v=>v[0]).join('').toUpperCase();
const unique = values => [...new Set(values.filter(Boolean))];
const first = value => Array.isArray(value) ? value[0] : value;
const need = (value, message='Controleer de ingevulde gegevens.') => {if(!value)throw new BackendError(message,{code:'INPUT_INVALID'});};
const id = value => {need(typeof value==='string'&&UUID.test(value));return value;};
const validDay = value => typeof value==='string' && /^\d{4}-\d{2}-\d{2}$/.test(value) && Number.isFinite(Date.parse(value)) && new Date(value).toISOString().slice(0,10)===value;
const version = value => {need(Number.isSafeInteger(Number(value))&&Number(value)>0);return Number(value);};
const plusDays = (date, days) => new Date(Date.parse(date+'T12:00:00Z')+days*86400000).toISOString().slice(0,10);

export class BackendError extends Error {
  constructor(message,{code='BACKEND_UNAVAILABLE',status=0,uncertain=false,accessLost=false}={}) {
    super(message);this.name='BackendError';Object.assign(this,{code,status,uncertain,accessLost});
  }
}

function verifiedZone(value) {
  try{need(typeof value==='string'&&value.length>0);return new Intl.DateTimeFormat('en',{timeZone:value}).resolvedOptions().timeZone;}
  catch{throw new BackendError('De tijdzone van je account is niet beschikbaar. Controleer je profiel en laad de gegevens opnieuw.',{code:'INVALID_ACCOUNT_TIME_ZONE'});}
}
function accountZone(profile,personal) {
  const zones=[profile?.time_zone,personal?.calendar?.time_zone,personal?.time_zone].filter(v=>v!==undefined).map(verifiedZone);
  if(new Set(zones).size>1)throw new BackendError('Je tijdzone is intussen gewijzigd. Laad de actuele gegevens opnieuw.',{code:'CALENDAR_TIME_ZONE_MISMATCH'});
  // Compatibility for older responses without zone fields; never use the
  // browser's implicit zone or replace an explicitly invalid server value.
  return zones[0]||ZONE;
}

export function localParts(instant, timeZone=ZONE) {
  const date=new Date(instant);need(Number.isFinite(date.getTime()),'De datum of tijd is niet geldig.');
  const parts=Object.fromEntries(new Intl.DateTimeFormat('en-GB',{timeZone:verifiedZone(timeZone),year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',second:'2-digit',hourCycle:'h23'}).formatToParts(date).map(p=>[p.type,p.value]));
  return {date:`${parts.year}-${parts.month}-${parts.day}`,time:`${parts.hour}:${parts.minute}`,seconds:parts.second};
}

/** A civil account time must identify exactly one instant (DST safe). */
export function civilInstant(day,time,timeZone) {
  const zone=verifiedZone(timeZone);
  need(validDay(day)&&/^([01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$/.test(time),'Vul een geldige datum en tijd in.');
  const seconds=time.length===8?time.slice(6):'00';
  const wall=day+'T'+time.slice(0,5)+':'+seconds;const nominal=Date.parse(wall+'Z');
  need(Number.isFinite(nominal));const offsets=new Set();
  for(const hours of [-36,-12,0,12,36]){
    const probe=nominal+hours*3600000;const p=localParts(probe,zone);
    offsets.add(Date.parse(p.date+'T'+p.time+':'+p.seconds+'Z')-probe);
  }
  const candidates=[...offsets].map(offset=>nominal-offset).filter(ms=>{
    const p=localParts(ms,zone);return p.date===day&&p.time===time.slice(0,5)&&p.seconds===seconds;
  });
  need(candidates.length===1,'Dit tijdstip bestaat niet of komt tweemaal voor door de klokwisseling. Kies een ander tijdstip.');
  return new Date(candidates[0]).toISOString();
}
export const amsterdamInstant=(day,time)=>civilInstant(day,time,ZONE);

function friendly(status,body,write) {
  const code=String(body?.message||body?.code||body?.error_code||body?.error||'');
  if(code==='TEMPORARY_FEEDING_PLAN_CONFLICT')return new BackendError('Een tijdelijk schema heeft basisvoeding nodig die de hele periode dekt en mag niet overlappen met een ander tijdelijk schema. Controleer de basisvoeding en datums.',{code,status});
  if(code==='STANDARD_FEEDING_PLAN_OVERLAP')return new BackendError('Er bestaat al basisvoeding voor deze periode. Open de bestaande basisvoeding om die aan te passen.',{code,status});
  if(code==='CROSS_STABLE_HORSE_DENIED')return new BackendError('Dit paard is niet beschikbaar voor deze taak of verantwoordelijke.',{code,status});
  if(status===409||/STALE|VERSION_STALE/.test(code))return new BackendError('Deze gegevens zijn intussen gewijzigd. Laad de actuele gegevens en probeer opnieuw.',{code,status});
  if(status===401)return new BackendError('Meld je opnieuw aan om verder te gaan.',{code,status,accessLost:true});
  if(status===403||body?.code==='42501')return new BackendError('Je hebt geen toegang tot deze handeling. Laad de actuele gegevens.',{code,status,accessLost:true});
  if(status>=500)return new BackendError(write?'Opslaan is nog niet bevestigd. Laad de gegevens voordat je opnieuw probeert.':'AVARYN is tijdelijk niet bereikbaar. Probeer het opnieuw.',{code,status,uncertain:write});
  return new BackendError(/INVALID_LOGIN|invalid_credentials|Invalid login/i.test(code)?'Controleer je e-mailadres en wachtwoord.':'Controleer de ingevulde gegevens en probeer opnieuw.',{code,status});
}

function normalizedActivity(row,actor,horseCaps,personal=false,timeZone=ZONE) {
  const start=row.scheduled_start_at;const p=start?localParts(start,timeZone):{date:row.due_date,time:row.due_time?.slice(0,5)||''};
  const end=row.scheduled_end_at?localParts(row.scheduled_end_at,timeZone):null;
  const kind=row.item_kind||'other', status=row.state||row.status;
  return {id:row.schedule_item_id||row.source_id,horseId:row.horse_id,type:KINDS[kind]||'Activiteit',itemKind:kind,title:row.title||KINDS[kind]||'Activiteit',
    date:p.date,time:p.time,end:end?.time||'',endDate:end?.date||p.date,status,
    person:rows(row.participant_names).join(' · ')||(personal?actor.name:''),location:row.location_name||'',note:row.instruction||'',
    organizationId:row.organization_id||null,organizationName:row.organization_name||'',rowVersion:Number(row.row_version),
    isMine:personal||row.is_mine===true,canComplete:personal?row.can_complete===true:row.is_mine===true&&horseCaps[row.horse_id]?.planning===true&&['planned','in_progress'].includes(status),
    participantProfileIds:rows(row.participant_profile_ids),scheduledStartAt:start,scheduledEndAt:row.scheduled_end_at||null,sourceTimezone:row.source_timezone||timeZone,displayTimezone:timeZone,
    priority:row.priority||'normal',stateReason:row.state_reason||null,sourceType:'horse_activity'};
}

function normalizedTask(row,org,actor) {
  return {id:row.task_id||row.activity_id||row.source_id,horseId:row.horse_id||null,title:row.title||'Taak',
    date:row.due_date,time:row.due_time?.slice(0,5)||'',location:row.location_name||'',note:row.note??row.instruction??'',status:row.status,
    assignee:row.assignee_name||(row.source_type==='stable_task'?actor.name:''),assigneeProfileId:row.assignee_profile_id||(row.source_type==='stable_task'?actor.id:null),
    organizationId:row.organization_id||org?.id,organizationName:row.organization_name||org?.name||'',rowVersion:Number(row.row_version),
    category:row.category||row.item_kind||'other',stablePlaceId:row.stable_place_id||null,canComplete:row.can_complete===true,sourceType:'stable_task'};
}

export function normalizeFeeding(data,day) {
  const plans=rows(data?.plans).map(plan=>{
    const v=rows(plan.versions).find(v=>v.feeding_plan_version_id===plan.active_version_id)||rows(plan.versions)[0];
    const items=rows(v?.items);
    return {planId:plan.feeding_plan_id,planType:plan.plan_type,planRowVersion:plan.row_version,planStatus:plan.status,
      name:plan.name||'',effectiveFrom:plan.effective_from,effectiveUntil:plan.effective_until||null,
      meals:Object.entries(MEALS).map(([code,name])=>({name,code,time:items.find(i=>i.round_code===code)?.local_time?.slice(0,5)||'',items:items.filter(i=>i.round_code===code).map(i=>({
        id:i.feeding_plan_item_id,rowVersion:i.row_version,product:i.product_brand||i.product_name||i.product_variant||'Voeding',
        productType:i.product_variant||'other',amount:`${new Intl.NumberFormat('nl-NL',{maximumFractionDigits:4}).format(i.planned_quantity)} ${UNITS[i.unit_code]||i.unit_code}`,
        quantity:Number(i.planned_quantity),unit:i.unit_code,note:i.instruction||'',productName:i.product_name||'',productVariant:i.product_variant||''
      }))}))};
  });
  const active=plans.filter(p=>p.planStatus==='active'&&p.effectiveFrom<=day&&(!p.effectiveUntil||p.effectiveUntil>=day))
    .sort((a,b)=>(a.planType==='temporary'?0:1)-(b.planType==='temporary'?0:1)||b.effectiveFrom.localeCompare(a.effectiveFrom)||a.planId.localeCompare(b.planId))[0];
  return {...(active||{planId:null,planType:'standard',planRowVersion:null,effectiveFrom:day,effectiveUntil:null,meals:Object.entries(MEALS).map(([code,name])=>({code,name,time:'',items:[]}))}),
    status:active?(active.planType==='temporary'?'Tijdelijk schema actief':'Basisvoeding actief'):'Geen actief schema',
    note:active?.name||'',until:active?.effectiveUntil||null,plans};
}

export function normalizeLoad(raw,{day,organizationId}) {
  const profile=first(raw.profile);need(profile?.profile_status==='active','Je account is niet beschikbaar. Meld je opnieuw aan.');
  const timeZone=accountZone(profile,raw.day);
  const org=raw.workspace?.organization||null;const permissionCodes=raw.workspace?.capabilities||{};
  const hs=rows(raw.horses);const horseCapabilities=Object.fromEntries(hs.map(h=>[h.horse_id,{view:true,edit:h.can_edit===true,manage:h.can_manage===true,planning:h.can_edit===true||h.can_manage_planning===true,feeding:h.can_edit===true||h.can_manage_feeding===true,primary:h.is_primary_authority===true}]));
  const stableHorseIds=rows(raw.workspace?.horses).map(h=>h.horse_id);
  const name=profile.display_name||[profile.first_name,profile.last_name].filter(Boolean).join(' ')||'Jouw account';
  const codes=rows(raw.stables).find(s=>s.organization_id===organizationId)?.role_codes||[];
  const canManage=permissionCodes['organization.edit']===true;
  const actor={id:profile.profile_id,name,initials:initials(name),roleKind:canManage?'manager':codes.includes('groom')?'groom':codes.includes('trainer')?'trainer':codes.includes('rider')?'rider':hs.some(h=>h.is_primary_authority)?'owner':'member',
    roleLabel:codes.map(v=>ROLES[v]||'Teamlid').join(' · ')||'Persoonlijk account',personalHorseIds:hs.filter(h=>h.is_primary_authority).map(h=>h.horse_id),accessibleHorseIds:hs.map(h=>h.horse_id),assignedHorseIds:unique(rows(raw.day?.items).map(i=>i.horse_id))};
  const activities=Object.values(raw.schedules||{}).flatMap(items=>rows(items)).map(r=>normalizedActivity(r,actor,horseCapabilities,false,timeZone));
  const todayItems=rows(raw.day?.items).map(row=>row.source_type==='stable_task'?normalizedTask(row,null,actor):normalizedActivity(row,actor,horseCapabilities,true,timeZone));
  const tasks=rows(raw.round1?.activities).filter(row=>row.activity_kind==='stable_task').map(row=>normalizedTask(row,org,actor));
  const allTasks=[...new Map([...todayItems.filter(i=>i.sourceType==='stable_task'),...tasks].map(t=>[t.id,t])).values()];
  const now=Date.now(),activeRelation=r=>r.status==='active'&&(!r.valid_from||Date.parse(r.valid_from)<=now)&&(!r.valid_until||Date.parse(r.valid_until)>now);
  const horses=hs.map(h=>{
    const detail=raw.details?.[h.horse_id]||{},residency=rows(detail.residencies).find(activeRelation);
    const team=rows(detail.relationships).filter(activeRelation).map(r=>({id:r.profile_id,name:r.profile_name,role:ROLES[r.relationship_type]||'Betrokkene'}));
    if(h.is_primary_authority&&!team.some(m=>m.id===actor.id))team.unshift({id:actor.id,name:actor.name,role:'Hoofdbeheerder'});
    const birth=h.birth_date?Number(day.slice(0,4))-Number(h.birth_date.slice(0,4))-(day.slice(5)<h.birth_date.slice(5)?1:0):null;
    return {id:h.horse_id,name:h.display_name,officialName:h.official_name||'',breed:h.breed||'',age:birth,discipline:[h.discipline,h.level].filter(Boolean).join(' · '),
      image:'assets/horse-placeholder.svg',imageIsPlaceholder:true,stable:residency?.organization_name||'',
      organizationId:residency?.organization_id||null,sex:h.sex||'',color:h.color||'',height:'',box:'',team,
      owner:rows(detail.person_ownerships).filter(activeRelation).map(r=>r.profile_name).filter(Boolean).join(', '),description:h.notes||'',rowVersion:h.row_version,lifecycleStatus:h.lifecycle_status,personalAccess:h.is_primary_authority,capabilities:horseCapabilities[h.horse_id]};
  });
  const feeding=Object.fromEntries(horses.map(h=>[h.id,normalizeFeeding(raw.feeding?.[h.id],raw.day.on_date)]));
  const team=rows(raw.workspace?.memberships).filter(m=>m.status==='active').map(m=>({id:m.profile_id,membershipId:m.id,rowVersion:m.row_version,name:m.profile_name,initials:initials(m.profile_name),role:m.role_name||ROLES[m.role_code]||'Teamlid',roleCode:m.role_code}));
  return {horses,activities,tasks:allTasks,feeding,team,stableName:org?.name||'Jouw paarden',stableLocation:[org?.location_name,org?.locality].filter(Boolean).join(' · '),selectedDay:day,
    backend:{connected:true,actor,organizationId:organizationId||null,organizations:rows(raw.stables).map(s=>({id:s.organization_id,name:s.name,roleCodes:s.role_codes,status:s.lifecycle_status})),stableHorseIds,horseCapabilities,
      capabilities:{canManage,canCreateTask:raw.round1?.can_manage_tasks===true,canPlan:hs.some(h=>horseCapabilities[h.horse_id].planning),canEditFeeding:hs.some(h=>horseCapabilities[h.horse_id].feeding),canViewTeam:permissionCodes['organization.memberships.view']===true,canShareMoment:false},
      profile,organization:org,roles:rows(raw.workspace?.roles),invitations:rows(raw.workspace?.invitations),permissionCodes,calendar:{...raw.day.calendar,time_zone:timeZone},todayDate:raw.day.on_date,todayItems,todayTasks:todayItems.filter(i=>i.sourceType==='stable_task'),todayActivities:todayItems.filter(i=>i.sourceType==='horse_activity'),taskCandidates:rows(raw.round1?.task_candidates).map(c=>({id:c.profile_id,name:c.display_name})),places:rows(raw.round1?.places),profileVersion:profile.row_version,theme:profile.theme_mode}};
}

/** Hooks: await login()/restore(); await load(). Replace core state atomically.
 * After every successful mutation await load() before showing saved/completed.
 * Keep form + requestId on uncertain errors; never automatically repeat writes.
 */
export function createBackendClient({baseUrl='/api',fetchImpl=globalThis.fetch,storage=globalThis.sessionStorage,timeoutMs=20000}={}) {
  const relativeBase=/^\/[a-z0-9/_-]+$/i.test(baseUrl)&&!baseUrl.startsWith('//');
  let remoteBase=false;try{const u=new URL(baseUrl);remoteBase=u.protocol==='https:'&&!u.username&&!u.password&&!u.search&&!u.hash&&u.pathname==='/api';}catch{}
  need(relativeBase||remoteBase,'Ongeldige verbinding.');
  let session=null,epoch=0,loadEpoch=0,cached=null,rawCache=null,mutationBusy=false,refreshPromise=null;
  const storageKey='avaryn-v8-real-auth-v1';
  const current=e=>{if(e!==epoch)throw new BackendError('Je accountcontext is veranderd.',{code:'STALE_CONTEXT',accessLost:true});};
  let persistence=Promise.resolve();
  const persist=()=>{
    const value=session?JSON.stringify(session):null;
    const operation=persistence.catch(()=>{}).then(()=>value===null?storage?.removeItem(storageKey):storage?.setItem(storageKey,value));
    persistence=operation;
    return operation.catch(()=>{throw new BackendError('Je sessie kon niet veilig worden bewaard. Probeer opnieuw.',{code:'SESSION_STORAGE_UNAVAILABLE'});});
  };
  const clear=()=>{session=null;cached=null;rawCache=null;epoch++;loadEpoch++;refreshPromise=null;return persist();};
  async function request(path,body,{token=session?.access_token,write=false,method='POST'}={}) {
    const controller=new AbortController();let timer;const headers={'Content-Type':'application/json','X-Supabase-Api-Version':'2024-01-01'};
    if(token)headers.Authorization='Bearer '+token;
    try {
      const operation=(async()=>{
        const response=await fetchImpl(baseUrl+path,{method,headers,body:method==='GET'?undefined:JSON.stringify(body??{}),signal:controller.signal,cache:'no-store',credentials:'same-origin'});
        if(response.ok&&response.status===204)return {};
        let payload;try{payload=await response.json();}catch{throw new BackendError('De verbinding gaf geen bruikbaar antwoord.',{code:'INVALID_RESPONSE',uncertain:write});}
        if(!response.ok)throw friendly(response.status,payload,write);return payload;
      })();
      return await Promise.race([operation,new Promise((_,reject)=>{timer=setTimeout(()=>{controller.abort();reject(new BackendError(write?'Opslaan is nog niet bevestigd. Laad de gegevens voordat je opnieuw probeert.':'Het laden duurt te lang. Probeer het opnieuw.',{code:'TIMEOUT',uncertain:write}));},timeoutMs);})]);
    }catch(error){if(error instanceof BackendError)throw error;throw new BackendError(write?'Opslaan is nog niet bevestigd. Laad de gegevens voordat je opnieuw probeert.':'AVARYN is tijdelijk niet bereikbaar. Probeer het opnieuw.',{code:'NETWORK',uncertain:write});}
    finally{clearTimeout(timer);}
  }
  async function ensure(){
    if(!session?.access_token)throw new BackendError('Meld je aan om verder te gaan.',{code:'AUTH_REQUIRED',status:401,accessLost:true});
    if(session.expires_at*1000>Date.now()+60000)return;
    if(refreshPromise)return refreshPromise;
    const e=epoch,actor=session.user_id,token=session.refresh_token;
    const operation=(async()=>{const next=await request('/auth/v1/token?grant_type=refresh_token',{refresh_token:token},{token:null});current(e);need(next.user?.id===actor,'Je accountcontext is veranderd.');await setSession(next);current(e);})();
    refreshPromise=operation;
    try{await operation;}finally{if(refreshPromise===operation)refreshPromise=null;}
  }
  async function setSession(value){need(value?.access_token&&value?.refresh_token&&value.user?.id,'Aanmelden is niet bevestigd.');const e=epoch,next={access_token:value.access_token,refresh_token:value.refresh_token,user_id:value.user.id,expires_at:value.expires_at||Math.floor(Date.now()/1000)+(value.expires_in||3600)};session=next;try{await persist();}catch(error){if(epoch===e&&session===next){session=null;cached=null;rawCache=null;epoch++;loadEpoch++;refreshPromise=null;}throw error;}}
  async function rpc(name,params={},write=false){const e=epoch;await ensure();current(e);const result=await request('/rest/v1/rpc/'+name,params,{write});current(e);return result;}
  async function login(email,password){const cleared=clear(),e=epoch;await cleared;current(e);const next=await request('/auth/v1/token?grant_type=password',{email,password},{token:null});current(e);await setSession(next);current(e);return true;}
  async function restoreSession(){const before=epoch;await persistence;const value=await storage?.getItem(storageKey);current(before);const cleared=clear(),e=epoch;await cleared;current(e);if(!value)return false;try{const parsed=JSON.parse(value);need(parsed.access_token&&parsed.refresh_token&&UUID.test(parsed.user_id));session=parsed;await ensure();current(e);const user=await request('/auth/v1/user',null,{method:'GET'});current(e);need(user.id===session.user_id);await persist();current(e);return true;}catch(error){if(e===epoch)await clear();throw error;}}
  async function logout(){const token=session?.access_token,cleared=clear();try{await cleared;}finally{if(token)await request('/auth/v1/logout?scope=local',{}, {token,write:true});}}
  async function signUp(email,password){need(password.length>=12,'Gebruik minstens 12 tekens voor je wachtwoord.');await request('/auth/v1/signup',{email,password},{token:null,write:true});return true;}
  async function recover(email){await request('/auth/v1/recover',{email},{token:null,write:true});return true;}
  async function resend(email){await request('/auth/v1/resend',{type:'signup',email},{token:null,write:true});return true;}
  async function verifyEmail({email,token,tokenHash,type='email'}){
    need(['email','signup','recovery'].includes(type));const cleared=clear(),e=epoch;await cleared;current(e);
    const next=await request('/auth/v1/verify',tokenHash?{token_hash:tokenHash,type}:{email,token,type},{token:null,write:true});current(e);
    need(next.user?.email_confirmed_at,'Je e-mailadres is nog niet bevestigd.');await setSession(next);current(e);return true;
  }
  async function updatePassword(password){need(password.length>=12,'Gebruik minstens 12 tekens voor je wachtwoord.');const e=epoch;await ensure();current(e);await request('/auth/v1/user',{password},{method:'PUT',write:true});current(e);return true;}
  async function load({organizationId,day}={}){
    const e=epoch,l=++loadEpoch;cached=null;rawCache=null;
    const [profile,personal,horses,stables]=await Promise.all([rpc('get_current_account_profile'),rpc('get_c010_personal_day',{p_on_date:null}),rpc('list_c010_horses'),rpc('list_c010_stables')]);current(e);
    if(l!==loadEpoch)throw new BackendError('Je weergave is intussen veranderd.',{code:'STALE_CONTEXT'});
    need(first(profile)?.profile_status==='active','Je account is niet beschikbaar. Meld je opnieuw aan.');
    const timeZone=accountZone(first(profile),personal);
    const selectedDay=day||personal.on_date;need(validDay(selectedDay));const activeStables=rows(stables).filter(s=>s.lifecycle_status==='active');
    const chosen=organizationId===null?null:organizationId||activeStables[0]?.organization_id||null;
    if(chosen&&!activeStables.some(s=>s.organization_id===chosen))throw new BackendError('Deze stal is niet meer beschikbaar voor jou.',{code:'ORGANIZATION_UNAVAILABLE',accessLost:true});
    const from=civilInstant(plusDays(selectedDay,-32),'00:00',timeZone),through=civilInstant(plusDays(selectedDay,64),'00:00',timeZone);
    const raw={profile,day:personal,horses:rows(horses).filter(h=>h.lifecycle_status==='active'),stables:activeStables,workspace:null,round1:null,schedules:{},feeding:{},details:{}};
    if(chosen)[raw.workspace,raw.round1]=await Promise.all([rpc('get_c010_stable_workspace',{p_organization_id:chosen,p_from:from,p_through:through,p_on_date:selectedDay,p_planning_scope:'all'}),rpc('get_c010_stable_round1_workspace',{p_organization_id:chosen,p_on_date:selectedDay,p_scope:'all'})]);
    // Bounded concurrency avoids a burst against the existing local gateway.
    for(let start=0;start<raw.horses.length;start+=3)await Promise.all(raw.horses.slice(start,start+3).map(async horse=>{
      const params={p_horse_id:horse.horse_id};const [schedule,feed,detail]=await Promise.all([rpc('list_c010_horse_schedule',{...params,p_from:from,p_through:through,p_scope:'all'}),rpc('get_canonical_horse_feeding',params),rpc('get_canonical_horse_workspace',params)]);
      raw.schedules[horse.horse_id]=schedule;raw.feeding[horse.horse_id]=feed;raw.details[horse.horse_id]=detail;
    }));
    current(e);if(l!==loadEpoch)throw new BackendError('Je weergave is intussen veranderd.',{code:'STALE_CONTEXT'});
    const result=normalizeLoad(raw,{day:selectedDay,organizationId:chosen});cached=result;rawCache=raw;return result;
  }
  const cache=()=>{need(cached?.backend?.connected,'Laad eerst de actuele gegevens.');return cached;};
  async function mutate(name,params){need(!mutationBusy,'Wacht tot de huidige wijziging is bevestigd.');mutationBusy=true;const e=epoch,l=loadEpoch;try{const result=await rpc(name,params,true);current(e);if(l!==loadEpoch)throw new BackendError('Laad de actuele gegevens om de wijziging te controleren.',{code:'STALE_CONTEXT',uncertain:true});const target=result?.task_id||result?.schedule_item_id||result?.feeding_plan_id;if(!UUID.test(target||'')||!Number.isSafeInteger(Number(result.row_version??result.plan_row_version)))throw new BackendError('Opslaan is nog niet bevestigd. Laad de actuele gegevens.',{code:'INVALID_RESPONSE',uncertain:true});return result;}finally{mutationBusy=false;}}
  /** completeTask(taskId, rowVersion, requestId): only own completable task. */
  async function completeTask(taskId,rowVersion,requestId){const task=cache().tasks.find(t=>t.id===taskId)||cache().backend.todayItems.find(t=>t.id===taskId&&t.sourceType==='stable_task');need(task?.canComplete,'Deze taak kun je niet afronden.');return mutate('transition_c010_stable_task',{p_organization_id:id(task.organizationId),p_task_id:id(taskId),p_expected_row_version:version(rowVersion),p_action:'complete',p_request_id:id(requestId)});}
  /** completeActivity(id,rowVersion,requestId): own participation + manage right. */
  async function completeActivity(activityId,rowVersion,requestId){const a=cache().activities.find(a=>a.id===activityId)||cache().backend.todayItems.find(a=>a.id===activityId);need(a?.canComplete,'Deze activiteit kun je niet afronden.');return mutate('complete_c010_personal_activity',{p_schedule_item_id:id(activityId),p_expected_row_version:version(rowVersion),p_request_id:id(requestId)});}
  /** saveTask({id?,rowVersion?,title,note,category?,date,time?,assigneeProfileId,horseId?,location,stablePlaceId?}, requestId). */
  async function saveTask(form,requestId){const s=cache();need(s.backend.capabilities.canCreateTask,'Je kunt hier geen taken beheren.');const old=form.id?s.tasks.find(t=>t.id===form.id):null;need(!form.id||old);need(!form.date||validDay(form.date));need(!form.time||Boolean(form.date),'Kies een datum als je een tijd toevoegt.');need(!form.time||/^([01]\d|2[0-3]):[0-5]\d$/.test(form.time),'Kies een geldige tijd.');id(form.assigneeProfileId);if(form.horseId)need(s.backend.stableHorseIds.includes(form.horseId));
    return mutate('upsert_c010_stable_task',{p_organization_id:id(s.backend.organizationId),p_task_id:old?.id||null,p_expected_row_version:old?version(form.rowVersion):null,p_title:form.title,p_note:form.note||'',p_category:form.category||'other',p_due_date:form.date||null,p_due_time:form.time?form.time.slice(0,5)+':00':null,p_assignee_profile_id:form.assigneeProfileId,p_location_text:form.location||'',p_stable_place_id:form.stablePlaceId||null,p_horse_id:form.horseId||null,p_request_id:id(requestId)});
  }
  /** saveActivity({id?,rowVersion?,horseId,type|itemKind,title,note,date,time,end,endDate?,participantProfileIds?}, requestId). Existing participants/timestamps preserved unless explicitly changed. No invented location field in this RPC. */
  async function saveActivity(form,requestId){const s=cache(),old=form.id?s.activities.find(a=>a.id===form.id):null;need(!form.id||old);need(s.backend.horseCapabilities[form.horseId]?.planning,'Je kunt voor dit paard geen activiteiten beheren.');
    const timeZone=verifiedZone(s.backend.calendar.time_zone);
    const instant=(current,date,time)=>{const shown=current?localParts(current,timeZone):null;return shown&&shown.date===date&&shown.time===time.slice(0,5)?current:civilInstant(date,time,timeZone);};
    const start=instant(old?.scheduledStartAt,form.date,form.time),end=form.end?instant(old?.scheduledEndAt,form.endDate||form.date,form.end):null;need(!end||Date.parse(end)>Date.parse(start),'De eindtijd moet na de begintijd liggen.');
    const sourceTimezone=old&&start===old.scheduledStartAt&&end===old.scheduledEndAt?old.sourceTimezone:timeZone;
    const kind=form.itemKind||Object.keys(KINDS).find(k=>KINDS[k]===form.type)||old?.itemKind||'training';
    return mutate('upsert_c010_horse_schedule_item',{p_horse_id:id(form.horseId),p_schedule_item_id:old?.id||null,p_expected_row_version:old?version(form.rowVersion):null,p_item_kind:kind,p_title:form.title||KINDS[kind],p_instruction:form.note||'',p_priority:old?.priority||'normal',p_scheduled_start_at:start,p_scheduled_end_at:end,p_source_timezone:sourceTimezone,p_state:old?.status||'planned',p_state_reason:old?.stateReason||null,p_participant_profile_ids:form.participantProfileIds||old?.participantProfileIds||[s.backend.actor.id],p_request_id:id(requestId)});
  }
  /** saveFeedingRound({horseId,day,mealName,items:[{product,amount,unit,note,productType?}]},requestId): edit the displayed plan's one daypart atomically, preserving other rounds. No guessed product type for new products. */
  async function saveFeedingRound(form,requestId){
    const s=cache();need(s.backend.horseCapabilities[form.horseId]?.feeding,'Je kunt dit voerplan niet wijzigen.');
    const feed=s.feeding[form.horseId];need(feed&&validDay(form.day)&&form.day===s.backend.todayDate,'Laad eerst het voerplan van vandaag.');
    const explicit=Object.hasOwn(form,'planId');
    const selected=explicit?(form.planId?feed.plans.find(p=>p.planId===form.planId):null):feed;
    need(!form.planId||selected,'Dit voerplan is niet meer beschikbaar. Laad de actuele gegevens.');
    need(!selected?.planStatus||selected.planStatus!=='retired','Dit voerplan is beëindigd.');
    const planType=explicit?(form.planType||selected?.planType):feed.planType;
    need(['standard','temporary'].includes(planType));need(!selected||selected.planType===planType);
    const from=explicit?form.effectiveFrom:(feed.effectiveFrom||form.day),until=explicit?(form.effectiveUntil||null):feed.effectiveUntil;
    need(validDay(from)&&(!until||validDay(until))&&(!until||until>=from),'De einddatum mag niet vóór de begindatum liggen.');
    need(planType!=='temporary'||until,'Kies de laatste dag van het tijdelijke schema.');
    if(planType==='temporary')need(feed.plans.some(p=>p.planType==='standard'&&p.planStatus==='active'&&p.effectiveFrom<=from&&(!p.effectiveUntil||p.effectiveUntil>=until)),'Leg eerst basisvoeding vast die de hele tijdelijke periode dekt.');
    const code=Object.keys(MEALS).find(k=>MEALS[k]===form.mealName)||form.mealName;need(MEALS[code]);
    const existing=selected?.meals.find(m=>m.code===code)?.items||[];
    need(form.items?.length>0&&form.items.length<=24,'Voeg minstens één product toe; leegmaken is hier nog niet gekoppeld.');
    const products=form.items.map(entry=>{
      const prior=entry.id?existing.find(i=>i.id===entry.id):null;need(!entry.id||prior,'Dit product is intussen gewijzigd. Laad het actuele voerplan.');
      const type=entry.productType||prior?.productType;need(['pellet','muesli','mash','roughage','supplement','medication','oil','other'].includes(type),'Kies bij ieder nieuw product een productsoort.');
      const quantity=String(entry.quantity??entry.amount).trim().replace(',','.');need(/^\d+(\.\d{1,4})?$/.test(quantity)&&Number(quantity)>0,'Vul een hoeveelheid groter dan nul in, met maximaal vier decimalen.');need(Object.hasOwn(UNITS,entry.unit));
      return {product_type:type,description:entry.product,note:entry.note||'',quantity,unit_code:entry.unit,...(prior?{item_id:prior.id,expected_row_version:version(entry.rowVersion??prior.rowVersion)}:{})};
    });
    const name=s.backend.horseCapabilities[form.horseId].edit?'save_canonical_horse_feeding_round':'save_c010_horse_feeding_round';
    return mutate(name,{p_horse_id:id(form.horseId),p_plan_type:planType,p_feeding_plan_id:selected?.planId||null,
      p_expected_plan_row_version:selected?.planId?version(explicit?form.planRowVersion:selected.planRowVersion):null,
      p_round_code:code,p_effective_from:from,p_effective_until:until,p_products:products,p_request_id:id(requestId)});
  }
  async function retireFeedingPlan(form,requestId){
    const s=cache();need(s.backend.horseCapabilities[form.horseId]?.feeding,'Je kunt dit voerplan niet wijzigen.');
    const plan=s.feeding[form.horseId]?.plans.find(p=>p.planId===form.planId);
    need(plan?.planType==='temporary'&&plan.planStatus!=='retired','Dit tijdelijke schema is niet meer beschikbaar.');
    const name=s.backend.horseCapabilities[form.horseId].edit?'retire_canonical_horse_feeding_plan':'retire_c010_horse_feeding_plan';
    return mutate(name,{p_horse_id:id(form.horseId),p_feeding_plan_id:id(form.planId),p_expected_row_version:version(form.planRowVersion),p_request_id:id(requestId)});
  }
  /** Internal adapter DI only: gateway owns the explicit RPC allowlist. */
  async function requestRpc(name,params={}, {write=false}={}){
    need(/^[a-z][a-z0-9_]*$/.test(name));cache();const e=epoch,l=loadEpoch;
    if(write){need(!mutationBusy,'Wacht tot de huidige wijziging is bevestigd.');mutationBusy=true;}
    try{const result=await rpc(name,params,write);current(e);if(l!==loadEpoch)throw new BackendError('Je weergave is intussen veranderd. Laad de actuele gegevens.',{code:'STALE_CONTEXT',uncertain:write});return result;}
    finally{if(write)mutationBusy=false;}
  }

  async function edgeRequest(name,body,{write=true}={}){
    need(['media-assets','delete-account'].includes(name));const e=epoch,l=loadEpoch;await ensure();current(e);
    const result=await request('/functions/v1/'+name,body,{write});current(e);
    if(l!==loadEpoch)throw new BackendError('Je weergave is veranderd. Controleer de actuele gegevens.',{code:'STALE_CONTEXT',uncertain:write});return result;
  }
  const mediaRequest=(body,options)=>{cache();need(['canonical_create','canonical_finalize','canonical_download'].includes(body?.action));return edgeRequest('media-assets',body,options);};
  async function mediaBytes(signedUrl,blob){
    cache();const path=horseMediaPath(signedUrl,blob?'upload':'download');need(path,'De fotoverbinding kon niet worden gecontroleerd.');
    const e=epoch,l=loadEpoch;await ensure();current(e);
    const controller=new AbortController();let timer;
    const headers={Authorization:'Bearer '+session.access_token};if(blob)headers['Content-Type']=blob.type;
    try{
      const job=(async()=>{
        const response=await fetchImpl(baseUrl+path,{method:blob?'PUT':'GET',headers,body:blob,signal:controller.signal,cache:'no-store',credentials:'same-origin',redirect:'error'});
        if(!response.ok){let value;try{value=await response.json();}catch{}throw friendly(response.status,value,Boolean(blob));}
        const result=blob?await response.json():await response.blob();current(e);
        if(l!==loadEpoch)throw new BackendError('Je account of paardenlijst is veranderd.',{code:'STALE_CONTEXT',uncertain:Boolean(blob)});
        if(!blob)need(['image/jpeg','image/png','image/webp'].includes(result.type)&&result.size>0&&result.size<=10*1024*1024,'De foto kon niet worden gecontroleerd.');return result;
      })();
      return await Promise.race([job,new Promise((_,reject)=>{timer=setTimeout(()=>{controller.abort();reject(new BackendError('De fotoverbinding duurt te lang. Je wijziging is niet bevestigd.',{code:'TIMEOUT',uncertain:Boolean(blob)}));},timeoutMs);})]);
    }catch(e){if(e instanceof BackendError)throw e;throw new BackendError('De fotoverbinding is onderbroken. Probeer opnieuw.',{code:'NETWORK',uncertain:Boolean(blob)});}finally{clearTimeout(timer);}
  }
  const uploadHorseMedia=(upload,blob)=>{const path=horseMediaPath(upload?.signed_upload_url,'upload'),max=path?.split('?')[0].endsWith('/thumbnail')?1024*1024:10*1024*1024;need(path&&blob instanceof Blob&&['image/jpeg','image/png','image/webp'].includes(blob.type)&&blob.type===upload.expected_mime_type&&blob.size>0&&blob.size<=upload.max_byte_size&&blob.size<=max,'Controleer het fotoformaat en de bestandsgrootte.');return mediaBytes(upload.signed_upload_url,blob);};
  async function downloadHorseMedia({media_asset_id,variant='thumbnail'}){id(media_asset_id);need(['thumbnail','original'].includes(variant));const value=await mediaRequest({action:'canonical_download',media_asset_id,variant},{write:false});return mediaBytes(value.signed_download_url);}

  return {login,signUp,recover,resend,verifyEmail,updatePassword,restore:restoreSession,logout,clearLocalSession:clear,invalidateData:()=>{cached=null;rawCache=null;loadEpoch++;},load,completeTask,completeActivity,saveTask,saveActivity,saveFeedingRound,retireFeedingPlan,requestRpc,edgeRequest,mediaRequest,uploadHorseMedia,downloadHorseMedia};
}
