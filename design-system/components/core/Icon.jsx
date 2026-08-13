import React from 'react';

export function Icon({name,size=20,color='currentColor',basePath,style,...rest}){
  const base=basePath||(typeof window!=='undefined'&&window.PLANNIT_ICON_BASE)||'assets/icons';
  const url='url("'+base+'/'+name+'.svg")';
  return <span aria-hidden="true" {...rest} style={{display:'inline-block',flex:'none',width:size,height:size,backgroundColor:color,WebkitMaskImage:url,maskImage:url,WebkitMaskSize:'contain',maskSize:'contain',WebkitMaskRepeat:'no-repeat',maskRepeat:'no-repeat',WebkitMaskPosition:'center',maskPosition:'center',...style}}/>;
}
