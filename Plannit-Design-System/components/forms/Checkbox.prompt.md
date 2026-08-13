Pick several — which groups can see an event, which days to allow.

```jsx
<Checkbox checked={days} onChange={()=>setDays(!days)} label="Weekends" sublabel="Sat & Sun, any time after noon" />
```

Pass `onChange` whenever the control should respond to taps; a `checked` value with no handler renders as a deliberate read-only display.
