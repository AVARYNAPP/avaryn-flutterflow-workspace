import {dashboardClock} from './browser-clock.js';
const day=dashboardClock().day;
export const INITIAL_STATE={route:'today',horseFilter:'personal',period:'today',theme:'light',today:day,selectedDay:day,horseId:null,selectedTaskId:null,stableName:'Jouw paarden',stableLocation:'',horses:[],tasks:[],activities:[],feeding:{},team:[]};
