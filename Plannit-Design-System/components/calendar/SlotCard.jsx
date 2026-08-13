import React from 'react';
import {Icon} from '../core/Icon.jsx';
import {Card} from '../core/Card.jsx';
import {Badge} from '../core/Badge.jsx';
import {AvatarStack} from '../core/AvatarStack.jsx';

export function SlotCard({day,date,time,freeCount,total,people,best,selected,onClick,style,...rest}){
  const all=freeCount===total;
  return (
    <Card elevation={selected?2:1} pad={0} onClick={onClick}
      style={{boxShadow:selected?'var(--shadow-2),inset 0 0 0 2px var(--action-primary)':undefined,...style}} {...rest}>
      <div style={{display:'flex',alignItems:'center',gap:14,padding:'14px 16px'}}>
        <div style={{display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',flex:'none',
          width:52,padding:'6px 0',borderRadius:'var(--r-md)',background:all?'var(--teal-50)':'var(--bg-sunk)'}}>
          <span style={{font:'var(--type-caption)',letterSpacing:'var(--track-caps)',textTransform:'uppercase',
            color:all?'var(--teal-700)':'var(--text-muted)'}}>{day}</span>
          <span style={{font:'var(--fw-heavy) var(--text-title2)/1.05 var(--font-display)',
            fontVariantNumeric:'tabular-nums',color:all?'var(--teal-700)':'var(--text-strong)'}}>{date}</span>
        </div>
        <div style={{flex:1,minWidth:0}}>
          <div style={{display:'flex',alignItems:'center',gap:8}}>
            <span style={{font:'var(--type-headline)',color:'var(--text-strong)'}}>{time}</span>
            {best?<Badge tone="primary" icon="sparkles">Best</Badge>:null}
          </div>
          <div style={{display:'flex',alignItems:'center',gap:8,marginTop:6}}>
            <Badge tone={all?'free':'neutral'} icon={all?'check':undefined}>{freeCount} of {total} free</Badge>
            <span style={{flex:1}}/>
            {people?<AvatarStack people={people} size={24} max={4}/>:null}
          </div>
        </div>
        <Icon name="chevron-right" size={18} color="var(--text-faint)"/>
      </div>
    </Card>
  );
}
