import { validate } from "./session";

export function issue(subject: string): string {
  const token = `${subject}-token-value`;
  if (!validate(token)) {
    return "";
  }
  return token;
}
