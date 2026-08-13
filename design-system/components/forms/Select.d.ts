/** Native select styled to match Input; chevron-down affordance on the right. */
export interface SelectProps {
  label?: string;
  options?: (string | { value: string; label: string })[];
  value?: string;
  onChange?: (e: React.ChangeEvent<HTMLSelectElement>) => void;
  style?: React.CSSProperties;
}
export function Select(props: SelectProps): JSX.Element;
