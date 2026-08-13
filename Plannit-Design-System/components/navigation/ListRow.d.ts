/** One row of a grouped list — settings, group members, share targets. Wrap rows in a Card with pad={0}. */
export interface ListRowProps {
  /** Icon name rendered in a 32px rounded tile */
  icon?: string;
  /** solid tile colour (usually a group hue); glyph turns white */
  iconTint?: string;
  /** custom leading node (e.g. an Avatar) instead of icon */
  leading?: React.ReactNode;
  title?: React.ReactNode;
  subtitle?: string;
  /** muted right-aligned value text */
  value?: string;
  /** trailing node — a Switch, Badge, or Button */
  right?: React.ReactNode;
  chevron?: boolean;
  onClick?: () => void;
  /** red title for destructive rows */
  danger?: boolean;
  /** drops the hairline separator on the final row */
  last?: boolean;
  style?: React.CSSProperties;
}
export function ListRow(props: ListRowProps): JSX.Element;
