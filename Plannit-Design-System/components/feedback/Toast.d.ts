/** Transient confirmation that floats above the tab bar. One line, optional single action. */
export interface ToastProps {
  tone?: 'neutral' | 'free' | 'danger';
  icon?: string;
  children?: React.ReactNode;
  /** single trailing text action, e.g. "Undo" */
  action?: string;
  onAction?: () => void;
  style?: React.CSSProperties;
}
export function Toast(props: ToastProps): JSX.Element;
