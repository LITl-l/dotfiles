import { validate } from "../auth/session";

export function handle(token: string): number {
  if (!validate(token)) {
    return 401;
  }
  return 200;
}
