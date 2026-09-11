import {esc,icon} from './components.js';
import {canEditFeeding} from './horse-access.js';
export const FEED_MEALS={morning:'Ochtend',afternoon:'Middag',evening:'Avond'};
const units={kg:'kg',g:'g',ml:'ml',l:'l',piece:'stuk',portion:'portie',scoop:'schep',bale:'baal'};
const types={roughage:'Ruwvoer',pellet:'Brok',muesli:'Muesli',mash:'Slobber',supplement:'Supplement',oil:'Olie',other:'Overig',medication:'Voorgeschreven middel'};
const date=value=>/^\d{4}-\d\d-\d\d$/.test(value||'')?value.split('-').reverse().join('-'):'Kies een datum';
const nextWeek=value=>new Date(Date.parse(value+'T12:00:00Z')+7*86400000).toISOString().slice(0,10);
const footer=label=>`<footer class="modal-footer"><button type="button" class="button-secondary" data-action="close-modal">Annuleren</button><button type="submit" class="button-primary">${icon('check',17)} ${label}</button></footer>`;
export function feedingProductRow(item={}){
 return `<div class="backend-feed-row" data-item-id="${esc(item.id||'')}" data-item-version="${esc(item.rowVersion||'')}"><div class="backend-feed-grid"><label class="form-field">Product<input data-field="product" value="${esc(item.product||'')}" maxlength="240" required></label><label class="form-field">Hoeveelheid<input data-field="quantity" inputmode="decimal" value="${esc(item.quantity??'')}" required></label><label class="form-field">Eenheid<select data-field="unit">${Object.entries(units).map(([u,label])=>`<option value="${u}"${u===(item.unit||'kg')?' selected':''}>${label}</option>`).join('')}</select></label></div><label class="form-field">Soort<select data-field="productType" required><option value="">Kies een productsoort</option>${Object.entries(types).map(([v,label])=>`<option value="${v}"${item.productType===v?' selected':''}>${label}</option>`).join('')}</select></label><label class="form-field">Instructie<textarea data-field="note">${esc(item.note||'')}</textarea></label><button type="button" class="text-link" data-action="backend-remove-feed">Product weghalen</button></div>`;
}
export function renderTemporaryPreview({plan,roundCode,items,from,until}){
 return `<div class="instruction-box"><h3>Volledig tijdelijk schema na deze opslag</h3><p>${esc(date(from))} tot en met ${esc(date(until))}</p><p>Dit vervangt alle basisvoeding in deze periode. De basis blijft bewaard en wordt daarna hervat.</p>${Object.entries(FEED_MEALS).map(([code,name])=>{
  const products=code===roundCode?items:plan?.meals.find(m=>m.code===code)?.items||[];
  return `<section class="form-block"><h4>${name}</h4>${products.length?`<ul>${products.map(i=>`<li>${esc(i.product||'Product nog invullen')} · ${esc(i.quantity??'')} ${esc(units[i.unit]||i.unit||'')}${i.note?`<p>${esc(i.note)}</p>`:''}</li>`).join('')}</ul>`:'<p>Geen producten — basisvoeding wordt niet aangevuld.</p>'}</section>`;
 }).join('')}</div>`;
}
/** One round per form: selecting a daypart never discards another unsaved round.
 * Form metadata and row versions are captured on open, not replaced by a reload.
 */
