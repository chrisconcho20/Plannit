const {NavBar,Card,ListRow,AvatarStack,Button,Badge,Icon,EmptyState,Input,Sheet,Tag}=window.PlannitDesignSystem_ede968;

function GroupsScreen({onOpenGroup,onNewGroup}){
  const D=window.PlannitData;
  return (
    <Screen>
      <NavBar large title="Groups" subtitle="Who sees what" actions={[{name:'user-plus',label:'Add friend'}]}/>
      <Scroll>
        <SectionLabel>Your groups</SectionLabel>
        <div style={{display:'flex',flexDirection:'column',gap:'var(--gap-list)',padding:'0 20px'}}>
          {D.groups.map(g=>(
            <Card key={g.id} pad={14} elevation={1} onClick={()=>onOpenGroup(g)}>
              <div style={{display:'flex',alignItems:'center',gap:12}}>
                <span style={{display:'flex',alignItems:'center',justifyContent:'center',width:44,height:44,flex:'none',
                  borderRadius:'var(--r-md)',background:g.hue}}>
                  <Icon name="users" size={22} color="var(--white)"/>
                </span>
                <div style={{flex:1,minWidth:0}}>
                  <div style={{font:'var(--type-headline)',color:'var(--text-strong)'}}>{g.name}</div>
                  <div style={{font:'var(--type-footnote)',color:'var(--text-muted)',marginTop:2}}>{g.note}</div>
                </div>
                <AvatarStack people={g.members} size={26} max={3}/>
                <Icon name="chevron-right" size={18} color="var(--text-faint)"/>
              </div>
            </Card>
          ))}
        </div>
        <SectionLabel>Friends not in a group yet</SectionLabel>
        <div style={{padding:'0 20px'}}>
          <Card pad={0}>
            <ListRow icon="user" title="Priya Nair" subtitle="Joined last week" right={<Button size="sm" variant="secondary" icon="plus">Add</Button>}/>
            <ListRow icon="user" title="Ben Alt" subtitle="From your contacts" right={<Button size="sm" variant="secondary" icon="plus">Add</Button>} last/>
          </Card>
        </div>
        <div style={{padding:'20px'}}>
          <Button variant="outline" size="lg" fullWidth icon="plus" onClick={onNewGroup}>Make a group</Button>
        </div>
        <div style={{height:110}}/>
      </Scroll>
    </Screen>
  );
}

function GroupDetail({group,onBack,onFindDate}){
  const g=group||window.PlannitData.groups[0];
  return (
    <Screen>
      <NavBar back title={g.name} subtitle={g.members.length+' people'} onBack={onBack} actions={[{name:'settings',label:'Group settings'}]}/>
      <Scroll>
        <div style={{padding:'16px 20px 0'}}>
          <Card pad={16} elevation={1} style={{background:g.soft,boxShadow:'none'}}>
            <div style={{display:'flex',alignItems:'center',gap:10}}>
              <Icon name="wand-sparkles" size={20} color={g.hue}/>
              <div style={{flex:1}}>
                <div style={{font:'var(--type-headline)',color:'var(--text-strong)'}}>Find a date for {g.name}</div>
                <div style={{font:'var(--type-footnote)',color:'var(--text-body)',marginTop:2}}>Tell us roughly when — we’ll do the rest.</div>
              </div>
            </div>
            <Button variant="primary" size="md" fullWidth icon="sparkles" style={{marginTop:12}} onClick={onFindDate}>Start a plan</Button>
          </Card>
        </div>
        <SectionLabel>Shared with this group</SectionLabel>
        <div style={{padding:'0 20px'}}>
          <Card pad={0}>
            <ListRow icon="dumbbell" iconTint={g.hue} title="Five-a-side" subtitle="Sat 16 Aug · 2:00 PM" chevron/>
            <ListRow icon="calendar-check" iconTint={g.hue} title="League match" subtitle="Tue 26 Aug · 7:00 PM" chevron last/>
          </Card>
        </div>
        <SectionLabel>People</SectionLabel>
        <div style={{padding:'0 20px'}}>
          <Card pad={0}>
            {g.members.map((m,i)=><MemberRow key={m.name} m={m} owner={i===0} last={i===g.members.length-1}/>)}
          </Card>
        </div>
        <div style={{padding:'20px'}}>
          <Card pad={0}>
            <ListRow icon="link" title="Invite by link" subtitle="Works without the app" chevron/>
            <ListRow icon="trash-2" title="Leave group" danger last/>
          </Card>
        </div>
        <div style={{height:40}}/>
      </Scroll>
    </Screen>
  );
}

function MemberRow({m,owner,last}){
  const {ListRow,Avatar,Badge}=window.PlannitDesignSystem_ede968;
  return <ListRow leading={<Avatar name={m.name} size={34}/>} title={m.name}
    right={owner?<Badge tone="neutral">Owner</Badge>:null} last={last}/>;
}

function NewGroupSheet({open,onClose}){
  const [name,setName]=React.useState('');
  const [hue,setHue]=React.useState('var(--hue-teal)');
  const hues=['var(--hue-coral)','var(--hue-amber)','var(--hue-teal)','var(--hue-sky)','var(--hue-indigo)','var(--hue-rose)'];
  return (
    <Sheet open={open} title="Make a group" onClose={onClose}
      footer={<Button variant="primary" size="lg" fullWidth onClick={onClose}>Create group</Button>}>
      <Input label="Group name" placeholder="Sunday runs" value={name} onChange={e=>setName(e.target.value)} icon="users" style={{marginBottom:16}}/>
      <div style={{font:'var(--type-caption)',letterSpacing:'var(--track-caps)',textTransform:'uppercase',color:'var(--text-muted)',marginBottom:8}}>Colour</div>
      <div style={{display:'flex',gap:10,marginBottom:16}}>
        {hues.map(h=>(
          <button key={h} type="button" onClick={()=>setHue(h)} style={{width:38,height:38,border:'none',cursor:'pointer',
            borderRadius:'var(--r-pill)',background:h,boxShadow:hue===h?'0 0 0 2px var(--bg-surface),0 0 0 4px '+h:'none'}}/>
        ))}
      </div>
      <div style={{font:'var(--type-caption)',letterSpacing:'var(--track-caps)',textTransform:'uppercase',color:'var(--text-muted)',marginBottom:8}}>Add people</div>
      <div style={{display:'flex',gap:8,flexWrap:'wrap'}}>
        {['Maya','Theo','Ada','Sam','Rae','Jo'].map((n,i)=><Tag key={n} hue={hue} selected={i<2}>{n}</Tag>)}
      </div>
    </Sheet>
  );
}

Object.assign(window,{GroupsScreen,GroupDetail,NewGroupSheet});
