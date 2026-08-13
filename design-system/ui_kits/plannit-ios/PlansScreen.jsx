const {NavBar,Card,SlotCard,AvailabilityBar,Badge,Button,Icon,Tag,Sheet,Input,Select,Checkbox,SegmentedControl,AvatarStack,Toast,EmptyState}=window.PlannitDesignSystem_ede968;

function PlansScreen({onOpenPlan,onNewPlan}){
  const D=window.PlannitData;
  return (
    <Screen>
      <NavBar large title="Plans" subtitle="2 waiting on the group"/>
      <Scroll>
        <SectionLabel>Needs your vote</SectionLabel>
        <div style={{display:'flex',flexDirection:'column',gap:'var(--gap-list)',padding:'0 20px'}}>
          {D.proposals.map(p=>(
            <Card key={p.id} pad={14} elevation={1} onClick={()=>onOpenPlan(p)}>
              <div style={{display:'flex',alignItems:'center',gap:10}}>
                <span style={{width:8,height:8,borderRadius:'var(--r-pill)',background:p.group.hue}}/>
                <span style={{flex:1,font:'var(--type-caption)',color:'var(--text-muted)'}}>{p.group.name}</span>
                <Badge tone={p.status==='found'?'free':'warning'} icon={p.status==='found'?'check':'hourglass'}>
                  {p.status==='found'?'Date found':p.votes+' of '+p.group.members.length+' voted'}
                </Badge>
              </div>
              <div style={{font:'var(--type-title3)',color:'var(--text-strong)',marginTop:8}}>{p.title}</div>
              <div style={{display:'flex',alignItems:'center',gap:6,marginTop:4,font:'var(--type-footnote)',color:'var(--text-muted)'}}>
                <Icon name="wand-sparkles" size={13}/><span>{p.constraint}</span>
              </div>
              <div style={{display:'flex',alignItems:'center',gap:10,marginTop:12}}>
                <AvatarStack people={p.group.members} size={26} max={4}/>
                <span style={{flex:1}}/>
                <span style={{font:'var(--type-subhead)',fontWeight:'var(--fw-semibold)',color:'var(--text-link)'}}>
                  {p.status==='found'?'See the date':'Pick a time'}
                </span>
                <Icon name="chevron-right" size={16} color="var(--text-faint)"/>
              </div>
            </Card>
          ))}
        </div>
        <SectionLabel>Past</SectionLabel>
        <div style={{padding:'0 20px'}}>
          <Card pad={14} elevation={0}>
            <div style={{display:'flex',alignItems:'center',gap:10}}>
              <Icon name="circle-check" size={18} color="var(--status-free)"/>
              <span style={{flex:1,font:'var(--type-subhead)',color:'var(--text-body)'}}>Board games night · locked for Fri 8 Aug</span>
            </div>
          </Card>
        </div>
        <div style={{padding:'20px'}}>
          <Button variant="outline" size="lg" fullWidth icon="wand-sparkles" onClick={onNewPlan}>Find a date</Button>
        </div>
        <div style={{height:110}}/>
      </Scroll>
    </Screen>
  );
}

