import {browserDay} from './browser-clock.js';
// A task can be undated, on a day, or at a time on that day.
export const taskToday=state=>state.today||browserDay();
export const shiftTaskDay=(day,offset)=>{const d=new Date(day+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+offset);return d.toISOString().slice(0,10);};
export function taskDayLabel(day,today){
 if(!day)return 'Zonder datum';
 if(day===today)return 'Vandaag';
 if(day===shiftTaskDay(today,1))return 'Morgen';
 return new Date(day+'T12:00:00Z').toLocaleDateString('nl-NL',{day:'numeric',month:'long',year:day.slice(0,4)!==today.slice(0,4)?'numeric':undefined,timeZone:'UTC'});
}
export const taskWhenLabel=(task,today)=>[taskDayLabel(task.date,today),task.date&&task.time].filter(Boolean).join(' · ');
export const taskOrder=(a,b)=>`${a.date||'9999-12-31'} ${a.time||''}`.localeCompare(`${b.date||'9999-12-31'} ${b.time||''}`);
export function taskFormValues(values,today){
 const {when,addTime,...fields}=values;
 const date=when==='none'?null:when==='today'?today:when==='tomorrow'?shiftTaskDay(today,1):fields.date||null;
 return {...fields,date,time:date&&addTime==='on'?(fields.time||null):null,horseId:fields.horseId||null};
}
