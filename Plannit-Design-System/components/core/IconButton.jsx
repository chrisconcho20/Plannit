import React from 'react';
import {Icon} from './Icon.jsx';

export function IconButton({name,size=44,iconSize,variant='plain',label,disabled,onClick,style,...rest}){
  const [press,setPress]=React.useState(false);
  const skin={
    plain:{background:'transparent',color:'var(--text-strong)'},
    filled:{background:press?'var(--action-secondary-press)':'var(--action-secondary)',color:'var(--text-strong)'},
    primary:{background:press?'var(--action-primary-press)':'var(--action-primary)',color:'var(--white)',boxShadow:press?'none':'var(--shadow-primary)'},
    chrome:{background:'var(--bg-chrome)',backdropFilter:'var(--blur-chrome)',color:'var(--text-strong)',boxShadow:'var(--ring-inset)'}
  }[variant]||{};
  return (
    <button type="button" aria-label={label} disabled={disabled} onClick={onClick}
      onPointerDown={()=>setPress(true)} onPointerUp={()=>setPress(false)} onPointerLeave={()=>setPress(false)}
      style={{display:'inline-flex',alignItems:'center',justifyContent:'center',width:size,height:size,flex:'none',
        border:'none',borderRadius:'var(--r-pill)',cursor:'pointer',opacity:disabled?.4:1,
        transform:press?'scale(var(--press-scale))':'none',transition:'var(--transition-control)',
        WebkitTapHighlightColor:'transparent',...skin,...style}} {...rest}>
      <Icon name={name} size={iconSize||Math.round(size*0.48)}/>
    </button>
  );
}
