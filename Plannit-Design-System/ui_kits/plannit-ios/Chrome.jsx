const {IconButton}=window.PlannitDesignSystem_ede968;

function StatusBar({dark}){
  const c=dark?'var(--white)':'var(--text-strong)';
  return (
    <div style={{display:'flex',alignItems:'flex-end',justifyContent:'space-between',height:'var(--safe-top)',
      padding:'0 28px 6px',color:c,font:'var(--fw-semibold) 14px/1 var(--font-core)',flex:'none'}}>
      <span>9:41</span>
      <span style={{display:'flex',alignItems:'center',gap:5}}>
        <span style={{display:'flex',alignItems:'flex-end',gap:1.5}}>
          {[4,6,8,10].map(h=><span key={h} style={{width:3,height:h,borderRadius:1,background:c}}/>)}
        </span>
        <span style={{width:22,height:11,borderRadius:3,boxShadow:'inset 0 0 0 1.2px '+c,padding:1.5,display:'flex'}}>
          <span style={{flex:1,borderRadius:1.5,background:c}}/>
        </span>
      </span>
    </div>
  );
}

function Phone({children,dark}){
  return (
    <div style={{position:'relative',width:390,height:844,flex:'none',borderRadius:44,overflow:'hidden',
      background:dark?'var(--ink-900)':'var(--bg-app)',boxShadow:'var(--shadow-3),0 0 0 10px #17140F,0 0 0 12px #2C2721',
      display:'flex',flexDirection:'column'}}>
      <StatusBar dark={dark}/>
      {children}
      <div style={{position:'absolute',left:'50%',bottom:8,transform:'translateX(-50%)',width:134,height:5,
        borderRadius:'var(--r-pill)',background:dark?'rgba(255,255,255,.5)':'var(--ink-300)'}}/>
    </div>
  );
}

function Screen({children,style}){
  return <div style={{flex:1,minHeight:0,display:'flex',flexDirection:'column',...style}}>{children}</div>;
}

function Scroll({children,style}){
  return <div style={{flex:1,minHeight:0,overflowY:'auto',...style}}>{children}</div>;
}

function SectionLabel({children,right}){
  return (
    <div style={{display:'flex',alignItems:'baseline',gap:8,padding:'18px 20px 8px'}}>
      <span style={{flex:1,font:'var(--type-caption)',letterSpacing:'var(--track-caps)',textTransform:'uppercase',color:'var(--text-faint)'}}>{children}</span>
      {right}
    </div>
  );
}

function Fab({onClick}){
  return (
    <div style={{position:'absolute',right:20,bottom:'calc(var(--tabbar-h) + var(--safe-bottom) + 16px)',zIndex:30}}>
      <IconButton name="plus" variant="primary" size={58} iconSize={26} label="New plan" onClick={onClick}/>
    </div>
  );
}

Object.assign(window,{StatusBar,Phone,Screen,Scroll,SectionLabel,Fab});
