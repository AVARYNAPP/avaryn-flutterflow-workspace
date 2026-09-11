import {createP2Client} from './p2-client.js';
import {FACILITY_KINDS,validDay} from './facility-data.js';
import {ROLE_FUNCTIONS} from './role-profile.js';

// Reuse the approved forms. Every connected write completes on the server and
// is read back through the core controller before a success message is shown.
export function createConnectedP2Controller({getState,getBackend,closeModal,toast}) {
  const client=createP2Client({request:(...args)=>getBackend().apiRequest(...args)});
  const drafts=new WeakMap();
  const ids=new Set(['role-profile-form','fac-config-form','fac-resource-form','fac-placement-form','fac-booking-form','fac-release-form','arena-reserve-form','arena-review-form','arena-cancel-form']);
  const connected=()=>getState().backend?.p2?.connected===true;
  const scope=s=>`${s.backend?.actor?.id}:${s.backend?.organizationId}`;
  function dateBounds(){const today=getState().backend?.todayDate||getState().today;const shift=n=>{const d=new Date(`${today}T12:00:00Z`);d.setUTCDate(d.getUTCDate()+n);return d.toISOString().slice(0,10);};return {today,min:shift(-366),max:shift(366)};}
  function allowedDay(day){const b=dateBounds();return validDay(day)&&day>=b.min&&day<=b.max;}
  function capture(form) {
    if(!form||!connected())return;
    if(ids.has(form.id))drafts.set(form,getState());
    if(['fac-date-form','arena-date-form','fac-booking-form','arena-reserve-form'].includes(form.id)){
      const input=form.querySelector('[name="date"]'),b=dateBounds();
      if(input){input.min=form.id.endsWith('date-form')?b.min:b.today;input.max=b.max;}
    }
  }
  function error(form,message) {
    let node=form.querySelector('.form-error,.fac-form-error,.arena-form-error,#role-profile-error');
    if(!node){node=document.createElement('p');node.className='form-error';node.setAttribute('role','alert');form.prepend(node);}
    node.hidden=false;node.textContent=message;node.scrollIntoView?.({block:'nearest'});return true;
  }
  async function load(snapshot) {return client.load(snapshot,{day:snapshot.facilityDate||snapshot.today});}
  function changeDay(day){if(!allowedDay(day)){toast('Kies een datum binnen één jaar van vandaag.');return;}getState().facilityDate=day;void getBackend().reload();}
  function handleAction(action,button){
    if(!connected())return false;
    if(action==='fac-shift-day'||action==='arena-shift-day'){
      const delta=Number(button.dataset.direction);if(![-1,1].includes(delta))return true;
      const state=getState(),d=new Date(`${state.facilityDate||state.today}T12:00:00Z`);d.setUTCDate(d.getUTCDate()+delta);changeDay(d.toISOString().slice(0,10));return true;
    }
    if(action==='fac-free-pasture'){toast('Open de reservering die je wilt vrijmaken.');return true;}
    return false;
  }
  function handleSubmit(form,event){
    if(!connected())return false;
    if(['fac-date-form','arena-date-form'].includes(form.id)){
      event.preventDefault();const day=String(new FormData(form).get('date')||'');if(!allowedDay(day))return error(form,'Kies een datum binnen één jaar van vandaag.');closeModal();changeDay(day);return true;
    }
    if(!ids.has(form.id))return false;
    event.preventDefault();
    const snapshot=drafts.get(form)||getState(),current=getState();
    if(scope(snapshot)!==scope(current))return error(form,'Je stal of account is veranderd. Open het formulier opnieuw.');
    const data=new FormData(form),get=name=>String(data.get(name)||'').trim(),fac=snapshot.facilities;
    let operation,message='Opgeslagen en opnieuw opgehaald.',day;
    if(form.id==='role-profile-form'){
      const functions=[...new Set(data.getAll('functions').map(String))].filter(id=>ROLE_FUNCTIONS.some(f=>f.id===id&&!f.later));
      if(!functions.length)return error(form,'Kies minimaal één functie die bij jou past.');
      operation=id=>client.saveFunctions(snapshot,functions,id);message='Je functieprofiel is opgeslagen. Je menu en acties sluiten nu aan.';
    }else if(form.id==='fac-config-form'){
      const values={counts:Object.fromEntries(Object.keys(FACILITY_KINDS).map(kind=>[kind,Number(get(kind))])),walkerCapacity:Number(get('walkerCapacity')),tackRoom:data.has('tackRoom')};
      operation=id=>client.configure(snapshot,values,id);message='De plekken op je stal zijn bijgewerkt.';
    }else if(form.id==='fac-resource-form'){
      const old=fac.resources.find(r=>r.id===get('resourceId'));if(!old)return error(form,'Deze plek is niet meer beschikbaar. Open het overzicht opnieuw.');
      const values={id:old.id,rowVersion:old.rowVersion,name:get('name'),type:old.kind==='arena'?get('arenaType'):old.kind==='stall'?get('type'):old.type,status:get('status'),capacity:old.kind==='arena'?Number(get('arenaCapacity')):old.capacity,note:get('description')};
      operation=id=>client.saveResource(snapshot,values,id);message='Naam en status zijn bijgewerkt.';
    }else if(form.id==='fac-placement-form'){
      const values={horseId:get('horseId'),resourceId:get('resourceId'),note:get('note')};
      operation=id=>client.setPlacement(snapshot,values,id);message='Het paard heeft een plek op stal.';
    }else if(form.id==='fac-booking-form'||form.id==='arena-reserve-form'){
      const arena=form.id==='arena-reserve-form',oldId=get('bookingId'),old=oldId?fac.bookings.find(b=>b.id===oldId):null;
      if(oldId&&!old)return error(form,'Deze reservering is veranderd. Open de planning opnieuw.');
      const horseIds=arena?(get('horseId')?[get('horseId')]:[]):data.getAll('horseIds').map(String);
      const values={id:old?.id,rowVersion:old?.rowVersion,resourceId:get('resourceId'),date:get('date'),start:get('start'),end:get('end'),horseIds,participants:arena?Number(get('participants')):horseIds.length,activity:arena?get('activity'):'',note:get('note'),exclusive:arena&&data.has('exclusive')};
      if(values.end<=values.start)return error(form,'Kies een eindtijd na de begintijd.');
      if(values.exclusive&&!values.note)return error(form,'Leg uit waarom je de hele rijbak voor jezelf wilt gebruiken.');
      day=values.date;operation=id=>client.saveBooking(snapshot,values,id);message=values.exclusive?'Je aanvraag wacht op goedkeuring van de stalmanager.':'De reservering is opgeslagen en opnieuw opgehaald.';
    }else if(form.id==='fac-release-form'){
      const releaseId=get('releaseId');
      if(get('mode')==='stall'){
        const old=fac.placements.find(p=>p.resourceId===releaseId);if(!old)return error(form,'Deze stalplaats is al vrijgemaakt.');
        operation=id=>client.setPlacement(snapshot,{horseId:old.horseId,resourceId:null,rowVersion:old.rowVersion,note:''},id);
      }else if(get('mode')==='booking'){
        const old=fac.bookings.find(b=>b.id===releaseId);if(!old)return error(form,'Deze reservering is al vrijgemaakt.');
        operation=id=>client.transitionBooking(snapshot,{id:old.id,rowVersion:old.rowVersion,action:'cancel',note:''},id);
      }else return error(form,'Open de afzonderlijke reservering die je wilt vrijmaken.');
      message='De plek is vrijgemaakt.';
    }else{
      const old=fac.arenaBookings.find(b=>b.id===get('bookingId'));if(!old)return error(form,'Deze reservering is veranderd. Open de planning opnieuw.');
      const action=form.id==='arena-cancel-form'?'cancel':get('decision')==='approved'?'approve':get('decision')==='rejected'?'reject':null;
      if(!action)return error(form,'Kies goedkeuren of afwijzen.');
      operation=id=>client.transitionBooking(snapshot,{id:old.id,rowVersion:old.rowVersion,action,note:get('decisionNote')},id);
      message=action==='approve'?'Goedgekeurd. De hele rijbak is in dit tijdvak gereserveerd.':action==='reject'?'De aanvraag is afgewezen.':'De reservering is geannuleerd.';
    }
    void getBackend().perform(form,async (id,isCurrent)=>{const result=await operation(id);if(day&&isCurrent()&&scope(getState())===scope(snapshot))getState().facilityDate=day;return result;},message);
    return true;
  }
  return {load,capture,handleAction,handleSubmit};
}
