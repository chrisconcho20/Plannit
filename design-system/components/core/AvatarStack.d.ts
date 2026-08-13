/** Overlapping avatar row for group membership and attendee lists. */
export interface AvatarStackProps {
  people?: { name?: string; src?: string }[];
  /** avatar diameter, default 32 */
  size?: number;
  /** how many before the +N pill, default 4 */
  max?: number;
  style?: React.CSSProperties;
}
export function AvatarStack(props: AvatarStackProps): JSX.Element;
