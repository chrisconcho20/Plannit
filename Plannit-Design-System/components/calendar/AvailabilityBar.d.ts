/** One person's day as opaque busy blocks over free teal — never shows event titles (privacy model D-08). */
export interface AvailabilityBarProps {
  /** person label on the left, 64px column */
  name?: string;
  /** busy intervals in decimal hours, e.g. [{start:9,end:12.5}] */
  blocks?: { start: number; end: number }[];
  /** window start hour, default 8 */
  from?: number;
  /** window end hour, default 22 */
  to?: number;
  height?: number;
  style?: React.CSSProperties;
}
export function AvailabilityBar(props: AvailabilityBarProps): JSX.Element;
