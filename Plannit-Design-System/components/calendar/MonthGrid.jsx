import React from 'react';

const DOW=['M','T','W','T','F','S','S'];

export function MonthGrid({year=2026,month=7,selected=16,marks={},onSelect,style,...rest}){
  const first=new Date(year,month,1);
  const lead=(first.getDay()+6)%7;
  const days=new Date(year,month+1,0).getDate();
  const cells=[...Array(lead).fill(null),...Array.from({length:days},(_,i)=>i+1)];
  return (
    <div {...rest} style={{...style}}>
      <div style={{display:'grid',gridTemplateColumns:'repeat(7,1fr)',gap:2,marginBottom:6}}>
        {DOW.map((d,i)=><div key={i} style={{textAlign:'center',font:'var(--type-caption)',
          color:'var(--text-faint)',letterSpacing:'var(--track-caps)'}}>{d}</div>)}
      </div>
      <div style={{display:'grid',gridTemplateColumns:'repeat(7,1fr)',gap:2}}>
        {cells.map((d,i)=>{
          if(!d) return <span key={i}/>;
          const on=d===selected, hues=marks[d]||[];
          return (
            <button key={i} type="button" onClick={()=>onSelect&&onSelect(d)}
              style={{display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',gap:3,
                aspectRatio:'1 / 1.05',border:'none',borderRadius:'var(--r-md)',cursor:'pointer',
                background:on?'var(--action-primary)':'transparent',
                color:on?'var(--white)':'var(--text-body)',
                font:'var(--fw-semibold) var(--text-subhead)/1 var(--font-core)',
                fontVariantNumeric:'tabular-nums',transition:'var(--transition-control)'}}>
              {d}
              <span style={{display:'flex',gap:2,height:5}}>
                {hues.slice(0,3).map((h,j)=><span key={j} style={{width:5,height:5,borderRadius:'var(--r-pill)',
                  background:on?'rgba(255,255,255,.9)':h}}/>)}
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
}
