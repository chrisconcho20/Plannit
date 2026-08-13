import React from 'react';
import {Icon} from '../core/Icon.jsx';

export function ListRow({icon,iconTint,leading,title,subtitle,value,right,chevron,onClick,danger,last,style,...rest}){
  const [press,setPress]=React.useState(false);
  return (
    <div onClick={onClick} {...rest}
      onPointerDown={()=>onClick&&setPress(true)} onPointerUp={()=>setPress(false)} onPointerLeave={()=>setPress(false)}
      style={{display:'flex',alignItems:'center',gap:12,minHeight:'var(--tap-min)',padding:'10px 16px',
        background:press?'var(--bg-sunk)':'transparent',cursor:onClick?'pointer':'default',
        boxShadow:last?'none':'inset 0 -1px 0 var(--line-hairline)',
        transition:'background-color var(--dur-instant) linear',...style}}>
      {leading}
      {icon?<span style={{display:'flex',alignItems:'center',justifyContent:'center',flex:'none',width:32,height:32,
        borderRadius:'var(--r-sm)',background:iconTint||'var(--bg-sunk)'}}>
        <Icon name={icon} size={18} color={iconTint?'var(--white)':'var(--text-muted)'}/></span>:null}
      <div style={{flex:1,minWidth:0}}>
        <div style={{font:'var(--type-body)',color:danger?'var(--status-danger)':'var(--text-strong)',
          whiteSpace:'nowrap',overflow:'hidden',textOverflow:'ellipsis'}}>{title}</div>
        {subtitle?<div style={{font:'var(--type-footnote)',color:'var(--text-muted)',marginTop:1}}>{subtitle}</div>:null}
      </div>
      {value?<span style={{font:'var(--type-subhead)',color:'var(--text-muted)'}}>{value}</span>:null}
      {right}
      {chevron?<Icon name="chevron-right" size={18} color="var(--text-faint)"/>:null}
    </div>
  );
}
