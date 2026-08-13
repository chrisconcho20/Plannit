/** Bottom tab bar, 56px + safe area. Active tab is coral; inactive is faint ink. */
export interface TabBarProps {
  tabs?: { value: string; label: string; icon: string; badge?: number | string }[];
  value?: string;
  onChange?: (next: string) => void;
  /** reserve the 34px home-indicator inset — true on a device, false in specimens/embeds */
  safeArea?: boolean;
  style?: React.CSSProperties;
}
export function TabBar(props: TabBarProps): JSX.Element;
