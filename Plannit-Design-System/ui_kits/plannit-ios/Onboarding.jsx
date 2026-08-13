const {Button,ProgressDots,Icon,Card,Tag,Badge}=window.PlannitDesignSystem_ede968;

const STEPS=[
  {icon:'calendar-heart', title:'One calendar,\nthe right people.', body:'Plannit sits on top of the calendar already on your phone. Nothing moves, nothing gets rewritten.'},
  {icon:'lock', title:'Share a plan,\nnot your whole week.', body:'Every event is private until you share it. Show five-a-side to Soccer, keep the dentist to yourself.'},
  {icon:'wand-sparkles', title:'Tap the days.\nWe find the time.', body:'Pick a group, leave the days that could work switched on, and Plannit comes back with times everyone is actually free.'}
];

function Welcome({onStart,onSignIn}){
  const [i,setI]=React.useState(0);
  const s=STEPS[i];
  return (
    <Screen style={{padding:'0 28px 28px'}}>
      <div style={{display:'flex',alignItems:'center',justifyContent:'space-between',padding:'8px 0 0'}}>
        <span style={{font:'var(--fw-heavy) 22px/1 var(--font-display)',letterSpacing:'var(--track-title)',color:'var(--coral-600)'}}>Plannit</span>
        <Button variant="ghost" size="sm" onClick={onSignIn}>I have an account</Button>
      </div>
      <div style={{flex:1,display:'flex',flexDirection:'column',justifyContent:'center',gap:22}}>
        <span style={{display:'flex',alignItems:'center',justifyContent:'center',width:76,height:76,
          borderRadius:'var(--r-2xl)',background:'var(--bg-tint-primary)'}}>
          <Icon name={s.icon} size={34} color="var(--coral-500)"/>
        </span>
        <h1 style={{font:'var(--type-display)',letterSpacing:'var(--track-display)',whiteSpace:'pre-line',color:'var(--text-strong)'}}>{s.title}</h1>
        <p style={{font:'var(--type-body)',color:'var(--text-muted)',textWrap:'pretty',maxWidth:300}}>{s.body}</p>
        <div style={{display:'flex',gap:8,flexWrap:'wrap'}}>
          {i===1?<><Tag hue="var(--hue-teal)" selected>Soccer</Tag><Tag hue="var(--hue-amber)" soft="var(--hue-amber-soft)">Family</Tag><Tag hue="var(--hue-sky)" soft="var(--hue-sky-soft)">Work</Tag></>:null}
          {i===2?<Card elevation={1} pad={12} style={{width:'100%'}}>
            <div style={{display:'flex',alignItems:'center',gap:10}}>
              <Icon name="sparkles" size={18} color="var(--status-free)"/>
              <span style={{flex:1,font:'var(--type-subhead)',color:'var(--text-strong)'}}>Sat 16 Aug · 2:00 PM</span>
              <Badge tone="free" icon="check">6 of 6</Badge>
            </div>
          </Card>:null}
        </div>
      </div>
      <div style={{display:'flex',flexDirection:'column',gap:14}}>
        <ProgressDots count={3} index={i}/>
        {i<2
          ? <Button variant="primary" size="lg" fullWidth iconAfter="arrow-right" onClick={()=>setI(i+1)}>Next</Button>
          : <Button variant="primary" size="lg" fullWidth icon="apple" onClick={onStart}>Continue with Apple</Button>}
        <span style={{font:'var(--type-footnote)',color:'var(--text-faint)',textAlign:'center'}}>
          {i<2?'Takes about a minute to set up.':'We only read your calendar to work out when you’re free.'}
        </span>
      </div>
    </Screen>
  );
}

function ConnectCalendar({onDone}){
  const [state,setState]=React.useState('ask');
  return (
    <Screen style={{padding:'0 28px 28px'}}>
      <div style={{flex:1,display:'flex',flexDirection:'column',justifyContent:'center',gap:20}}>
        <span style={{display:'flex',alignItems:'center',justifyContent:'center',width:76,height:76,
          borderRadius:'var(--r-2xl)',background:state==='done'?'var(--bg-tint-free)':'var(--bg-tint-primary)'}}>
          <Icon name={state==='done'?'circle-check':'calendar-days'} size={34} color={state==='done'?'var(--status-free)':'var(--coral-500)'}/>
        </span>
        <h1 style={{font:'var(--type-title1)',letterSpacing:'var(--track-title)',color:'var(--text-strong)'}}>
          {state==='done'?'Your calendar is in.':'Add your iPhone calendar'}
        </h1>
        <p style={{font:'var(--type-body)',color:'var(--text-muted)',textWrap:'pretty'}}>
          {state==='done'
            ?'Plannit made a calendar called “Plannit” for anything you plan here. Your existing events stay exactly where they are.'
            :'Plannit reads your events so it knows when you’re busy, and writes new plans into a calendar of its own.'}
        </p>
        <Card pad={14} elevation={1}>
          <div style={{display:'flex',gap:10,alignItems:'flex-start'}}>
            <Icon name="eye-off" size={18} color="var(--text-muted)" style={{marginTop:2}}/>
            <span style={{font:'var(--type-footnote)',color:'var(--text-muted)',textWrap:'pretty'}}>
              Nobody sees your event titles. When we look for a date, your friends only see grey blocks where you’re busy.
            </span>
          </div>
        </Card>
      </div>
      <div style={{display:'flex',flexDirection:'column',gap:10}}>
        {state==='ask'
          ? <><Button variant="primary" size="lg" fullWidth onClick={()=>setState('done')}>Allow calendar access</Button>
              <Button variant="ghost" fullWidth onClick={()=>setState('done')}>Maybe later</Button></>
          : <Button variant="free" size="lg" fullWidth iconAfter="arrow-right" onClick={onDone}>Take me in</Button>}
      </div>
    </Screen>
  );
}

Object.assign(window,{Welcome,ConnectCalendar});
