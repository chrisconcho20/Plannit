/**
 * The primary action control. Pill-shaped, never square.
 * @startingPoint section="Core" subtitle="Buttons in every variant and size" viewport="700x220"
 */
export interface ButtonProps {
  /** primary = one per screen; free = date-found/confirm actions; danger = destructive text button */
  variant?: 'primary' | 'secondary' | 'outline' | 'ghost' | 'free' | 'danger';
  /** sm 36px · md 46px · lg 54px (full-width sheet CTA) */
  size?: 'sm' | 'md' | 'lg';
  /** Icon name placed before the label */
  icon?: string;
  /** Icon name placed after the label */
  iconAfter?: string;
  fullWidth?: boolean;
  disabled?: boolean;
  /** swaps the leading icon for an hourglass and blocks input */
  loading?: boolean;
  children?: React.ReactNode;
  onClick?: (e: React.MouseEvent) => void;
  style?: React.CSSProperties;
}
export function Button(props: ButtonProps): JSX.Element;
