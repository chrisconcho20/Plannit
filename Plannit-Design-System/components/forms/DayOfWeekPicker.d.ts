/** Sunday-to-Saturday day toggles — every day selected by default; tap to rule days out. */
export interface DayOfWeekPickerProps {
  /** selected day indices, 0 = Sunday … 6 = Saturday. Default is all seven. */
  value?: number[];
  onChange?: (next: number[]) => void;
  style?: React.CSSProperties;
}
export function DayOfWeekPicker(props: DayOfWeekPickerProps): JSX.Element;
