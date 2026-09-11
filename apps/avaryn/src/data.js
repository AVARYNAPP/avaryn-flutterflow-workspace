export const INITIAL_STATE = {
  persona:'manager', horseFilter:'personal', route: 'today', horseId: 'orion', period: 'today', selectedDay: '2026-09-10',
  theme: 'light', selectedTaskId: null, stableName: 'SDS Stables', stableLocation: 'Goes, Zeeland',
  horses: [
    {id:'orion',name:'Orion',breed:'KWPN',age:8,discipline:'Dressuur · Z1',image:'assets/orion.png',stable:'SDS Stables',sex:'Ruin',color:'Donkerbruin',height:'1,72 m',box:'Box 04',owner:'Emma de Vries',description:'Nieuwsgierig, werkwillig en altijd in voor een buitenrit.'},
    {id:'nova',name:'Nova',breed:'KWPN',age:9,discipline:'Springen · 1,10 m',image:'assets/nova.png',stable:'SDS Stables',sex:'Merrie',color:'Schimmel',height:'1,68 m',box:'Box 06',owner:'Sophie Bakker',description:'Een energieke merrie die graag met je meedenkt.'}
  ],
  activities: [
    {id:'a1',horseId:'orion',type:'Hoefsmid',title:'Bekappen',date:'2026-09-10',time:'10:30',end:'11:15',status:'planned',person:'Daan Visser',location:'Poetsplaats',note:'Zet Orion klaar op de poetsplaats. Zijn halster hangt naast box 04.'},
    {id:'a2',horseId:'nova',type:'Training',title:'Springles met Sophie',date:'2026-09-10',time:'14:00',end:'14:45',status:'planned',person:'Sophie Bakker',location:'Buitenbak',note:'Neem het springzadel mee. Sophie bespreekt de oefeningen bij aanvang van de les.'},
    {id:'a3',horseId:'orion',type:'Verzorging',title:'Avondronde',date:'2026-09-10',time:'18:00',end:'18:20',status:'planned',person:'Noor Meijer',location:'Stalgang A',note:'Controleer de drinkbak en leg het halster terug op de vaste plek.'},
    {id:'a4',horseId:'orion',type:'Training',title:'Dressuurles met Sophie',date:'2026-09-11',time:'09:30',end:'10:15',status:'planned',person:'Sophie Bakker',location:'Binnenbak',note:'Zadel Orion op met de zwarte dressuurset. De les wordt samen met Sophie ingevuld.'},
    {id:'a5',horseId:'nova',type:'Wedstrijd',title:'Springen in De Kroo',date:'2026-09-12',time:'11:00',end:'12:00',status:'planned',person:'Emma de Vries',location:'Nieuw- en Sint Joosland',note:'Starttijd en route samen controleren. Wedstrijdset ligt in kast 06.'},
    {id:'a6',horseId:'orion',type:'Verzorging',title:'Vacht verzorgen',date:'2026-09-13',time:'10:00',end:'10:30',status:'planned',person:'Noor Meijer',location:'Poetsplaats',note:'Borstelset staat op de plank naast box 04.'},
    {id:'a7',horseId:'nova',type:'Dierenarts',title:'Jaarlijkse afspraak',date:'2026-09-17',time:'13:00',end:'13:30',status:'planned',person:'Emma de Vries',location:'SDS Stables',note:'Paspoort ligt in het kantoor. Emma is bij de afspraak aanwezig.'},
    {id:'a8',horseId:'orion',type:'Training',title:'Buitenrit',date:'2026-09-19',time:'10:00',end:'11:00',status:'planned',person:'Emma de Vries',location:'Bosroute',note:'Verzamel bij de ingang van de stal.'}
  ],
  tasks: [
    {id:'t1',horseId:'orion',title:'Hooiruif vullen',date:'2026-09-10',time:'09:00',location:'Weide 6',note:'Vul de hooiruif met de klaargelegde portie uit de voerkar. Sluit het weidehek achter je en zet de voerkar terug in de opslag.',status:'open',assignee:'Noor Meijer'},
    {id:'t2',horseId:'nova',title:'Nova klaarmaken voor de training',date:'2026-09-10',time:'13:45',location:'Poetsplaats',note:'Poets Nova en leg de springuitrusting klaar. Het zadel en hoofdstel hangen bij kast 06. Sophie haalt haar om 14:00 op.',status:'open',assignee:'Noor Meijer'},
    {id:'t3',horseId:'orion',title:'Orion voeren',date:'2026-09-10',time:'18:00',location:'Box 04',note:'Volg het avondblok bij Orions voerinstructies. Controleer ook de drinkbak en laat weten wanneer je klaar bent.',status:'open',assignee:'Noor Meijer'},
    {id:'t4',horseId:null,title:'Stalgang en poetsplaats netjes',date:'2026-09-10',time:'08:00',location:'Stalgang A',note:'Bezem en kruiwagen terugzetten na de ochtendronde.',status:'done',assignee:'Emma de Vries'}
  ],
  feeding: {
    orion: {status:'Basisvoeding actief',note:'De klaargelegde porties staan in de voerkar bij stalgang A.',meals:[
      {name:'Ochtend',time:'07:30',items:[{product:'Hooi',amount:'1 baal',note:'Portie ligt klaar in de voerkar.'},{product:'Brok',amount:'1 kg',note:'Gebruik de blauwe voerbak.'}]},
      {name:'Middag',time:'12:30',items:[]},
      {name:'Avond',time:'18:00',items:[{product:'Supplement',amount:'20 g',note:'Afgewogen bakje bij box 04.'},{product:'Hooi',amount:'1 baal',note:'Portie uit de voerkar.'}]}
    ]},
    nova: {status:'Tijdelijk schema actief',note:'Tot en met 14 september. Daarna geldt de bewaarde basisvoeding weer.',until:'2026-09-14',meals:[
      {name:'Ochtend',time:'07:30',items:[{product:'Hooi',amount:'1 baal',note:'Portie ligt klaar bij box 06.'},{product:'Brok',amount:'1 kg',note:'Gebruik de groene voerbak.'}]},
      {name:'Middag',time:'12:30',items:[]},
      {name:'Avond',time:'18:00',items:[{product:'Supplement',amount:'20 g',note:'Afgewogen bakje bij box 06.'},{product:'Hooi',amount:'1 baal',note:'Portie uit de voerkar.'}]}
    ]}
  },
  team: [{name:'Emma de Vries',role:'Stalmanager · eigenaar',initials:'EV'},{name:'Noor Meijer',role:'Groom',initials:'NM'},{name:'Sophie Bakker',role:'Trainer',initials:'SB'},{name:'Daan Visser',role:'Hoefsmid',initials:'DV'}]
};
