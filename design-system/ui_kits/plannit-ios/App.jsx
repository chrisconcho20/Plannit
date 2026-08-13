const {TabBar,Toast}=window.PlannitDesignSystem_ede968;

const TABS=[
  {value:'cal',label:'Calendar',icon:'calendar-days'},
  {value:'groups',label:'Groups',icon:'users'},
  {value:'plans',label:'Plans',icon:'sparkles',badge:2},
  {value:'you',label:'You',icon:'user'}
];

function App(){
  const [flow,setFlow]=React.useState('welcome');   // welcome | connect | app
  const [tab,setTab]=React.useState('cal');
  const [stack,setStack]=React.useState(null);      // {type,payload}
  const [sheet,setSheet]=React.useState(null);      // 'plan' | 'group'
  const [toast,setToast]=React.useState(null);

  React.useEffect(()=>{ if(!toast) return; const t=setTimeout(()=>setToast(null),3200); return ()=>clearTimeout(t); },[toast]);

  if(flow==='welcome') return <Phone><Welcome onStart={()=>setFlow('connect')} onSignIn={()=>setFlow('app')}/></Phone>;
  if(flow==='connect') return <Phone><ConnectCalendar onDone={()=>setFlow('app')}/></Phone>;

  let body;
  if(stack&&stack.type==='event') body=<EventDetail event={stack.payload} onBack={()=>setStack(null)}/>;
  else if(stack&&stack.type==='group') body=<GroupDetail group={stack.payload} onBack={()=>setStack(null)} onFindDate={()=>setSheet('plan')}/>;
  else if(stack&&stack.type==='plan') body=<PlanDetail plan={stack.payload} onBack={()=>setStack(null)}/>;
  else if(tab==='cal') body=<CalendarScreen onOpenEvent={e=>setStack({type:'event',payload:e})} onNewPlan={()=>setSheet('plan')}/>;
  else if(tab==='groups') body=<GroupsScreen onOpenGroup={g=>setStack({type:'group',payload:g})} onNewGroup={()=>setSheet('group')}/>;
  else if(tab==='plans') body=<PlansScreen onOpenPlan={p=>setStack({type:'plan',payload:p})} onNewPlan={()=>setSheet('plan')}/>;
  else body=<YouScreen/>;

  const rootTab=!stack;
  return (
    <Phone>
      {body}
      {rootTab&&tab!=='you'?<Fab onClick={()=>setSheet(tab==='groups'?'group':'plan')}/>:null}
      {rootTab?<TabBar tabs={TABS} value={tab} onChange={v=>{setStack(null);setTab(v);}}/>:null}
      <NewPlanSheet open={sheet==='plan'} onClose={()=>setSheet(null)} onFound={(name,groupName)=>{setTab('plans');setToast(name+' sent to '+groupName+' — 4 have voted already');}}/>
      <NewGroupSheet open={sheet==='group'} onClose={()=>setSheet(null)}/>
      {toast?<div style={{position:'absolute',left:16,right:16,bottom:'calc(var(--tabbar-h) + var(--safe-bottom) + 12px)',zIndex:70}}>
        <Toast tone="free" icon="circle-check">{toast}</Toast></div>:null}
    </Phone>
  );
}

Object.assign(window,{App});
