/** Group chip / filter chip. Carries a group hue as a dot or a filled state. */
export interface TagProps {
  /** the group's hue token, e.g. var(--hue-sky) */
  hue?: string;
  /** soft background used when unselected but tinted, e.g. var(--hue-sky-soft) */
  soft?: string;
  selected?: boolean;
  /** replaces the hue dot with a glyph */
  icon?: string;
  onClick?: (e: React.MouseEvent) => void;
  onRemove?: (e: React.MouseEvent) => void;
  children?: React.ReactNode;
  style?: React.CSSProperties;
}
export function Tag(props: TagProps): JSX.Element;
