import React from 'react';
import {IconButton} from '../core/IconButton.jsx';

export function Sheet({open=true,title,onClose,footer,children,style,...rest}){
  if(!open) return null;
  return (
    <div style={{position:'absolute',inset:0,zIndex:60,display:'flex',flexDirection:'column',justifyContent:'flex-end'}}>
      <div onClick={onClose} style={{position:'absolute',inset:0,background:'var(--bg-scrim)',
        animation:'plannit-fade var(--dur-base) var(--ease-out)'}}/>
      <div {...rest} style={{position:'relative',background:'var(--bg-surface)',
        borderRadius:'var(--r-sheet) var(--r-sheet) 0 0',boxShadow:'var(--shadow-sheet)',
        paddingBottom:'var(--safe-bottom)',maxHeight:'90%',display:'flex',flexDirection:'column',
        animation:'plannit-sheet var(--dur-sheet) var(--ease-ios)',...style}}>
        <div style={{display:'flex',justifyContent:'center',paddingTop:8}}>
          <span style={{width:36,height:5,borderRadius:'var(--r-pill)',background:'var(--ink-200)'}}/>
        </div>
        <div style={{display:'flex',alignItems:'center',gap:8,padding:'8px 12px 12px 20px'}}>
          <h3 style={{flex:1,font:'var(--type-title3)',color:'var(--text-strong)'}}>{title}</h3>
          {onClose?<IconButton name="x" label="Close" size={36} variant="filled" onClick={onClose}/>:null}
        </div>
        <div style={{flex:1,overflowY:'auto',padding:'0 20px 16px'}}>{children}</div>
        {footer?<div style={{padding:'12px 20px 4px',borderTop:'1px solid var(--line-hairline)'}}>{footer}</div>:null}
      </div>
    </div>
  );
}
