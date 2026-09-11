// General prototype content, no media URLs or personalized exercise prescription.
export const EXERCISE_SAFETY='Algemene oefening. Stop bij pijn of twijfel en vraag advies aan een professional.';
export const EXERCISES=Object.freeze([
 {id:'shoulders',title:'Nek & schouders losmaken',seconds:60,focus:'Nek en schouders',description:'Maak rustige schouderrollen. Draai je hoofd langzaam links en rechts, alleen zover comfortabel.',icon:'roles'},
 {id:'hips',title:'Heupen & benen losmaken',seconds:120,focus:'Heupen en benen',description:'Sta bij vaste steun. Buig je knieën een klein stukje en kom rustig weer rechtop, zonder te forceren.',icon:'leaf'},
 {id:'ankles',title:'Enkels en kuiten activeren',seconds:60,focus:'Enkels en kuiten',description:'Houd vaste steun vast. Kom rustig op je tenen en zak gecontroleerd terug.',icon:'roles'},
 {id:'balance',title:'Balanscheck',seconds:60,focus:'Houding',description:'Sta met beide voeten op de grond bij vaste steun. Verdeel je gewicht rustig over links en rechts.',icon:'heart'},
 {id:'breathing',title:'Ademhaling en focus',seconds:30,focus:'Rust',description:'Adem rustig in en uit, op een manier die prettig voelt. Forceer niets en houd je adem niet vast.',icon:'leaf'}
].map(item=>Object.freeze({...item,level:'Rustig / basis'})));
export const ROUTINES=Object.freeze([
 {id:'basic',title:'5 minuten basis',seconds:[60,90,60,60,30],description:'Een korte algemene voorbereiding in vijf stappen.'},
 {id:'extended',title:'10 minuten uitgebreid',seconds:[120,180,120,120,60],description:'Dezelfde vijf oefeningen, met meer tijd per stap.'},
 {id:'dressage',title:'Voor dressuur',seconds:[60,90,60,60,30],description:'De algemene basisroutine, met rust en houding als focus. Geen gespecialiseerd disciplineprogramma.'},
 {id:'jumping',title:'Voor springen',seconds:null,description:'Een eigen routine voor springen volgt later.'},
 {id:'stablework',title:'Na stalwerk',seconds:null,description:'Een routine na het stalwerk volgt later.'}
].map(item=>Object.freeze({...item,seconds:item.seconds&&Object.freeze(item.seconds)})));
export const durationLabel=seconds=>seconds<60?`${seconds} sec`:`${Math.floor(seconds/60)} min${seconds%60?' '+seconds%60+' sec':''}`;
