import React from 'react';
import {Icon} from '../core/Icon.jsx';

export function TabBar({tabs=[],value,onChange,safeArea=true,style,...rest}){
  return (
    <div {...rest} style={{display:'flex',alignItems:'stretch',background:'var(--bg-chrome)',
      backdropFilter:'var(--blur-chrome)',WebkitBackdropFilter:'var(--blur-chrome)',
      borderTop:'1px solid var(--line-hairline)',paddingBottom:safeArea?'var(--safe-bottom)':0,...style}}>
      {tabs.map(t=>{const on=t.value===value;return (
        <button key={t.value} type="button" onClick={()=>onChange&&onChange(t.value)}
          style={{flex:1,display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',gap:3,
            minHeight:'var(--tabbar-h)',border:'none',background:'transparent',cursor:'pointer',
            color:on?'var(--action-primary)':'var(--text-faint)',WebkitTapHighlightColor:'transparent'}}>
          <span style={{position:'relative'}}>
            <Icon name={t.icon} size={24}/>
            {t.badge?<span style={{position:'absolute',top:-2,right:-6,minWidth:16,height:16,padding:'0 4px',
              borderRadius:'var(--r-pill)',background:'var(--action-primary)',color:'var(--white)',
              font:'var(--fw-bold) 10px/16px var(--font-core)',textAlign:'center'}}>{t.badge}</span>:null}
          </span>
          <span style={{font:'var(--fw-semibold) 10px/1 var(--font-core)',letterSpacing:'.01em'}}>{t.label}</span>
        </button>
      );})}
    </div>
  );
}
