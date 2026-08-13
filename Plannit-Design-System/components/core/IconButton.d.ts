/** Circular icon-only tap target. Never render below 44px. */
export interface IconButtonProps {
  /** Icon name from assets/icons */
  name: string;
  /** tap-target diameter, default 44 (the minimum) */
  size?: number;
  /** glyph size; defaults to 48% of size */
  iconSize?: number;
  /** chrome = translucent blurred pill for use over content */
  variant?: 'plain' | 'filled' | 'primary' | 'chrome';
  /** accessible label — required in practice */
  label?: string;
  disabled?: boolean;
  onClick?: (e: React.MouseEvent) => void;
  style?: React.CSSProperties;
}
export function IconButton(props: IconButtonProps): JSX.Element;
