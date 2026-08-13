import React from 'react';

export function Radio({checked,onChange,label,sublabel,disabled,style,...rest}){
  return (
    <label {...rest} style={{display:'flex',alignItems:'flex-start',gap:12,minHeight:'var(--tap-min)',
      cursor:disabled?'not-allowed':'pointer',opacity:disabled?.45:1,...style}}>
      <span style={{display:'flex',alignItems:'center',justifyContent:'center',flex:'none',width:24,height:24,marginTop:2,
        borderRadius:'var(--r-pill)',background:'var(--bg-surface)',
        boxShadow:checked?'inset 0 0 0 7px var(--action-primary)':'inset 0 0 0 1.5px var(--line-strong)',
        transition:'box-shadow var(--dur-fast) var(--ease-pop)'}}/>
      <input type="radio" checked={!!checked} onChange={onChange} readOnly={!onChange} disabled={disabled}
        style={{position:'absolute',opacity:0,width:0,height:0}}/>
      <span style={{paddingTop:2}}>
        <span style={{display:'block',font:'var(--type-body)',color:'var(--text-strong)'}}>{label}</span>
        {sublabel?<span style={{display:'block',font:'var(--type-footnote)',color:'var(--text-muted)',marginTop:2}}>{sublabel}</span>:null}
      </span>
    </label>
  );
}
