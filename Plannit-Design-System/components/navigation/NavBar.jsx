import React from 'react';
import {IconButton} from '../core/IconButton.jsx';

export function NavBar({title,subtitle,large,back,onBack,actions=[],style,...rest}){
  return (
    <div {...rest} style={{position:'sticky',top:0,zIndex:20,background:'var(--bg-chrome)',
      backdropFilter:'var(--blur-chrome)',WebkitBackdropFilter:'var(--blur-chrome)',
      borderBottom:'1px solid var(--line-hairline)',padding:'0 8px',...style}}>
      <div style={{display:'flex',alignItems:'center',gap:4,minHeight:'var(--nav-h)'}}>
        {back?<IconButton name="chevron-left" label="Back" onClick={onBack} size={40}/>:<span style={{width:8}}/>}
        <div style={{flex:1,minWidth:0,textAlign:large?'left':'center',paddingLeft:large?8:0}}>
          {!large?<><div style={{font:'var(--type-headline)',color:'var(--text-strong)',whiteSpace:'nowrap',overflow:'hidden',textOverflow:'ellipsis'}}>{title}</div>
            {subtitle?<div style={{font:'var(--type-caption)',color:'var(--text-muted)'}}>{subtitle}</div>:null}</>:null}
        </div>
        <div style={{display:'flex',alignItems:'center',gap:2}}>
          {actions.map((a,i)=><IconButton key={i} size={40} {...a}/>)}
          {!actions.length?<span style={{width:8}}/>:null}
        </div>
      </div>
      {large?<div style={{padding:'2px 12px 12px'}}>
        <div style={{font:'var(--type-display)',letterSpacing:'var(--track-display)',color:'var(--text-strong)'}}>{title}</div>
        {subtitle?<div style={{font:'var(--type-subhead)',color:'var(--text-muted)',marginTop:2}}>{subtitle}</div>:null}
      </div>:null}
    </div>
  );
}
