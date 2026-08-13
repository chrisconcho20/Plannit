/**
 * Sliding-pill segmented switch — Plannit's tab pattern (Month / Week / List).
 * @startingPoint section="Forms" subtitle="Segmented control, switch, checkbox, radio" viewport="700x260"
 */
export interface SegmentedControlProps {
  options?: (string | { value: string; label: string })[];
  value?: string;
  onChange?: (next: string) => void;
  /** stretch to the container width, default true */
  fullWidth?: boolean;
  style?: React.CSSProperties;
}
export function SegmentedControl(props: SegmentedControlProps): JSX.Element;