function PlanDetail({plan,onBack}){
  const p=plan||window.PlannitData.proposals[0];
  const [vote,setVote]=React.useState(0);
  const [locked,setLocked]=React.useState(false);
  const [tab,setTab]=React.useState('Slots');
  return (
    <Screen>
      <NavBar back title={p.title} subtitle={p.group.name+' · '+p.group.members.length+' people'} onBack={onBack} actions={[{name:'ellipsis',label:'More'}]}/>
      <Scroll>
        <div style={{padding:'14px 20px 0'}}>
          <Card pad={14} elevation={0} style={{background:'var(--bg-tint-primary)',boxShadow:'none'}}>
            <div style={{display:'flex',gap:10,alignItems:'flex-start'}}>
              <Icon name="wand-sparkles" size={18} color="var(--coral-600)" style={{marginTop:2}}/>
              <div>
                <div style={{font:'var(--type-subhead)',fontWeight:'var(--fw-semibold)',color:'var(--coral-700)'}}>You asked for {p.constraint}</div>
                <div style={{font:'var(--type-footnote)',color:'var(--coral-700)',opacity:.85,marginTop:2}}>Three times work. Pick the one you like.</div>
              </div>
            </div>
          </Card>
        </div>
        <div style={{padding:'14px 20px 0'}}>
          <SegmentedControl options={['Slots','Who’s free']} value={tab} onChange={setTab}/>
        </div>
        {tab==='Slots'?<>
          <SectionLabel>Best times found</SectionLabel>
          <div style={{display:'flex',flexDirection:'column',gap:'var(--gap-list)',padding:'0 20px'}}>
            {p.slots.map((s,i)=>(
              <SlotCard key={i} day={s.day} date={s.date} time={s.time} freeCount={s.free} total={p.group.members.length}
                best={s.best} selected={vote===i} people={p.group.members.slice(0,s.free)} onClick={()=>setVote(i)}/>
            ))}
          </div>
        </>:<>
          <SectionLabel right={<span style={{font:'var(--type-caption)',color:'var(--text-faint)'}}>Sat 16 · 8am–10pm</span>}>Busy blocks only</SectionLabel>
          <div style={{padding:'0 20px'}}>
            <Card pad={14}>
              {p.availability.map(a=><AvailabilityBar key={a.name} name={a.name} blocks={a.blocks} style={{marginBottom:10}}/>)}
              <div style={{display:'flex',gap:14,marginTop:4,font:'var(--type-caption)',color:'var(--text-muted)'}}>
                <span style={{display:'inline-flex',alignItems:'center',gap:6}}><span style={{width:12,height:8,borderRadius:4,background:'var(--teal-100)'}}/>Free</span>
                <span style={{display:'inline-flex',alignItems:'center',gap:6}}><span style={{width:12,height:8,borderRadius:4,background:'var(--status-busy)'}}/>Busy — titles never shared</span>
              </div>
            </Card>
          </div>
        </>}
        <div style={{padding:'20px'}}>
          <Button variant="free" size="lg" fullWidth icon="check" onClick={()=>setLocked(true)}>
            Lock in {p.slots[vote].day.charAt(0)+p.slots[vote].day.slice(1).toLowerCase()} {p.slots[vote].date}
          </Button>
          <Button variant="ghost" fullWidth style={{marginTop:6}}>None of these work</Button>
        </div>
        <div style={{height:20}}/>
      </Scroll>
      {locked?<div style={{position:'absolute',left:16,right:16,bottom:24,zIndex:50}}>
        <Toast tone="free" icon="circle-check" action="Undo" onAction={()=>setLocked(false)}>
          On everyone’s calendar. We’ll nudge them.
        </Toast>
      </div>:null}
    </Screen>
  );
}

