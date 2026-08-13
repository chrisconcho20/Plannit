import React from 'react';

export function ProgressDots({count=3,index=0,style,...rest}){
  return (
    <div {...rest} style={{display:'flex',alignItems:'center',gap:6,...style}}>
      {Array.from({length:count}).map((_,i)=>(
        <span key={i} style={{height:6,width:i===index?20:6,borderRadius:'var(--r-pill)',
          background:i===index?'var(--action-primary)':'var(--ink-200)',
          transition:'width var(--dur-base) var(--ease-ios),background-color var(--dur-base) var(--ease-out)'}}/>
      ))}
    </div>
  );
}
