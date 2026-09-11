/** Presentation scope only. Membership/horse access remain server-authorized.
 * A personal view has no active organization and retains its accessible horses.
 */
export function getActiveStableView(state){
 const organizationId=state.backend?.connected&&state.backend.organizationId;
 if(!organizationId)return state;
 const stableIds=new Set(state.backend.stableHorseIds||[]);
 const horses=(state.horses||[]).filter(h=>stableIds.has(h.id));
 const visibleIds=new Set(horses.map(h=>h.id));
 return {...state,horses,
  activities:(state.activities||[]).filter(a=>{const horseId=a.horseId||a.horse;return horseId?visibleIds.has(horseId):a.organizationId===organizationId;}),
  tasks:(state.tasks||[]).filter(t=>t.organizationId===organizationId),
  feeding:Object.fromEntries(Object.entries(state.feeding||{}).filter(([horseId])=>visibleIds.has(horseId)))
 };
}
