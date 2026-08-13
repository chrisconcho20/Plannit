Plannit's four roots: Calendar, Groups, Plans (proposals), You.

```jsx
<TabBar value={tab} onChange={setTab} tabs={[
  {value:'cal',label:'Calendar',icon:'calendar-days'},
  {value:'groups',label:'Groups',icon:'users'},
  {value:'plans',label:'Plans',icon:'sparkles',badge:2},
  {value:'you',label:'You',icon:'user'}]} />
```

On a device leave `safeArea` alone. Outside a phone frame pass `safeArea={false}`, or the 34px home-indicator inset pushes the glyphs above centre.
