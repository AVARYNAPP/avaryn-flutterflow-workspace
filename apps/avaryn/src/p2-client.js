/** P2 adapter. Uses only the existing authenticated BackendClient requestRpc.
 * No tokens, persona defaults, fixture rows or direct table writes. Caller owns
 * actor/context generation and authoritative reread after every mutation.
 */
import {BackendError} from './backend-client.js';
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const need=(ok,msg='Controleer de ingevulde gegevens.')=>{if(!ok)throw new BackendError(msg,{code:'INPUT_INVALID'});};
const id=v=>{need(UUID.test(v||''));return v;};
const messages={C010_FACILITY_CAPACITY_CONFLICT:'Er is op dit tijdstip onvoldoende ruimte. Kies een ander tijdstip of minder deelnemers.',C010_HORSE_LOCATION_CONFLICT:'Een gekozen paard staat op dit tijdstip al ergens anders ingepland.',C010_FACILITY_HAS_HISTORY:'Deze plek heeft nog toewijzingen of bewaarde planning en kan niet worden weggehaald.',C010_PLACE_OCCUPIED:'Deze stalplaats is al in gebruik. Kies een andere plek.',C010_BOOKING_INPUT_INVALID:'Controleer de datum, tijden, paarden en deelnemers. Vul bij een hele rijbak een reden in.',C010_BOOKING_TERMINAL:'Deze reservering is al afgehandeld. Laad de actuele planning.',C010_HORSE_CONTEXT_REQUIRED:'Dit paard is niet beschikbaar voor deze handeling in deze stal.',C010_FACILITY_UNAVAILABLE:'Deze plek is niet beschikbaar. Laad de actuele faciliteiten.'};
const empty=()=>({schema:1,arenaSetupVersion:1,tackRoom:false,resources:[],placements:[],placementVersions:{},bookings:[],arenaBookings:[],configuration:{rowVersion:null,counts:{stall:0,pasture:0,paddock:0,arena:0,walker:0,wash:0,locker:0},walkerCapacity:1,tackRoom:false}});
export const P2_RPC_NAMES=Object.freeze(['get_my_c010_function_profile','save_my_c010_function_profile','get_c010_facility_workspace','configure_c010_facilities','update_c010_facility_unit','set_c010_horse_place','save_c010_facility_booking','transition_c010_facility_booking']);
export function createP2Client({request}){
 need(typeof request==='function');
 const actor=s=>{need(s?.backend?.connected&&s.backend.actor?.id,'Laad eerst je account.');return id(s.backend.actor.id);};
 const org=s=>{actor(s);need(s.backend.p2?.connected&&s.backend.p2.organizationId===s.backend.organizationId,'Laad eerst de actuele stal.');return id(s.backend.organizationId);};
 async function call(name,params,write=false){try{return await request(name,params,{write});}catch(error){if(messages[error.code])error.userMessage=error.message=messages[error.code];throw error;}}
 const invalid=(write=false)=>new BackendError(write?'Opslaan is nog niet bevestigd. Laad de actuele gegevens.':'De verbinding gaf geen bruikbare gegevens. Probeer opnieuw.',{code:'INVALID_RESPONSE',uncertain:write});
 async function write(name,params){const r=await call(name,params,true);const field=name==='configure_c010_facilities'?'organization_id':name==='update_c010_facility_unit'?'resource_id':name==='set_c010_horse_place'?'horse_id':name==='save_my_c010_function_profile'?'profile_id':'booking_id';
 const expected=params['p_'+field];if(!r||!Number.isSafeInteger(Number(r.row_version))||Number(r.row_version)<1||!UUID.test(r[field]||'')||(expected&&r[field]!==expected))throw invalid(true);return r;}

 /** Returns a new core snapshot enriched with authoritative P2, never mutates it. */
 async function load(snapshot,{day}={}){
  const profileId=actor(snapshot),organizationId=snapshot.backend.organizationId||null;
  const [preferences,workspace]=await Promise.all([call('get_my_c010_function_profile',{}),organizationId?call('get_c010_facility_workspace',{p_organization_id:organizationId,p_on_date:day||snapshot.facilityDate||snapshot.backend.todayDate}):null]);
  if(!preferences||!Array.isArray(preferences.functions)||preferences.functions.some(f=>!['owner','rider','manager','trainer','groom','farrier','vet','physio','nutrition'].includes(f))||!(preferences.row_version===null||Number.isSafeInteger(preferences.row_version)&&preferences.row_version>0))throw invalid();
  if(organizationId&&(!workspace||!['resources','placements','bookings','arenaBookings'].every(k=>Array.isArray(workspace[k]))||!workspace.configuration||!workspace.configuration.counts||!workspace.capabilities||!workspace.calendar))throw invalid();
  if(preferences.profile_id!==profileId||workspace&&(workspace.profile_id!==profileId||workspace.organization_id!==organizationId))throw new BackendError('Je accountcontext is veranderd.',{code:'STALE_CONTEXT',accessLost:true});
  const f=workspace?{schema:1,arenaSetupVersion:1,tackRoom:workspace.configuration.tack_room,
   configuration:{rowVersion:workspace.configuration.row_version,counts:workspace.configuration.counts,walkerCapacity:workspace.configuration.walker_capacity,tackRoom:workspace.configuration.tack_room},
   resources:workspace.resources.map(r=>({...r,description:r.note||''})),placements:workspace.placements,placementVersions:workspace.placementVersions||{},
   bookings:workspace.bookings,arenaBookings:workspace.arenaBookings,calendar:workspace.calendar}:empty();
  const byId=new Map(f.resources.map(r=>[r.id,r]));const places=new Map(f.placements.map(p=>[p.horseId,byId.get(p.resourceId)?.name||'']));
  return {...snapshot,facilities:f,facilityDate:workspace?.on_date||day||snapshot.backend.todayDate,
   horses:snapshot.horses.map(h=>({...h,box:places.get(h.id)||(h.organizationId===organizationId?'':h.box||'')})),
   functionProfiles:{[profileId]:preferences.functions},functionProfileRowVersion:preferences.row_version,
   backend:{...snapshot.backend,p2:{connected:true,organizationId,day:workspace?.on_date||snapshot.backend.todayDate,canManage:workspace?.capabilities.manage===true,canBook:workspace?.capabilities.book===true}}};
 }
 const manage=s=>need(s.backend.p2?.canManage===true,'Je kunt de faciliteiten van deze stal niet beheren.');
 function configure(snapshot,form,requestId){const organization=org(snapshot);manage(snapshot);return write('configure_c010_facilities',{p_organization_id:organization,p_expected_row_version:snapshot.facilities.configuration.rowVersion,p_counts:form.counts,p_walker_capacity:Number(form.walkerCapacity),p_has_tack_room:form.tackRoom===true,p_request_id:id(requestId)});}
 function saveResource(snapshot,form,requestId){const organization=org(snapshot);manage(snapshot);need(snapshot.facilities.resources.some(r=>r.id===form.id));return write('update_c010_facility_unit',{p_organization_id:organization,p_resource_id:id(form.id),p_expected_row_version:form.rowVersion,p_name:form.name,p_type:form.type||'',p_status:form.status,p_capacity:Number(form.capacity),p_note:form.note??form.description??'',p_request_id:id(requestId)});}
 function setPlacement(snapshot,form,requestId){const organization=org(snapshot);manage(snapshot);need(snapshot.horses.some(h=>h.id===form.horseId));const expected=Object.hasOwn(form,'rowVersion')?form.rowVersion:snapshot.facilities.placementVersions?.[form.horseId]??null;return write('set_c010_horse_place',{p_organization_id:organization,p_horse_id:id(form.horseId),p_stable_place_id:form.resourceId?id(form.resourceId):null,p_expected_row_version:expected,p_note:form.note||'',p_request_id:id(requestId)});}
 function saveBooking(snapshot,form,requestId){const organization=org(snapshot);need(snapshot.backend.p2.canBook,'Je kunt hier geen reservering maken.');const resource=snapshot.facilities.resources.find(r=>r.id===form.resourceId);need(resource);const horseIds=Array.isArray(form.horseIds)?form.horseIds:form.horseId?[form.horseId]:[];need(horseIds.every(h=>snapshot.horses.some(x=>x.id===h)));return write('save_c010_facility_booking',{p_organization_id:organization,p_booking_id:form.id?id(form.id):null,p_expected_row_version:form.id?form.rowVersion:null,p_resource_id:id(form.resourceId),p_date:form.date,p_start:form.start,p_end:form.end,p_horse_ids:horseIds,p_participants:resource.kind==='arena'?Number(form.participants):horseIds.length,p_activity:form.activity||'',p_note:form.note||'',p_exclusive:resource.kind==='arena'&&form.exclusive===true,p_request_id:id(requestId)});}
 function transitionBooking(snapshot,form,requestId){const organization=org(snapshot);return write('transition_c010_facility_booking',{p_organization_id:organization,p_booking_id:id(form.id),p_expected_row_version:form.rowVersion,p_action:form.action,p_note:form.note||'',p_request_id:id(requestId)});}
 async function saveFunctions(snapshot,functions,requestId){const profileId=actor(snapshot);const result=await write('save_my_c010_function_profile',{p_functions:functions,p_expected_row_version:snapshot.functionProfileRowVersion??null,p_request_id:id(requestId)});if(result.profile_id!==profileId)throw invalid(true);return result;}
 return {load,configure,saveResource,setPlacement,saveBooking,transitionBooking,saveFunctions};
}
