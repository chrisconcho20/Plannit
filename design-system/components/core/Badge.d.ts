/** Small status pill: "5 of 6 free", "Private", "New". */
export interface BadgeProps {
  tone?: 'neutral' | 'primary' | 'free' | 'warning' | 'danger' | 'solid';
  /** optional 12px leading glyph */
  icon?: string;
  children?: React.ReactNode;
  style?: React.CSSProperties;
}
export function Badge(props: BadgeProps): JSX.Element;
