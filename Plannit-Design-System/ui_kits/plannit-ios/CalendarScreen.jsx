const {NavBar,SegmentedControl,MonthGrid,EventCard,Card,EmptyState,Button,Icon,Badge}=window.PlannitDesignSystem_ede968;

const MONTH=['January','February','March','April','May','June','July','August','September','October','November','December'];

function CalendarScreen({onOpenEvent,onNewPlan}){
  const D=window.PlannitData;
  const [view,setView]=React.useState('Month');
  const [day,setDay]=React.useState(16);
  const dayEvents=D.events.filter(e=>e.day===day);
  const listEvents=view==='List'?D.events:dayEvents;
  const heading=view==='List'?'Everything coming up':'Sat '+day+' August';
  return (
    <Screen>
      <NavBar large title="August" subtitle="4 plans this week"
        actions={[{name:'search',label:'Search'},{name:'bell',label:'Notifications'}]}/>
      <Scroll>
        <div style={{padding:'4px 20px 0'}}>
          <SegmentedControl options={['Month','Week','List']} value={view} onChange={setView}/>
        </div>
        {view!=='List'?<div style={{padding:'14px 20px 0'}}>
          <Card pad={12} elevation={1}><MonthGrid year={2026} month={7} selected={day} marks={D.marks} onSelect={setDay}/></Card>
        </div>:null}
        <SectionLabel right={<span style={{font:'var(--type-caption)',color:'var(--text-faint)'}}>{listEvents.length} {listEvents.length===1?'plan':'plans'}</span>}>{heading}</SectionLabel>
        <div style={{display:'flex',flexDirection:'column',gap:'var(--gap-list)',padding:'0 20px'}}>
          {listEvents.length?listEvents.map(e=>(
            <EventCard key={e.id} {...e} time={(view==='List'?'Aug '+e.day+' · ':'')+e.time} onClick={()=>onOpenEvent(e)}/>
          )):<Card pad={0}><EmptyState icon="calendar-plus" title="Nothing on this day"
              body="Free all day. Want to see if the others are too?"
              action={<Button variant="primary" icon="wand-sparkles" onClick={onNewPlan}>Find a date</Button>}/></Card>}
        </div>
        <div style={{padding:'20px 20px 0'}}>
          <Card pad={14} elevation={0} style={{background:'var(--bg-tint-free)',boxShadow:'none'}}>
            <div style={{display:'flex',alignItems:'center',gap:10}}>
              <Icon name="repeat" size={18} color="var(--teal-700)"/>
              <span style={{flex:1,font:'var(--type-footnote)',color:'var(--teal-700)'}}>Synced with your iPhone calendar a moment ago</span>
            </div>
          </Card>
        </div>
        <div style={{height:120}}/>
      </Scroll>
    </Screen>
  );
}

function EventDetail({event,onBack}){
  const e=event||{};
  const [sheet,setSheet]=React.useState(false);
  return (
    <Screen>
      <NavBar back title={e.title} subtitle={e.group?e.group+' · '+(e.people?e.people.length:1)+' going':'Only you'} onBack={onBack}
        actions={[{name:'pencil',label:'Edit'},{name:'ellipsis',label:'More'}]}/>
      <Scroll>
        <div style={{padding:'16px 20px 0'}}>
          <div style={{borderRadius:'var(--r-xl)',background:e.hue||'var(--hue-coral)',padding:'22px 20px',color:'var(--white)'}}>
            <Icon name={e.icon||'calendar'} size={28} color="rgba(255,255,255,.9)"/>
            <div style={{font:'var(--type-title1)',letterSpacing:'var(--track-title)',marginTop:12}}>{e.title}</div>
            <div style={{font:'var(--type-subhead)',opacity:.9,marginTop:4}}>Sat 16 August · {e.time}</div>
          </div>
        </div>
        <div style={{padding:'16px 20px 0'}}>
          <Card pad={0}>
            <ListRowLike icon="clock" title="Saturday 16 August" value={e.time}/>
            {e.location?<ListRowLike icon="map-pin" title={e.location} value="Map"/>:null}
            <ListRowLike icon="lock" title="Visible to" value={e.group?e.group:'Only you'} last/>
          </Card>
        </div>
        {e.people?<>
          <SectionLabel>Going</SectionLabel>
          <div style={{padding:'0 20px'}}>
            <Card pad={0}>
              {e.people.map((p,i)=><PersonRow key={p.name} person={p} status={i%3===2?'busy':'free'} last={i===e.people.length-1}/>)}
            </Card>
          </div></>:null}
        <div style={{display:'flex',gap:10,padding:'20px'}}>
          <Button variant="secondary" icon="message-circle" fullWidth>Message</Button>
          <Button variant="primary" icon="share-2" fullWidth onClick={()=>setSheet(true)}>Share</Button>
        </div>
        <div style={{padding:'0 20px 40px'}}>
          <Button variant="danger" fullWidth>Remove from my calendar</Button>
        </div>
      </Scroll>
      <ShareSheet open={sheet} onClose={()=>setSheet(false)} event={e}/>
    </Screen>
  );
}

function ListRowLike({icon,title,value,last}){
  const {ListRow}=window.PlannitDesignSystem_ede968;
  return <ListRow icon={icon} title={title} value={value} last={last}/>;
}

function PersonRow({person,status,last}){
  const {ListRow,Avatar,Badge}=window.PlannitDesignSystem_ede968;
  return <ListRow leading={<Avatar name={person.name} size={34} status={status}/>} title={person.name}
    right={<Badge tone={status==='free'?'free':'neutral'}>{status==='free'?'Free':'Busy'}</Badge>} last={last}/>;
}

function ShareSheet({open,onClose,event}){
  const {Sheet,Checkbox,Button,Icon}=window.PlannitDesignSystem_ede968;
  const D=window.PlannitData;
  const [sel,setSel]=React.useState(['soccer']);
  const toggle=id=>setSel(s=>s.includes(id)?s.filter(x=>x!==id):[...s,id]);
  return (
    <Sheet open={open} title="Who can see this?" onClose={onClose}
      footer={<Button variant="primary" size="lg" fullWidth onClick={onClose}>Share with {sel.length} {sel.length===1?'group':'groups'}</Button>}>
      <p style={{font:'var(--type-footnote)',color:'var(--text-muted)',marginBottom:12}}>
        Everyone else keeps seeing a plain busy block — no title, no place.
      </p>
      {D.groups.map(g=>(
        <div key={g.id} style={{display:'flex',alignItems:'center',gap:12}}>
          <Checkbox checked={sel.includes(g.id)} onChange={()=>toggle(g.id)} label={g.name} sublabel={g.members.length+' people'} style={{flex:1}}/>
          <span style={{width:10,height:10,borderRadius:'var(--r-pill)',background:g.hue}}/>
        </div>
      ))}
      <div style={{display:'flex',gap:8,alignItems:'center',marginTop:8,padding:'12px 0',borderTop:'1px solid var(--line-hairline)'}}>
        <Icon name="link" size={16} color="var(--text-muted)"/>
        <span style={{flex:1,font:'var(--type-footnote)',color:'var(--text-muted)'}}>Or send a link — friends can reply without the app.</span>
      </div>
    </Sheet>
  );
}

Object.assign(window,{CalendarScreen,EventDetail,ShareSheet});
