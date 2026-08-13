/** Sticky translucent top bar. Compact (centred 17px title) or large (34px display title below). */
export interface NavBarProps {
  title?: string;
  subtitle?: string;
  /** large iOS title treatment — use on a tab root, not on pushed screens */
  large?: boolean;
  back?: boolean;
  onBack?: () => void;
  /** IconButton prop objects rendered on the right */
  actions?: { name: string; label?: string; onClick?: () => void }[];
  style?: React.CSSProperties;
}
export function NavBar(props: NavBarProps): JSX.Element;
