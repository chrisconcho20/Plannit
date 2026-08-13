# Plannit app icon — "The found day"

A calendar page with one cell turned teal: the moment the date-finder lands on a slot that works. Coral `#F76941` ground, warm-white page `#FFFBF6`, warm-grey cells `#E0D8CC`, teal cell `#14A98F`.

## Drop it into Xcode

1. In your Xcode project, open `Assets.xcassets` and delete the placeholder **AppIcon** set.
2. Drag `AppIcon.appiconset` (this folder) into `Assets.xcassets`. Xcode 14+ needs only the single 1024×1024 image and generates every other size at build time.
3. Confirm **Target → General → App Icons and Launch Screen → App Icon** reads `AppIcon`.

If you prefer to supply every size yourself (or need them for a website, TestFlight art, or an Android port), the loose PNGs are here:

| File | Where it's used |
|---|---|
| `PlannitAppIcon-1024.png` | App Store / Xcode single-size slot |
| `180` · `120` | iPhone home screen (@3x, @2x) |
| `167` · `152` · `76` | iPad Pro / iPad |
| `114` · `100` | Apple Watch-adjacent + legacy |
| `87` · `58` · `29` | Settings |
| `80` · `40` · `20` | Spotlight / notifications |
| `144` · `128` · `60` | Legacy and marketing use |

## Rules Apple enforces

- **Square, fully opaque, no transparency** — these files are fully opaque. One caveat: PNGs written by a browser canvas still carry an (unused) alpha *channel*, and App Store Connect rejects the 1024 marketing icon for that. Strip it once before upload:

  ```sh
  # macOS, no extra tools
  sips -s format png --setProperty hasAlpha false PlannitAppIcon-1024.png --out PlannitAppIcon-1024.png
  # or with ImageMagick
  magick PlannitAppIcon-1024.png -background '#F76941' -alpha remove -alpha off PlannitAppIcon-1024.png
  ```

  Local builds and simulator runs work fine as-is; this only matters at upload.
- **Don't pre-round the corners** and don't add a drop shadow or inner glow.
- **Don't add the app name** — the home screen prints the label under the icon.
- Keep the artwork inside the safe area: nothing meaningful within ~8% of any edge.

## Regenerating / editing

The icon is drawn from proportions, not pixels, so every size is crisp. To change a colour, edit the constants in the generator (coral / page / cell / teal) and re-render — or ask me and I'll produce a new set. For a vector master (SVG/PDF for print and App Store marketing), we should have a designer redraw it properly: this set is programmatically generated CSS-geometry, good enough to ship a beta but not a hand-tuned mark.