function NewPlanSheet({open,onClose,onFound}){
  const D=window.PlannitData;
  const SHORT=['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
  const {DayOfWeekPicker,ListRow}=window.PlannitDesignSystem_ede968;
  const [step,setStep]=React.useState('ask');
  const [group,setGroup]=React.useState('soccer');
  const [newGroup,setNewGroup]=React.useState('');
  const [days,setDays]=React.useState([0,1,2,3,4,5,6]);
  const [times,setTimes]=React.useState(['Afternoon']);
  const [more,setMore]=React.useState(false);
  const [quorum,setQuorum]=React.useState(true);
  const [name,setName]=React.useState('');
  React.useEffect(()=>{ if(step==='finding'){ const t=setTimeout(()=>setStep('found'),1400); return ()=>clearTimeout(t);} },[step]);
  React.useEffect(()=>{ if(!open){ setStep('ask'); setName(''); } },[open]);
  const g=D.groups.find(x=>x.id===group);
  const groupName=group==='new'?(newGroup||'your new group'):g.name;
  const dayText=days.length===7?'Any day':days.map(d=>SHORT[d]).join(', ');
  const timeText=times.length?times.join(' or ').toLowerCase():'any time';
  const toggleTime=t=>setTimes(s=>s.includes(t)?s.filter(x=>x!==t):[...s,t]);
  return (
    <Sheet open={open} onClose={onClose}
      title={step==='found'?'Three times work':step==='finding'?'Checking calendars':'Find a date'}
      footer={step==='ask'
        ? <Button variant="primary" size="lg" fullWidth icon="wand-sparkles" disabled={!days.length} onClick={()=>setStep('finding')}>Find a date</Button>
        : step==='finding'
          ? <Button variant="primary" size="lg" fullWidth loading disabled>Checking {group==='new'?'their':g.members.length+' '}calendars…</Button>
          : <Button variant="free" size="lg" fullWidth icon="send" onClick={()=>{onClose();onFound&&onFound(name||'Your plan',groupName);}}>Send to {groupName} to vote</Button>}>
      {step==='ask'?<>
        <div style={{font:'var(--type-caption)',letterSpacing:'var(--track-caps)',textTransform:'uppercase',color:'var(--text-muted)',marginBottom:8}}>Who’s it with?</div>
        <div style={{display:'flex',gap:8,flexWrap:'wrap',marginBottom:group==='new'?12:18}}>
          {D.groups.map(x=><Tag key={x.id} hue={x.hue} soft={x.soft} selected={group===x.id} onClick={()=>setGroup(x.id)}>{x.name}</Tag>)}
          <Tag hue="var(--text-muted)" icon="plus" selected={group==='new'} onClick={()=>setGroup('new')}>New group</Tag>
        </div>
        {group==='new'?<div style={{marginBottom:18}}>
          <Input label="Group name" placeholder="Sunday runs" icon="users" value={newGroup} onChange={e=>setNewGroup(e.target.value)} style={{marginBottom:10}}/>
          <div style={{display:'flex',gap:8,flexWrap:'wrap'}}>
            {['Maya','Theo','Ada','Sam','Rae','Jo'].map((n,i)=><Tag key={n} hue="var(--action-primary)" selected={i<2}>{n}</Tag>)}
          </div>
        </div>:null}
        <div style={{font:'var(--type-caption)',letterSpacing:'var(--track-caps)',textTransform:'uppercase',color:'var(--text-muted)',marginBottom:8}}>Which days work?</div>
        <DayOfWeekPicker value={days} onChange={setDays}/>
        <div style={{font:'var(--type-footnote)',color:'var(--text-muted)',margin:'8px 0 16px'}}>
          {days.length?dayText+' · '+timeText+' · next 3 weeks':'Tap at least one day.'}
        </div>
        <Card pad={0}>
          <ListRow icon={more?'chevron-down':'chevron-right'} title="More details"
            subtitle={more?null:'Time of day, how long, who has to make it'} onClick={()=>setMore(!more)} last/>
          {more?<div style={{padding:'0 16px 16px'}}>
            <div style={{font:'var(--type-caption)',letterSpacing:'var(--track-caps)',textTransform:'uppercase',color:'var(--text-muted)',marginBottom:8}}>Time of day</div>
            <div style={{display:'flex',gap:8,flexWrap:'wrap',marginBottom:14}}>
              {['Morning','Afternoon','Evening'].map(t=>
                <Tag key={t} hue="var(--action-primary)" selected={times.includes(t)} onClick={()=>toggleTime(t)}>{t}</Tag>)}
            </div>
            <Select label="How long?" options={['1 hour','2 hours','Half a day','All day']} style={{marginBottom:12}}/>
            <Select label="Look how far ahead?" options={['Next 3 weeks','Next month','Next 3 months']} style={{marginBottom:12}}/>
            <Checkbox checked={quorum} onChange={()=>setQuorum(!quorum)} label="It’s fine if one person can’t make it" sublabel="We’ll accept 5 of 6 free"/>
          </div>:null}
        </Card>
      </>:step==='finding'?<div style={{padding:'20px 0'}}>
        {D.proposals[0].availability.map((a,i)=>(
          <AvailabilityBar key={a.name} name={a.name} blocks={a.blocks} style={{marginBottom:10,opacity:0,animation:'plannit-fade var(--dur-base) var(--ease-out) '+(i*140)+'ms forwards'}}/>
        ))}
        <div style={{textAlign:'center',font:'var(--type-footnote)',color:'var(--text-muted)',marginTop:10}}>Looking at busy blocks, not your events.</div>
      </div>:<>
        <Input label="Name this plan" placeholder="Five-a-side" icon="pencil" value={name} onChange={e=>setName(e.target.value)} style={{marginBottom:16}}/>
        <div style={{font:'var(--type-footnote)',color:'var(--text-muted)',marginBottom:12}}>
          {dayText} · {timeText}. Sorted by how many of you are free — send them all and let {groupName} vote.
        </div>
        <div style={{display:'flex',flexDirection:'column',gap:10}}>
          {D.proposals[0].slots.map((s,i)=>(
            <SlotCard key={i} day={s.day} date={s.date} time={s.time} freeCount={s.free} total={6} best={s.best}
              people={(group==='new'?D.groups[0]:g).members.slice(0,s.free)}/>
          ))}
        </div>
      </>}
    </Sheet>
  );
}

function YouScreen(){
  const {ListRow,Avatar,Switch,Card,Button,Badge}=window.PlannitDesignSystem_ede968;
  const [sync,setSync]=React.useState(true);
  const [push,setPush]=React.useState(true);
  const [quiet,setQuiet]=React.useState(false);
  return (
    <Screen>
      <NavBar large title="You"/>
      <Scroll>
        <div style={{display:'flex',alignItems:'center',gap:14,padding:'6px 20px 18px'}}>
          <Avatar name="Chris Concho" size={64}/>
          <div style={{flex:1}}>
            <div style={{font:'var(--type-title3)',color:'var(--text-strong)'}}>Chris Concho</div>
            <div style={{font:'var(--type-footnote)',color:'var(--text-muted)',marginTop:2}}>Signed in with Apple · London</div>
          </div>
          <Button size="sm" variant="secondary" icon="pencil">Edit</Button>
        </div>
        <SectionLabel>Calendar</SectionLabel>
        <div style={{padding:'0 20px'}}>
          <Card pad={0}>
            <ListRow icon="repeat" title="Two-way sync" subtitle="Synced a moment ago" right={<Switch checked={sync} onChange={setSync}/>}/>
            <ListRow icon="calendar-days" title="Plannit calendar" value="On your iPhone" chevron/>
            <ListRow icon="eye-off" title="Availability sharing" subtitle="Busy blocks only, no titles" right={<Badge tone="free">On</Badge>} chevron last/>
          </Card>
        </div>
        <SectionLabel>Notifications</SectionLabel>
        <div style={{padding:'0 20px'}}>
          <Card pad={0}>
            <ListRow icon="bell" title="New plans and votes" right={<Switch checked={push} onChange={setPush}/>}/>
            <ListRow icon="moon" title="Quiet hours" subtitle="10pm – 8am" right={<Switch checked={quiet} onChange={setQuiet}/>} last/>
          </Card>
        </div>
        <SectionLabel>Plannit</SectionLabel>
        <div style={{padding:'0 20px'}}>
          <Card pad={0}>
            <ListRow icon="link" title="Invite a friend" subtitle="No referral wall, ever" chevron/>
            <ListRow icon="lock" title="Privacy" chevron/>
            <ListRow icon="info" title="About" value="1.0 (beta)" last/>
          </Card>
        </div>
        <div style={{height:120}}/>
      </Scroll>
    </Screen>
  );
}

Object.assign(window,{PlansScreen,PlanDetail,NewPlanSheet,YouScreen});
