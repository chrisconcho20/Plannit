/**
 * The core Plannit list object: one event, its time, its group hue, and who's coming.
 * @startingPoint section="Calendar" subtitle="Event cards, day list, availability" viewport="700x300"
 */
export interface EventCardProps {
  title?: string;
  /** human time range, e.g. "Sat 16 Aug · 2:00–4:00 PM" */
  time?: string;
  location?: string;
  /** group hue token driving the leading tile and the group dot */
  hue?: string;
  /** group name shown under the meta line */
  group?: string;
  people?: { name?: string; src?: string }[];
  /** Icon name for the leading tile, default "calendar" */
  icon?: string;
  /** short status text, e.g. "Private" or "Found" */
  badge?: string;
  badgeTone?: 'neutral' | 'primary' | 'free' | 'warning' | 'danger' | 'solid';
  onClick?: () => void;
  style?: React.CSSProperties;
}
export function EventCard(props: EventCardProps): JSX.Element;
