Plannit's pill button — one `primary` per screen, everything else secondary/ghost.

```jsx
<Button variant="primary" size="lg" icon="wand-sparkles" fullWidth>Find a date</Button>
<Button variant="secondary" icon="share-2">Share with a group</Button>
<Button variant="ghost" size="sm">Maybe</Button>
```

Variants: primary (coral, soft coral shadow), secondary (warm grey fill), outline, ghost (coral text), free (teal — reserved for availability/confirmation moments), danger (red text only, never a red fill). Press state is a 0.97 scale, no color-shift-only feedback.
