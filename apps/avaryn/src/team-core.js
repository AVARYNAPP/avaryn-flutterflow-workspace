import {esc,icon} from './components.js';
const one=v=>Array.isArray(v)?v[0]:v;
const scope=s=>`${s.backend?.actor?.id}:${s.backend?.organizationId}`;
const tokenPattern=/^[a-f0-9]{64}$/;
const footer=label=>`<footer class="modal-footer"><button type="button" class="button-secondary" data-action="close-modal">Annuleren</button><button type="submit" class="button-primary">${label}</button></footer>`;
const uncertain=()=>Object.assign(Error('De uitkomst is nog niet bevestigd. Controleer de actuele gegevens.'),{uncertain:true});
export function invitationToken(input,origin){
 const value=String(input||'').trim();if(tokenPattern.test(value))return value;
 try{const u=new URL(value);return u.origin===origin&&u.pathname==='/uitnodiging'&&!u.hash&&[...u.searchParams.keys()].length===1&&tokenPattern.test(u.searchParams.get('invitation')||'')?u.searchParams.get('invitation'):null;}catch{return null;}
}
/** One-time invitations stay in memory and are shown only in their originating modal. */
export function createTeamCore({getState,showModal,perform,apiRequest,toast}){
 const results=new WeakMap(),previews=new WeakMap(),captures=new WeakMap(),drafts=new WeakMap();let pendingToken=null;
 const allowed=code=>getState().backend?.permissionCodes?.[code]===true;
 const rpc=(name,args,write=false)=>apiRequest(name,args,{write});
 const roles=()=>getState().backend.roles||[];
 const roleOptions=selected=>roles().map(r=>`<option value="${esc(r.code)}"${r.code===selected?' selected':''}>${esc(r.name)}</option>`).join('');
 function open(title,body,buttons='',caption=getState().stableName){showModal(title,body,buttons,caption);const form=document.querySelector('#modal form');if(form)captures.set(form,scope(getState()));return form;}
 function team(){
  const s=getState();if(!s.backend.capabilities.canViewTeam)return;
  const manage=allowed('organization.memberships.manage'),primary=s.backend.organization?.primary_authority_profile_id;
  open('Samen op stal',`<div class="team-list">${s.team.map(t=>`<div class="team-person"><span class="profile-avatar">${esc(t.initials)}</span><div><strong>${esc(t.name)}</strong><small>${esc(t.role)}</small>${manage&&t.id!==primary?`<button class="text-link" data-action="team-member" data-id="${esc(t.membershipId)}">Toegang beheren</button>`:''}</div></div>`).join('')||'<p>Er zijn nog geen teamleden.</p>'}</div>${allowed('organization.invitations.manage')?`<h3>Open uitnodigingen</h3>${s.backend.invitations.filter(i=>i.status==='pending').map(i=>`<div class="team-person"><div><strong>${esc(i.recipient_label||'Uitgenodigde persoon')}</strong><small>${esc(i.role_name)} · geldig tot ${esc(new Date(i.expires_at).toLocaleDateString('nl-NL'))}</small><button class="text-link" data-action="team-revoke-invite" data-id="${esc(i.id)}">Uitnodiging intrekken</button></div></div>`).join('')||'<p class="horse-muted">Geen open uitnodigingen.</p>'}`:''}`,allowed('organization.invitations.manage')?'<button class="button-primary" data-action="team-invite">Teamlid uitnodigen</button>':'');
 }
 function invite(){
  if(!allowed('organization.invitations.manage'))return;
  open('Teamlid uitnodigen',`<form id="core-invite-form"><label class="form-field">E-mailadres<input name="email" type="email" required autocomplete="email"></label><label class="form-field">Rol op stal<select name="role" required><option value="">Kies een rol</option>${roleOptions()}</select></label><p class="horse-muted">De link is zeven dagen geldig en hoort bij dit bevestigde e-mailadres. Een stalrol geeft geen automatische toegang tot alle paarden. Je deelt de link zelf.</p>${footer('Uitnodiging maken')}</form>`);
 }
 function acceptForm(token=pendingToken){
  pendingToken=null;open('Uitnodiging openen',`<form id="core-invite-preview-form"><label class="form-field">Eenmalige code of AVARYN-link<input name="invitation" value="${esc(token||'')}" autocomplete="off" required></label><p class="horse-muted">Gebruik het account met het e-mailadres waarvoor je bent uitgenodigd.</p>${footer('Uitnodiging controleren')}</form>`,'','Jouw account');
 }
 function member(id){
  const s=getState(),m=s.team.find(m=>m.membershipId===id);
  if(!m||!allowed('organization.memberships.manage')||m.id===s.backend.organization?.primary_authority_profile_id)return;
  const form=open(m.name,`<form id="core-member-form" data-id="${esc(id)}" data-version="${m.rowVersion}">${allowed('organization.roles.manage')?`<label class="form-field">Rol op stal<select name="role">${roleOptions(m.roleCode)}</select></label>`:''}<label class="form-field">Wijziging<select name="change">${allowed('organization.roles.manage')?'<option value="role">Rol opslaan</option>':''}<option value="revoke">Staltoegang intrekken</option></select></label><p class="horse-muted">Bij intrekken vervalt de staltoegang. Afzonderlijk verleende paardenrechten en eerdere activiteiten blijven behouden.</p>${footer('Wijziging bevestigen')}</form>`);
  if(form)results.set(form,{kind:'team'});
 }
 function handleAction(action,button){
  if(!getState().backend?.connected)return false;
  if(action==='team'){team();return true;}
  if(action==='team-invite'){invite();return true;}
  if(action==='open-invitation'){acceptForm();return true;}
  if(action==='team-member'){member(button.dataset.id);return true;}
  if(action==='team-revoke-invite'){
   const i=getState().backend.invitations.find(i=>i.id===button.dataset.id&&i.status==='pending');
   if(i&&allowed('organization.invitations.manage'))open('Uitnodiging intrekken?',`<form id="core-invite-revoke-form" data-id="${esc(i.id)}" data-version="${i.row_version}"><p>Deze link kan daarna niet meer worden gebruikt om lid te worden.</p>${footer('Uitnodiging intrekken')}</form>`);return true;
  }
  return false;
 }
 function handleSubmit(form,event){
  if(!['core-invite-form','core-invite-preview-form','core-invite-response-form','core-invite-revoke-form','core-member-form'].includes(form.id))return false;
  event.preventDefault();if(captures.get(form)!==scope(getState())||!form.isConnected||document.getElementById(form.id)!==form){toast('Open dit formulier opnieuw voor je huidige account en stal.');return true;}
  const f=form.dataset.uncertain==='true'?drafts.get(form):Object.fromEntries(new FormData(form)),s=getState();
  if(!f)return true;drafts.set(form,f);
  if(form.id==='core-invite-preview-form'){
   const token=invitationToken(f.invitation,location.origin);if(!token){toast('Gebruik de volledige AVARYN-link of een geldige eenmalige code.');return true;}
   const captured=scope(s),modal=document.querySelector('#modal'),viewId=modal.dataset.viewId;form.querySelector('button[type="submit"]').disabled=true;
   rpc('preview_organization_invitation',{p_invitation_token:token}).then(value=>{
    if(scope(getState())!==captured||!modal.open||modal.dataset.viewId!==viewId)return;
    const preview=one(value);if(!preview?.organization_id){toast('Deze uitnodiging hoort niet bij je account, is verlopen of al gebruikt.');return;}
    const next=open('Staluitnodiging',`<form id="core-invite-response-form"><p>Je bent uitgenodigd voor <strong>${esc(preview.organization_name)}</strong> als ${esc(preview.role_name)}.</p><label class="form-field">Jouw keuze<select name="response"><option value="accept">Uitnodiging accepteren</option><option value="decline">Uitnodiging weigeren</option></select></label>${footer('Keuze bevestigen')}</form>`,'','Jouw account');
    previews.set(next,{...preview,token});
   }).catch(e=>{if(scope(getState())===captured&&modal.open&&modal.dataset.viewId===viewId)toast(e.userMessage||e.message);}).finally(()=>{form.querySelector('button[type="submit"]').disabled=false;});return true;
  }
  if(form.id==='core-invite-form')perform(form,async requestId=>{
   const expiry=form.dataset.expiresAt||(form.dataset.expiresAt=new Date(Date.now()+7*86400000).toISOString());
   const value=one(await rpc('create_c010_stable_invitation',{p_organization_id:s.backend.organizationId,p_role_code:f.role,p_target_email:f.email.trim(),p_expires_at:expiry,p_request_id:requestId},true));
   if(!value?.invitation_id)throw uncertain();results.set(form,{kind:'invitation',token:value.invitation_token});
  },'De uitnodiging is gecontroleerd.');
  if(form.id==='core-invite-response-form')perform(form,async requestId=>{
   const p=previews.get(form);if(!p||!['accept','decline'].includes(f.response))throw Error('Open de uitnodiging opnieuw.');
   // Keep the accepted acknowledgement for readback retries: the token is single-use.
   let value=results.get(form);
   if(!value){value=one(await rpc('respond_stable_invitation',{p_invitation_token:p.token,p_action:f.response,p_correlation_id:requestId},true));if(!['accepted','declined'].includes(value?.status))throw uncertain();results.set(form,value);}
   if(value.status==='accepted')form.dataset.resultOrganizationId=p.organization_id;
  },'Je keuze is opgeslagen.','stable');
  if(form.id==='core-invite-revoke-form')perform(form,async requestId=>{
   const value=one(await rpc('revoke_organization_invitation',{p_invitation_id:form.dataset.id,p_expected_row_version:Number(form.dataset.version),p_correlation_id:requestId},true));
   if(value?.status!=='revoked')throw Error('De uitnodiging is intussen gewijzigd. Open het teamoverzicht om de actuele toegang te controleren.');
  },'Uitnodiging ingetrokken.');
  if(form.id==='core-member-form')perform(form,async requestId=>{
   const revoke=f.change==='revoke';
   const value=await rpc(revoke?'revoke_c010_membership':'set_c010_team_role',revoke?{p_organization_id:s.backend.organizationId,p_membership_id:form.dataset.id,p_expected_row_version:Number(form.dataset.version),p_request_id:requestId}:{p_organization_id:s.backend.organizationId,p_membership_id:form.dataset.id,p_expected_membership_row_version:Number(form.dataset.version),p_role_code:f.role,p_request_id:requestId},true);
   if(value?.organization_id!==s.backend.organizationId||value?.membership_id!==form.dataset.id||revoke&&(value.status!=='ended'||!Number.isSafeInteger(value.row_version))||!revoke&&(value.role_code!==f.role||!Number.isSafeInteger(value.membership_row_version)))throw uncertain();
  },'De staltoegang is bijgewerkt.');
  return true;
 }
 function afterSave(form){
  const value=results.get(form);results.delete(form);previews.delete(form);
  if(value?.kind!=='invitation')return;
  if(!tokenPattern.test(value.token||'')){open('Open uitnodiging','<p>Er bestaat al een open uitnodiging. Trek die via het teamoverzicht in als je een nieuwe link nodig hebt.</p>','<button class="button-primary" data-action="team">Naar het team</button>');return;}
  const link=new URL('/uitnodiging',location.origin);link.searchParams.set('invitation',value.token);
  open('Uitnodiging klaar',`<p>Deel deze eenmalige link zelf met de bedoelde ontvanger. Na sluiten tonen we hem niet opnieuw. Er is geen e-mail verstuurd.</p><label class="form-field">Uitnodigingslink<textarea readonly aria-label="Uitnodigingslink">${esc(link.href)}</textarea></label>`,'<button class="button-primary" data-action="close-modal">Gereed</button>');
 }
 function consumeLink(loc=location,history=globalThis.history){if(loc.pathname!=='/uitnodiging')return;pendingToken=invitationToken(loc.href,loc.origin);history.replaceState(history.state,'','/#/vandaag');}
 function resume(){if(pendingToken&&getState().backend?.connected)acceptForm();}
 return {handleAction,handleSubmit,afterSave,consumeLink,resume};
}
