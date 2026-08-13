import React from 'react';
import {Icon} from './Icon.jsx';

const SIZES={
  sm:{h:36,px:14,font:'var(--type-subhead)',icon:16,gap:6},
  md:{h:46,px:18,font:'var(--type-headline)',icon:18,gap:8},
  lg:{h:54,px:22,font:'var(--fw-bold) var(--text-body-size)/1 var(--font-display)',icon:20,gap:10}
};

export function Button({variant='primary',size='md',icon,iconAfter,fullWidth,disabled,loading,children,onClick,style,...rest}){
  const [press,setPress]=React.useState(false);
  const s=SIZES[size]||SIZES.md;
  const skin={
    primary:{background:press?'var(--action-primary-press)':'var(--action-primary)',color:'var(--text-on-primary)',boxShadow:press?'none':'var(--shadow-primary)'},
    secondary:{background:press?'var(--action-secondary-press)':'var(--action-secondary)',color:'var(--text-strong)'},
    outline:{background:press?'var(--bg-sunk)':'transparent',color:'var(--text-strong)',boxShadow:'inset 0 0 0 1.5px var(--line-strong)'},
    ghost:{background:press?'var(--bg-sunk)':'transparent',color:'var(--text-link)'},
    free:{background:press?'var(--teal-600)':'var(--status-free)',color:'var(--white)'},
    danger:{background:'transparent',color:'var(--status-danger)'}
  }[variant]||{};
  return (
    <button type="button" disabled={disabled||loading} onClick={onClick}
      onPointerDown={()=>setPress(true)} onPointerUp={()=>setPress(false)} onPointerLeave={()=>setPress(false)}
      style={{display:'inline-flex',alignItems:'center',justifyContent:'center',gap:s.gap,minHeight:s.h,
        padding:'0 '+s.px+'px',width:fullWidth?'100%':'auto',border:'none',borderRadius:'var(--r-pill)',
        font:s.font,letterSpacing:'var(--track-body)',cursor:disabled?'not-allowed':'pointer',
        opacity:disabled?.42:1,transform:press?'scale(var(--press-scale))':'none',
        transition:'var(--transition-control)',WebkitTapHighlightColor:'transparent',...skin,...style}} {...rest}>
      {loading?<Icon name="hourglass" size={s.icon}/>:icon?<Icon name={icon} size={s.icon}/>:null}
      {children}
      {iconAfter?<Icon name={iconAfter} size={s.icon}/>:null}
    </button>
  );
}
