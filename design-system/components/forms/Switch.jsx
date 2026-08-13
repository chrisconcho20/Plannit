import React from 'react';

export function Switch({checked,onChange,disabled,style,...rest}){
  return (
    <button type="button" role="switch" aria-checked={!!checked} disabled={disabled}
      onClick={()=>onChange&&onChange(!checked)} {...rest}
      style={{position:'relative',flex:'none',width:52,height:32,border:'none',padding:0,borderRadius:'var(--r-pill)',
        background:checked?'var(--status-free)':'var(--ink-200)',cursor:disabled?'not-allowed':'pointer',opacity:disabled?.45:1,
        transition:'background-color var(--dur-base) var(--ease-ios)',...style}}>
      <span style={{position:'absolute',top:2,left:checked?22:2,width:28,height:28,borderRadius:'var(--r-pill)',
        background:'var(--white)',boxShadow:'var(--shadow-2)',transition:'left var(--dur-base) var(--ease-ios)'}}/>
    </button>
  );
}
