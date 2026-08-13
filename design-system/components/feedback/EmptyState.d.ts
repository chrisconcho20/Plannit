/** First-run / nothing-here state: tinted glyph tile, warm one-liner, one action. */
export interface EmptyStateProps {
  icon?: string;
  title?: string;
  body?: string;
  /** a single Button */
  action?: React.ReactNode;
  style?: React.CSSProperties;
}
export function EmptyState(props: EmptyStateProps): JSX.Element;
