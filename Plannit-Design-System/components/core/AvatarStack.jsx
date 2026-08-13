import React from 'react';
import {Avatar} from './Avatar.jsx';

export function AvatarStack({people=[],size=32,max=4,style,...rest}){
  const shown=people.slice(0,max), extra=people.length-shown.length;
  return (
    <span {...rest} style={{display:'inline-flex',alignItems:'center',...style}}>
      {shown.map((p,i)=>(
        <span key={i} style={{marginLeft:i?-size*0.3:0,borderRadius:'var(--r-pill)',boxShadow:'0 0 0 2px var(--bg-surface)',display:'inline-flex'}}>
          <Avatar name={p.name} src={p.src} size={size}/>
        </span>
      ))}
      {extra>0?<span style={{marginLeft:-size*0.3,display:'inline-flex',alignItems:'center',justifyContent:'center',
        width:size,height:size,borderRadius:'var(--r-pill)',background:'var(--bg-sunk)',color:'var(--text-muted)',
        font:'var(--fw-bold) '+Math.round(size*0.36)+'px/1 var(--font-core)',boxShadow:'0 0 0 2px var(--bg-surface)'}}>+{extra}</span>:null}
    </span>
  );
}
