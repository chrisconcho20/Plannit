/** A proposed slot from the date-finder: date block, time, who's free, vote affordance. */
export interface SlotCardProps {
  /** short weekday, e.g. "SAT" */
  day?: string;
  /** day of month, e.g. 16 */
  date?: number | string;
  /** time range, e.g. "2:00 – 4:00 PM" */
  time?: string;
  freeCount?: number;
  total?: number;
  people?: { name?: string; src?: string }[];
  /** marks the top-ranked slot with a coral "Best" badge */
  best?: boolean;
  /** coral 2px inset ring — the user's current vote */
  selected?: boolean;
  onClick?: () => void;
  style?: React.CSSProperties;
}
export function SlotCard(props: SlotCardProps): JSX.Element;
