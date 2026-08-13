import React from 'react';
import {Icon} from '../core/Icon.jsx';

export function Toast({tone='neutral',icon,children,action,onAction,style,...rest}){
  const fg=tone==='free'?'var(--teal-700)':tone==='danger'?'var(--status-danger)':'var(--text-strong)';
  const bg=tone==='free'?'var(--teal-50)':tone==='danger'?'var(--red-50)':'var(--bg-surface)';
  return (
    <div {...rest} style={{display:'flex',alignItems:'center',gap:10,padding:'12px 14px',background:bg,
      borderRadius:'var(--r-card)',boxShadow:'var(--shadow-3)',color:fg,font:'var(--type-subhead)',
      animation:'plannit-toast var(--dur-base) var(--ease-pop)',...style}}>
      {icon?<Icon name={icon} size={18}/>:null}
      <span style={{flex:1}}>{children}</span>
      {action?<button type="button" onClick={onAction} style={{border:'none',background:'transparent',
        color:'var(--text-link)',font:'var(--type-subhead)',fontWeight:'var(--fw-bold)',cursor:'pointer'}}>{action}</button>:null}
    </div>
  );
}
