import React from 'react';

export function Card({elevation=1,pad=16,accent,onClick,children,style,...rest}){
  const [press,setPress]=React.useState(false);
  return (
    <div onClick={onClick}
      onPointerDown={()=>onClick&&setPress(true)} onPointerUp={()=>setPress(false)} onPointerLeave={()=>setPress(false)}
      style={{position:'relative',overflow:'hidden',background:'var(--bg-surface)',borderRadius:'var(--r-card)',
        padding:pad,boxShadow:elevation===0?'var(--ring-inset)':elevation===1?'var(--shadow-1),var(--ring-inset)':elevation===2?'var(--shadow-2)':'var(--shadow-3)',
        cursor:onClick?'pointer':'default',transform:press?'scale(.988)':'none',
        transition:'transform var(--dur-fast) var(--ease-out),box-shadow var(--dur-base) var(--ease-out)',...style}} {...rest}>
      {accent?<span style={{position:'absolute',left:0,top:0,bottom:0,width:4,background:accent}}/>:null}
      {children}
    </div>
  );
}
