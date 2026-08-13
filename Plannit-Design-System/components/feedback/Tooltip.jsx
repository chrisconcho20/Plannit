import React from 'react';

export function Tooltip({label,side='top',children,style,...rest}){
  const [show,setShow]=React.useState(false);
  const pos=side==='top'?{bottom:'calc(100% + 8px)',left:'50%',transform:'translateX(-50%)'}
    :{top:'calc(100% + 8px)',left:'50%',transform:'translateX(-50%)'};
  return (
    <span {...rest} onPointerEnter={()=>setShow(true)} onPointerLeave={()=>setShow(false)}
      style={{position:'relative',display:'inline-flex',...style}}>
      {children}
      {show?<span style={{position:'absolute',zIndex:70,whiteSpace:'nowrap',padding:'6px 10px',
        borderRadius:'var(--r-sm)',background:'var(--ink-900)',color:'var(--white)',font:'var(--type-footnote)',
        boxShadow:'var(--shadow-2)',animation:'plannit-fade var(--dur-fast) var(--ease-out)',...pos}}>{label}</span>:null}
    </span>
  );
}
