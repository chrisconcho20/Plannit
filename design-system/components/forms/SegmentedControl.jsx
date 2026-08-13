import React from 'react';

export function SegmentedControl({options=[],value,onChange,fullWidth=true,style,...rest}){
  const items=options.map(o=>typeof o==='string'?{value:o,label:o}:o);
  const i=Math.max(0,items.findIndex(o=>o.value===value));
  return (
    <div {...rest} style={{position:'relative',display:'flex',padding:3,gap:0,background:'var(--bg-sunk)',
      borderRadius:'var(--r-pill)',width:fullWidth?'100%':'auto',...style}}>
      <span style={{position:'absolute',top:3,bottom:3,left:'calc('+(i*100/items.length)+'% + 3px)',
        width:'calc('+(100/items.length)+'% - 6px)',background:'var(--bg-surface)',borderRadius:'var(--r-pill)',
        boxShadow:'var(--shadow-1)',transition:'left var(--dur-base) var(--ease-ios)'}}/>
      {items.map(o=>(
        <button key={o.value} type="button" onClick={()=>onChange&&onChange(o.value)}
          style={{position:'relative',flex:1,minHeight:38,border:'none',background:'transparent',cursor:'pointer',
            color:o.value===value?'var(--text-strong)':'var(--text-muted)',
            font:'var(--type-subhead)',fontWeight:'var(--fw-semibold)',borderRadius:'var(--r-pill)',
            transition:'color var(--dur-fast) var(--ease-out)'}}>{o.label}</button>
      ))}
    </div>
  );
}
