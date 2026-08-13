import React from 'react';
import {Icon} from '../core/Icon.jsx';

export function EmptyState({icon='calendar-days',title,body,action,style,...rest}){
  return (
    <div {...rest} style={{display:'flex',flexDirection:'column',alignItems:'center',textAlign:'center',
      gap:8,padding:'40px 28px',...style}}>
      <span style={{display:'flex',alignItems:'center',justifyContent:'center',width:64,height:64,marginBottom:4,
        borderRadius:'var(--r-xl)',background:'var(--bg-tint-primary)'}}>
        <Icon name={icon} size={28} color="var(--coral-500)"/>
      </span>
      <div style={{font:'var(--type-title3)',color:'var(--text-strong)'}}>{title}</div>
      {body?<p style={{font:'var(--type-subhead)',color:'var(--text-muted)',maxWidth:300,textWrap:'pretty'}}>{body}</p>:null}
      {action?<div style={{marginTop:8}}>{action}</div>:null}
    </div>
  );
}
