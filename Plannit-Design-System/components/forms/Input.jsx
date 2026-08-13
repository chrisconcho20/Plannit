import React from 'react';
import {Icon} from '../core/Icon.jsx';

export function Input({label,hint,error,icon,value,onChange,placeholder,type='text',multiline,rows=3,style,...rest}){
  const [focus,setFocus]=React.useState(false);
  const El=multiline?'textarea':'input';
  return (
    <label style={{display:'block',...style}}>
      {label?<span style={{display:'block',font:'var(--type-caption)',letterSpacing:'var(--track-caps)',
        textTransform:'uppercase',color:'var(--text-muted)',marginBottom:6}}>{label}</span>:null}
      <span style={{display:'flex',alignItems:multiline?'flex-start':'center',gap:10,padding:multiline?'12px 14px':'0 14px',
        minHeight:48,background:'var(--bg-surface)',borderRadius:'var(--r-control)',
        boxShadow:error?'inset 0 0 0 1.5px var(--status-danger)':focus?'inset 0 0 0 1.5px var(--line-focus),var(--ring-focus)':'inset 0 0 0 1px var(--line-strong)',
        transition:'box-shadow var(--dur-fast) var(--ease-out)'}}>
        {icon?<Icon name={icon} size={18} color="var(--text-faint)" style={{marginTop:multiline?3:0}}/>:null}
        <El type={type} value={value} onChange={onChange} placeholder={placeholder} rows={multiline?rows:undefined}
          onFocus={()=>setFocus(true)} onBlur={()=>setFocus(false)} {...rest}
          style={{flex:1,minWidth:0,border:'none',outline:'none',background:'transparent',resize:multiline?'vertical':undefined,
            color:'var(--text-strong)',font:'var(--type-body)',letterSpacing:'var(--track-body)',padding:multiline?0:'12px 0'}}/>
      </span>
      {hint||error?<span style={{display:'block',font:'var(--type-footnote)',color:error?'var(--status-danger)':'var(--text-muted)',marginTop:6}}>{error||hint}</span>:null}
    </label>
  );
}