export function createFeedingEditor({getState,showModal,perform,client,formError,reload}){
 const contexts=new WeakMap();
 const horse=(horseId)=>{const s=getState(),h=s.horses.find(h=>h.id===horseId);return h&&canEditFeeding(s,h)?h:null;};
 const findPlan=(horseId,planId)=>getState().feeding[horseId]?.plans?.find(p=>p.planId===planId&&p.planStatus!=='retired');
 function plans(horseId){
  const h=horse(horseId);if(!h)return;const feed=getState().feeding[horseId],available=(feed?.plans||[]).filter(p=>p.planStatus!=='retired');
  const basis=available.find(p=>p.planType==='standard'),temporaries=available.filter(p=>p.planType==='temporary');
  const button=(label,p,type)=>`<button class="button-secondary" data-action="backend-feed-plan" data-horse="${esc(horseId)}" data-plan="${esc(p?.planId||'')}" data-plan-type="${type}">${esc(label)}</button>`;
  showModal(`Voeding · ${h.name}`,`<div class="scope-options">${button(basis?'Basisvoeding aanpassen':'Basisvoeding vastleggen',basis,'standard')}${temporaries.map(p=>button(`Tijdelijk · ${date(p.effectiveFrom)} – ${date(p.effectiveUntil)}`,p,'temporary')).join('')}${basis?.planStatus==='active'?button('Tijdelijk schema toevoegen',null,'temporary'):'<p>Leg eerst de basisvoeding vast. Daarna kun je tijdelijk een ander volledig schema gebruiken.</p>'}</div>`,'','Voeding');
 }
 function chooseRound(horseId,planId,type){
  const h=horse(horseId),plan=planId?findPlan(horseId,planId):null;if(!h||(planId&&!plan))return;
  type=plan?.planType||type;if(!['standard','temporary'].includes(type))return;
  if(type==='temporary'&&!(getState().feeding[horseId]?.plans||[]).some(p=>p.planType==='standard'&&p.planStatus==='active'))return;
  showModal(`${type==='temporary'?'Tijdelijk schema':'Basisvoeding'} · ${h.name}`,`<p>Welk dagdeel wil je ${plan?'aanpassen':'vastleggen'}? Je slaat ieder dagdeel afzonderlijk op.</p><div class="meal-select">${Object.entries(FEED_MEALS).map(([code,name])=>`<button class="button-secondary" data-action="backend-feed-meal" data-horse="${esc(horseId)}" data-plan="${esc(planId||'')}" data-plan-type="${type}" data-meal="${code}">${name}</button>`).join('')}</div>${plan?.planType==='temporary'?`<div class="scope-options"><button class="button-secondary" data-action="backend-feed-end" data-horse="${esc(horseId)}" data-plan="${esc(planId)}">Eerder laten eindigen</button><button class="text-link" data-action="backend-feed-remove" data-horse="${esc(horseId)}" data-plan="${esc(planId)}">Tijdelijk schema verwijderen</button></div>`:''}`,'','Voeding');
 }
 function readItems(form){return [...form.querySelectorAll('.backend-feed-row')].map(row=>({id:row.dataset.itemId||undefined,rowVersion:row.dataset.itemVersion?Number(row.dataset.itemVersion):undefined,...Object.fromEntries(['product','quantity','unit','note','productType'].map(k=>[k,row.querySelector(`[data-field="${k}"]`).value]))}));}
 function refreshPreview(form){const c=contexts.get(form);if(!c||c.type!=='temporary')return;const box=form.querySelector('[data-feed-preview]');if(box)box.innerHTML=renderTemporaryPreview({plan:c.plan,roundCode:c.code,items:readItems(form),from:form.elements.namedItem('effectiveFrom').value,until:form.elements.namedItem('effectiveUntil').value});}
 function edit(horseId,planId,type,code){
  const s=getState(),h=horse(horseId),plan=planId?findPlan(horseId,planId):null;if(!h||(planId&&!plan)||!FEED_MEALS[code])return;
  type=plan?.planType||type;if(!['standard','temporary'].includes(type))return;
  const from=plan?.effectiveFrom||s.today,until=plan?.effectiveUntil||(type==='temporary'?nextWeek(s.today):''),items=plan?.meals.find(m=>m.code===code)?.items||[];
  showModal(`${FEED_MEALS[code]} · ${type==='temporary'?'Tijdelijk schema':'Basisvoeding'}`,`<form id="backend-feeding-form"><p class="horse-muted">${esc(h.name)} · Je slaat dit hele dagdeel op. De andere opgeslagen dagdelen blijven behouden.</p>${type==='temporary'?`<div class="form-grid"><label class="form-field">Geldig van<input type="date" name="effectiveFrom" value="${esc(from)}" required></label><label class="form-field">Geldig tot en met<input type="date" name="effectiveUntil" value="${esc(until)}" required></label></div>`:`<input type="hidden" name="effectiveFrom" value="${esc(from)}"><input type="hidden" name="effectiveUntil" value="${esc(until)}"><p>Basisvoeding vanaf ${date(from)}${until?` tot en met ${date(until)}`:''}.</p>`}<div id="backend-feed-items">${(items.length?items:[{}]).map(feedingProductRow).join('')}</div><button type="button" class="text-link" data-action="backend-add-feed">${icon('plus',15)} Product toevoegen</button>${type==='temporary'?'<section class="form-block" data-feed-preview></section><label class="form-field"><span><input type="checkbox" name="replacementConfirmed" required> Ik heb alle dagdelen gecontroleerd: dit tijdelijke schema vervangt de volledige basisvoeding.</span></label>':''}${footer('Dagdeel opslaan')}</form>`,'','Voeding');
  const form=document.getElementById('backend-feeding-form');contexts.set(form,{horseId,plan:plan?structuredClone(plan):null,type,code,day:s.today});
  form.addEventListener('input',event=>{const check=form.elements.namedItem('replacementConfirmed');if(check&&event.target.name!=='replacementConfirmed')check.checked=false;refreshPreview(form);});form.addEventListener('change',event=>{if(event.target.name!=='replacementConfirmed'){const check=form.elements.namedItem('replacementConfirmed');if(check)check.checked=false;}refreshPreview(form);});refreshPreview(form);
 }
 function end(horseId,planId){
  const h=horse(horseId),p=findPlan(horseId,planId);if(!h||p?.planType!=='temporary')return;
  showModal('Tijdelijk schema eerder laten eindigen',`<form id="backend-feed-end-form"><p>${esc(h.name)} · Huidige periode: ${date(p.effectiveFrom)} tot en met ${date(p.effectiveUntil)}.</p><label class="form-field">Laatste dag van het tijdelijke schema<input name="until" type="date" min="${p.effectiveFrom}" max="${p.effectiveUntil}" value="${getState().today>=p.effectiveFrom&&getState().today<p.effectiveUntil?getState().today:p.effectiveFrom}" required></label><p class="horse-muted">Deze laatste dag telt mee. Vanaf de volgende dag wordt de basisvoeding hervat.</p>${footer('Einddatum opslaan')}</form>`,'','Voeding');
  contexts.set(document.getElementById('backend-feed-end-form'),{horseId,plan:structuredClone(p),day:getState().today});
 }
 function remove(horseId,planId){
  const h=horse(horseId),p=findPlan(horseId,planId);if(!h||p?.planType!=='temporary')return;
  showModal('Tijdelijk schema verwijderen',`<form id="backend-feed-remove-form"><p>Het tijdelijke schema van ${esc(h.name)} (${date(p.effectiveFrom)} tot en met ${date(p.effectiveUntil)}) verdwijnt uit het actieve overzicht. De basisvoeding en eerdere registraties blijven bewaard.</p>${footer('Tijdelijk schema verwijderen')}</form>`,'','Voeding');contexts.set(document.getElementById('backend-feed-remove-form'),{horseId,plan:structuredClone(p)});
 }
 function handleAction(action,button){
  const {horse:horseId,plan:planId,planType,meal}=button.dataset;
  if(action==='edit-feeding'){plans(horseId||getState().horseId);return true;}
  if(action==='backend-feed-plan'){chooseRound(horseId,planId,planType);return true;}
  if(action==='backend-feed-meal'){edit(horseId,planId,planType,meal);return true;}
  if(action==='backend-feed-end'){end(horseId,planId);return true;}
  if(action==='backend-feed-remove'){remove(horseId,planId);return true;}
  if(action==='backend-feed-reload'){reload();return true;}
  if(action==='backend-add-feed'||action==='backend-remove-feed'){
   const form=button.closest('form');if(!contexts.has(form)||form.dataset.busy==='true'||form.dataset.uncertain==='true')return true;
   if(action==='backend-add-feed')form.querySelector('#backend-feed-items').insertAdjacentHTML('beforeend',feedingProductRow());else button.closest('.backend-feed-row').remove();
   const check=form.elements.namedItem('replacementConfirmed');if(check)check.checked=false;refreshPreview(form);return true;
  }return false;
 }
 function handleSubmit(form,event){
  const c=contexts.get(form);if(!c)return false;event.preventDefault();if(!horse(c.horseId))return true;
  const p=c.plan;
  if(form.id==='backend-feed-remove-form'){perform(form,id=>client.retireFeedingPlan({horseId:c.horseId,planId:p.planId,planRowVersion:p.planRowVersion},id),'Tijdelijk schema verwijderd en opnieuw opgehaald.');return true;}
  let input;
  if(form.id==='backend-feed-end-form'){
   const until=form.elements.namedItem('until').value,round=p.meals.find(m=>m.items.length);
   if(!round||until<p.effectiveFrom||until>=p.effectiveUntil){formError(form,new Error('Kies een laatste dag vanaf de begindatum en vóór de bestaande einddatum.'));return true;}
   input={horseId:c.horseId,day:c.day,planId:p.planId,planType:'temporary',planRowVersion:p.planRowVersion,mealName:round.code,effectiveFrom:p.effectiveFrom,effectiveUntil:until,items:round.items};
  }else{
   if(c.type==='temporary'&&!form.elements.namedItem('replacementConfirmed').checked){formError(form,new Error('Controleer en bevestig eerst het volledige tijdelijke schema.'));return true;}
   input={horseId:c.horseId,day:c.day,planId:p?.planId||null,planType:c.type,planRowVersion:p?.planRowVersion||null,mealName:c.code,effectiveFrom:form.elements.namedItem('effectiveFrom').value,effectiveUntil:form.elements.namedItem('effectiveUntil').value||null,items:readItems(form)};
  }
  perform(form,id=>client.saveFeedingRound(input,id),form.id==='backend-feed-end-form'?'Einddatum opgeslagen en opnieuw opgehaald.':'Dagdeel opgeslagen en opnieuw opgehaald.');return true;
 }
 return {handleAction,handleSubmit};
}
