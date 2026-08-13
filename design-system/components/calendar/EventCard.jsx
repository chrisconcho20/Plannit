import React from 'react';
import {Icon} from '../core/Icon.jsx';
import {Card} from '../core/Card.jsx';
import {Badge} from '../core/Badge.jsx';
import {AvatarStack} from '../core/AvatarStack.jsx';

export function EventCard({title,time,location,hue='var(--hue-coral)',group,people,icon,badge,badgeTone='neutral',onClick,style,...rest}){
  return (
    <Card elevation={1} pad={0} onClick={onClick} style={{...style}} {...rest}>
      <div style={{display:'flex',gap:12,padding:'14px 16px 14px 14px'}}>
        <span style={{display:'flex',alignItems:'center',justifyContent:'center',flex:'none',width:44,height:44,
          borderRadius:'var(--r-md)',background:hue}}>
          <Icon name={icon||'calendar'} size={22} color="var(--white)"/>
        </span>
        <div style={{flex:1,minWidth:0}}>
          <div style={{display:'flex',alignItems:'center',gap:8}}>
            <span style={{flex:1,minWidth:0,font:'var(--type-headline)',color:'var(--text-strong)',
              whiteSpace:'nowrap',overflow:'hidden',textOverflow:'ellipsis'}}>{title}</span>
            {badge?<Badge tone={badgeTone}>{badge}</Badge>:null}
          </div>
          <div style={{display:'flex',alignItems:'center',gap:6,marginTop:3,font:'var(--type-footnote)',color:'var(--text-muted)'}}>
            <Icon name="clock" size={13}/><span>{time}</span>
            {location?<><span style={{opacity:.5}}>·</span><Icon name="map-pin" size={13}/><span style={{whiteSpace:'nowrap',overflow:'hidden',textOverflow:'ellipsis'}}>{location}</span></>:null}
          </div>
          {group||people?<div style={{display:'flex',alignItems:'center',gap:8,marginTop:10}}>
            {group?<span style={{display:'inline-flex',alignItems:'center',gap:5,font:'var(--type-caption)',
              color:'var(--text-muted)'}}><span style={{width:7,height:7,borderRadius:'var(--r-pill)',background:hue}}/>{group}</span>:null}
            <span style={{flex:1}}/>
            {people?<AvatarStack people={people} size={24} max={4}/>:null}
          </div>:null}
        </div>
      </div>
    </Card>
  );
}
