Renders one Plannit (Lucide) glyph, tinted with the current text color — use it anywhere an icon is needed instead of inlining SVG.

```jsx
<Icon name="calendar-days" size={24} />
<Icon name="sparkles" size={16} color="var(--status-free)" />
```

Set `window.PLANNIT_ICON_BASE` once per page to the relative path of `assets/icons` (e.g. `'../../assets/icons'`). Available stems are the 50 files in `assets/icons/`. Never pass an emoji or a hand-drawn SVG instead.
