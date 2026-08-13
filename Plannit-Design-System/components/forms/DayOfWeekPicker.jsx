import React from 'react';

const DAYS=[{i:0,short:'Su',name:'Sunday'},{i:1,short:'Mo',name:'Monday'},{i:2,short:'Tu',name:'Tuesday'},
  {i:3,short:'We',name:'Wednesday'},{i:4,short:'Th',name:'Thursday'},{i:5,short:'Fr',name:'Friday'},{i:6,short:'Sa',name:'Saturday'}];

export function DayOfWeekPicker({value=[0,1,2,3,4,5,6],onChange,style,...rest}){
  const toggle=i=>{
    if(!onChange) return;
    onChange(value.includes(i)?value.filter(v=>v!==i):[...value,i].sort((a,b)=>a-b));
  };
  return (
    <div {...rest} style={{display:'flex',gap:5,...style}}>
      {DAYS.map(d=>{
        const on=value.includes(d.i);
        return (
          <button key={d.i} type="button" aria-pressed={on} aria-label={d.name} onClick={()=>toggle(d.i)}
            style={{flex:1,minWidth:0,minHeight:46,border:'none',cursor:'pointer',borderRadius:'var(--r-md)',
              background:on?'var(--action-primary)':'var(--bg-surface)',
              color:on?'var(--white)':'var(--text-faint)',
              boxShadow:on?'none':'inset 0 0 0 1px var(--line-strong)',
              font:'var(--fw-semibold) var(--text-subhead)/1 var(--font-core)',
              transition:'var(--transition-control)',WebkitTapHighlightColor:'transparent'}}>{d.short}</button>
        );
      })}
    </div>
  );
}
