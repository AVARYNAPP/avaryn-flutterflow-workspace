const context=s=>`${s.backend?.actor?.id}:${s.backend?.calendar?.today_date||s.today}`;
function checked(value,state){
 if(value?.profile_id!==state.backend.actor.id||value.on_date!==(state.backend.calendar?.today_date||state.today)||!Number.isSafeInteger(value.row_version)||!value.document||typeof value.document!=='object')throw Error('Je persoonlijke voortgang kon niet worden gecontroleerd.');
 return value;
}
export function createVitalityBackend({getState,getBackend}){
 async function read(state){return checked(await getBackend().apiRequest('get_c010_my_vitality_day',{p_on_date:state.backend.calendar?.today_date||state.today}),state);}
 async function load(state){state.backend.vitality=await read(state);return state;}
 async function save({document,rowVersion,requestId}){
  const state=getState(),scope=context(state),day=state.backend.calendar?.today_date||state.today;
  const result=await getBackend().apiRequest('save_c010_my_vitality_day',{p_on_date:day,p_expected_row_version:rowVersion,p_document:document,p_request_id:requestId},{write:true});
  if(context(getState())!==scope)return false;
  if(result?.on_date!==day||!Number.isSafeInteger(result.row_version))throw Object.assign(Error('Opslaan is nog niet bevestigd. Probeer dezelfde aanvraag opnieuw.'),{uncertain:true});
  let current;
  try{
   current=await read(getState());
   if(current.row_version<result.row_version)throw Error('De opgeslagen voortgang is nog niet teruggelezen.');
  }catch(error){throw Object.assign(error,{uncertain:true});}
  if(context(getState())!==scope)return false;
  getState().backend.vitality=current;return true;
 }
 return {load,save};
}
