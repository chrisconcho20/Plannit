/** Bottom sheet — Plannit's only modal. Grabber, 32px top corners, scrim, iOS easing. */
export interface SheetProps {
  open?: boolean;
  title?: string;
  onClose?: () => void;
  /** sticky footer area, usually a full-width primary Button */
  footer?: React.ReactNode;
  children?: React.ReactNode;
  style?: React.CSSProperties;
}
export function Sheet(props: SheetProps): JSX.Element | null;
