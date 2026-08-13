import React from 'react';

export function AvailabilityBar({name,blocks=[],from=8,to=22,height=12,style,...rest}){
  const span=to-from;
  return (
    <div {...rest} style={{display:'flex',alignItems:'center',gap:10,...style}}>
      {name?<span style={{width:64,flex:'none',font:'var(--type-footnote)',color:'var(--text-muted)',
        whiteSpace:'nowrap',overflow:'hidden',textOverflow:'ellipsis'}}>{name}</span>:null}
      <span style={{position:'relative',flex:1,height,borderRadius:'var(--r-pill)',background:'var(--teal-100)',overflow:'hidden'}}>
        {blocks.map((b,i)=>(
          <span key={i} style={{position:'absolute',top:0,bottom:0,
            left:((b.start-from)/span*100)+'%',width:((b.end-b.start)/span*100)+'%',
            background:'var(--status-busy)'}}/>
        ))}
      </span>
    </div>
  );
}
