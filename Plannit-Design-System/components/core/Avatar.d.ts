/** Circular person avatar; falls back to initials on a deterministic group hue. */
export interface AvatarProps {
  /** display name — drives initials and the fallback hue */
  name?: string;
  src?: string;
  /** px diameter, default 40 */
  size?: number;
  /** colour of the 2px outer ring, usually a group hue */
  ring?: string;
  /** availability dot: teal when free, warm grey when busy */
  status?: 'free' | 'busy';
  style?: React.CSSProperties;
}
export function Avatar(props: AvatarProps): JSX.Element;
