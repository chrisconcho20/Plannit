/** Single- or multi-line text field with an inset hairline that thickens to coral on focus. */
export interface InputProps {
  /** uppercase 12px caption above the field */
  label?: string;
  /** footnote below the field */
  hint?: string;
  /** replaces hint and turns the border red */
  error?: string;
  /** leading Icon name */
  icon?: string;
  value?: string;
  onChange?: (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => void;
  placeholder?: string;
  type?: string;
  multiline?: boolean;
  rows?: number;
  style?: React.CSSProperties;
}
export function Input(props: InputProps): JSX.Element;
