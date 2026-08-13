import React from 'react';
import {Icon} from '../core/Icon.jsx';

export function Select({label,options=[],value,onChange,style,...rest}){
  return (
    <label style={{display:'block',...style}}>
      {label?<span style={{display:'block',font:'var(--type-caption)',letterSpacing:'var(--track-caps)',
        textTransform:'uppercase',color:'var(--text-muted)',marginBottom:6}}>{label}</span>:null}
      <span style={{position:'relative',display:'flex',alignItems:'center',background:'var(--bg-surface)',
        borderRadius:'var(--r-control)',boxShadow:'inset 0 0 0 1px var(--line-strong)'}}>
        <select value={value} onChange={onChange} {...rest}
          style={{appearance:'none',WebkitAppearance:'none',flex:1,minHeight:48,border:'none',outline:'none',
            background:'transparent',padding:'0 40px 0 14px',color:'var(--text-strong)',font:'var(--type-body)',cursor:'pointer'}}>
          {options.map(o=>{const v=typeof o==='string'?o:o.value,l=typeof o==='string'?o:o.label;
            return <option key={v} value={v}>{l}</option>;})}
        </select>
        <Icon name="chevron-down" size={18} color="var(--text-faint)" style={{position:'absolute',right:14,pointerEvents:'none'}}/>
      </span>
    </label>
  );
}
