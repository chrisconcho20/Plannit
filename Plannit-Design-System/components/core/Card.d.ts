/** Warm-white rounded container: 18px radius, hairline inset ring, soft shadow. */
export interface CardProps {
  /** 0 hairline only · 1 resting list card · 2 lifted · 3 sheet/modal */
  elevation?: 0 | 1 | 2 | 3;
  /** inner padding in px, default 16 */
  pad?: number;
  /** optional 4px group-hue spine on the left edge (group-coloured events only) */
  accent?: string;
  onClick?: (e: React.MouseEvent) => void;
  children?: React.ReactNode;
  style?: React.CSSProperties;
}
export function Card(props: CardProps): JSX.Element;
