import React from 'react';
import {Icon} from './Icon.jsx';

const TONES={
  neutral:['var(--bg-sunk)','var(--text-muted)'],
  primary:['var(--coral-50)','var(--coral-700)'],
  free:['var(--teal-50)','var(--teal-700)'],
  warning:['#FDF3E0','var(--amber-500)'],
  danger:['var(--red-50)','var(--red-500)'],
  solid:['var(--action-primary)','var(--white)']
};

export function Badge({tone='neutral',icon,children,style,...rest}){
  const [bg,fg]=TONES[tone]||TONES.neutral;
  return (
    <span {...rest} style={{display:'inline-flex',alignItems:'center',gap:4,padding:'3px 8px',borderRadius:'var(--r-pill)',
      background:bg,color:fg,font:'var(--type-label)',letterSpacing:'.01em',whiteSpace:'nowrap',...style}}>
      {icon?<Icon name={icon} size={12}/>:null}{children}
    </span>
  );
}
