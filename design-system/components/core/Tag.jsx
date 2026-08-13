import React from 'react';
import {Icon} from './Icon.jsx';

export function Tag({hue='var(--hue-coral)',soft,selected,icon,onClick,onRemove,children,style,...rest}){
  return (
    <span onClick={onClick} {...rest} style={{display:'inline-flex',alignItems:'center',gap:6,minHeight:32,
      padding:onRemove?'0 6px 0 12px':'0 12px',borderRadius:'var(--r-chip)',cursor:onClick?'pointer':'default',
      background:selected?hue:soft||'var(--bg-sunk)',color:selected?'var(--white)':'var(--text-body)',
      font:'var(--type-subhead)',fontWeight:'var(--fw-semibold)',
      boxShadow:selected?'none':'inset 0 0 0 1px var(--line-hairline)',
      transition:'var(--transition-control)',...style}}>
      {icon?<Icon name={icon} size={14} color={selected?'var(--white)':hue}/>:<span style={{width:8,height:8,borderRadius:'var(--r-pill)',background:selected?'var(--white)':hue}}/>}
      {children}
      {onRemove?<Icon name="x" size={14} onClick={onRemove} style={{cursor:'pointer',opacity:.6,marginLeft:2}}/>:null}
    </span>
  );
}
