/** Month view. Days carry up to three group-hue dots; the selected day is a coral rounded square. */
export interface MonthGridProps {
  year?: number;
  /** 0-indexed month, like JS Date */
  month?: number;
  selected?: number;
  /** day-of-month -> array of hue tokens, e.g. { 16: ['var(--hue-teal)'] } */
  marks?: Record<number, string[]>;
  onSelect?: (day: number) => void;
  style?: React.CSSProperties;
}
export function MonthGrid(props: MonthGridProps): JSX.Element;
