import React from 'react';

const HUES=['var(--hue-coral)','var(--hue-amber)','var(--hue-teal)','var(--hue-sky)','var(--hue-indigo)','var(--hue-rose)'];
function pick(name=''){let n=0;for(let i=0;i<name.length;i++)n+=name.charCodeAt(i);return HUES[n%HUES.length];}

export function Avatar({name='',src,size=40,ring,status,style,...rest}){
  const initials=name.trim().split(/\s+/).slice(0,2).map(w=>w[0]||'').join('').toUpperCase();
  return (
    <span {...rest} style={{position:'relative',display:'inline-flex',flex:'none',width:size,height:size,...style}}>
      <span style={{display:'flex',alignItems:'center',justifyContent:'center',width:'100%',height:'100%',
        borderRadius:'var(--r-pill)',overflow:'hidden',background:src?'var(--bg-sunk)':pick(name),
        color:'var(--white)',font:'var(--fw-bold) '+Math.round(size*0.4)+'px/1 var(--font-display)',
        boxShadow:ring?'0 0 0 2px var(--bg-surface),0 0 0 4px '+ring:'none'}}>
        {src?<img src={src} alt={name} style={{width:'100%',height:'100%',objectFit:'cover'}}/>:initials}
      </span>
      {status?<span style={{position:'absolute',right:-1,bottom:-1,width:Math.max(10,size*0.28),height:Math.max(10,size*0.28),
        borderRadius:'var(--r-pill)',background:status==='free'?'var(--status-free)':'var(--status-busy)',
        boxShadow:'0 0 0 2px var(--bg-surface)'}}/>:null}
    </span>
  );
}
