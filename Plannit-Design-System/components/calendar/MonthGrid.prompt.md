The calendar tab's month grid — dots, not event text, so the month stays legible.

```jsx
<MonthGrid year={2026} month={7} selected={16} marks={{14:['var(--hue-rose)'],16:['var(--hue-teal)','var(--hue-amber)']}} onSelect={setDay} />
```

Numerals are tabular. Max three dots per day; a fourth event never adds a fourth dot.
