/**
 * Lucide glyph rendered as a currentColor-tinted mask. 1.5–2px stroke, rounded caps.
 */
export interface IconProps {
  /** file stem in assets/icons, e.g. "calendar-days" */
  name: string;
  /** px box, default 20. Use 16 in captions, 20 in rows, 24 in nav, 28 in tab bar. */
  size?: number;
  /** any CSS color; defaults to currentColor */
  color?: string;
  /** path to the icons folder; defaults to window.PLANNIT_ICON_BASE or "assets/icons" */
  basePath?: string;
  style?: React.CSSProperties;
}
export function Icon(props: IconProps): JSX.Element;
