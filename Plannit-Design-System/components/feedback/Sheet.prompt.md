Every "compose", "confirm", or "pick" flow happens in a bottom sheet — Plannit has no centred dialogs.

```jsx
<Sheet open={open} title="New plan" onClose={close}
  footer={<Button variant="primary" size="lg" fullWidth>Find a date</Button>}>
  …
</Sheet>
```

Requires the `plannit-sheet` / `plannit-fade` keyframes (see `guidelines/motion.md`); the host page declares them.
