How Plannit asks "which days work?" — seven coral capsules, all on, tap to deselect. This replaced free-text constraints; never ask the user to type when a day is meant.

```jsx
const [days,setDays]=React.useState([0,1,2,3,4,5,6]);
<DayOfWeekPicker value={days} onChange={setDays} />
```

Summarise the selection in words underneath ("Any day", "Sat & Sun", "Mon–Fri") so the constraint stays readable. Zero days selected is an invalid state — disable the Find-a-date button rather than showing an error.
