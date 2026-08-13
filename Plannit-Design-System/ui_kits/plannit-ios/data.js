window.PlannitData = (function(){
  const P = {
    maya:{name:'Maya Ellis'}, theo:{name:'Theo Sand'}, ada:{name:'Ada Kim'},
    sam:{name:'Sam Roe'}, rae:{name:'Rae Loft'}, jo:{name:'Jo Vane'}
  };
  const groups = [
    {id:'soccer', name:'Soccer', hue:'var(--hue-teal)', soft:'var(--hue-teal-soft)', members:[P.maya,P.theo,P.ada,P.sam,P.rae,P.jo], note:'Tuesday + weekend games'},
    {id:'family', name:'Family', hue:'var(--hue-amber)', soft:'var(--hue-amber-soft)', members:[P.maya,P.ada,P.rae], note:'Birthdays and Sunday lunch'},
    {id:'work', name:'Work', hue:'var(--hue-sky)', soft:'var(--hue-sky-soft)', members:[P.theo,P.sam,P.jo,P.ada], note:'Offsites only, nothing else'},
    {id:'flat', name:'Flatmates', hue:'var(--hue-indigo)', soft:'var(--hue-indigo-soft)', members:[P.sam,P.rae], note:'Bills, bins, film nights'}
  ];
  const events = [
    {id:'e1', day:16, title:'Five-a-side', time:'2:00–4:00 PM', location:'Hackney Marshes', group:'Soccer', hue:'var(--hue-teal)', icon:'dumbbell', people:[P.maya,P.theo,P.ada,P.sam,P.rae,P.jo], badge:'Found', badgeTone:'free', source:'plannit'},
    {id:'e2', day:16, title:'Dinner with Ada', time:'7:30 PM', location:'Bermondsey', hue:'var(--hue-coral)', icon:'utensils', badge:'Private', badgeTone:'neutral', source:'device'},
    {id:'e3', day:17, title:"Mum's birthday lunch", time:'1:00 PM', location:'Hers', group:'Family', hue:'var(--hue-amber)', icon:'cake', people:[P.maya,P.ada,P.rae], source:'plannit'},
    {id:'e4', day:18, title:'Film night', time:'8:00 PM', location:'The flat', group:'Flatmates', hue:'var(--hue-indigo)', icon:'film', people:[P.sam,P.rae], source:'plannit'},
    {id:'e5', day:20, title:'Dentist', time:'9:15 AM', hue:'var(--hue-coral)', icon:'clock', badge:'Private', badgeTone:'neutral', source:'device'}
  ];
  const marks = {5:['var(--hue-amber)'],9:['var(--hue-rose)'],14:['var(--hue-sky)','var(--hue-amber)'],
    16:['var(--hue-teal)','var(--hue-coral)'],17:['var(--hue-amber)'],18:['var(--hue-indigo)'],20:['var(--hue-coral)'],27:['var(--hue-teal)']};
  const proposals = [
    {id:'p1', title:'Five-a-side', group:groups[0], constraint:'Sat, Sun · afternoon · 2 hours', status:'voting', votes:4,
      slots:[
        {day:'SAT', date:16, time:'2:00 – 4:00 PM', free:6, best:true},
        {day:'SUN', date:17, time:'11:00 AM – 1:00 PM', free:5},
        {day:'SAT', date:23, time:'3:00 – 5:00 PM', free:5}
      ],
      availability:[
        {name:'Maya', blocks:[{start:9,end:11}]},
        {name:'Theo', blocks:[{start:8,end:9},{start:18,end:21}]},
        {name:'Ada', blocks:[{start:13,end:14}]},
        {name:'Sam', blocks:[]},
        {name:'Rae', blocks:[{start:19,end:22}]},
        {name:'Jo', blocks:[{start:8,end:10}]}
      ]},
    {id:'p2', title:'Someone’s 30th', group:groups[1], constraint:'Fri, Sat · evening · next 3 months', status:'found',
      slots:[{day:'SAT', date:6, time:'7:00 PM', free:3, best:true}], votes:3, availability:[]}
  ];
  return {P, groups, events, marks, proposals, people:P};
})();
