/** Ink tooltip on hover — desktop/marketing surfaces only; the iOS app uses inline footnotes instead. */
export interface TooltipProps {
  label?: string;
  side?: 'top' | 'bottom';
  children?: React.ReactNode;
  style?: React.CSSProperties;
}
export function Tooltip(props: TooltipProps): JSX.Element;
