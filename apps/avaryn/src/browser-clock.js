// Civil values stay date-only. Connected instants use the verified account zone;
// browser-local behavior remains the default for demo and pre-profile screens.
export function browserDay(now=new Date()){
  return `${now.getFullYear()}-${String(now.getMonth()+1).padStart(2,'0')}-${String(now.getDate()).padStart(2,'0')}`;
}
function zonedParts(now,timeZone){
  return Object.fromEntries(new Intl.DateTimeFormat('en-GB',{timeZone,year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',hourCycle:'h23'}).formatToParts(now).map(p=>[p.type,p.value]));
}
const zonedDay=(now,timeZone)=>{const p=zonedParts(now,timeZone);return `${p.year}-${p.month}-${p.day}`;};
export function dashboardClock(now=new Date(),state){
  const b=state?.backend;
  const timeZone=b?.connected===true&&b.profile?.profile_status==='active'?(b.calendar?.time_zone||b.profile.time_zone):undefined;
  const p=timeZone?zonedParts(now,timeZone):null,hour=p?Number(p.hour):now.getHours();
  const label=now.toLocaleDateString('nl-NL',{...(timeZone?{timeZone}:{}),weekday:'long',day:'numeric',month:'long'});
  return {day:p?`${p.year}-${p.month}-${p.day}`:browserDay(now),dateLabel:label.charAt(0).toLocaleUpperCase('nl-NL')+label.slice(1),greeting:hour>=5&&hour<12?'Goedemorgen':hour>=12&&hour<18?'Goedemiddag':'Goedenavond'};
}
export function activityDay(activity){
  const instant=activity.scheduledStartAt&&new Date(activity.scheduledStartAt);
  return instant&&Number.isFinite(instant.getTime())?(activity.displayTimezone?zonedDay(instant,activity.displayTimezone):browserDay(instant)):activity.date;
}
export function activityOrder(a,b){
  if(a.scheduledStartAt&&b.scheduledStartAt)return Date.parse(a.scheduledStartAt)-Date.parse(b.scheduledStartAt);
  return String(a.time||'99:99').localeCompare(String(b.time||'99:99'));
}
export function browserActivity(activity){
  if(!activity.scheduledStartAt)return activity;
  const time=value=>value?new Date(value).toLocaleTimeString('nl-NL',{...(activity.displayTimezone?{timeZone:activity.displayTimezone}:{}),hour:'2-digit',minute:'2-digit'}):'';
  return {...activity,date:activityDay(activity),time:time(activity.scheduledStartAt),end:time(activity.scheduledEndAt)};
}
