// DECOY. Shares a name with auth/session.ts's validate so that a text search
// for "function validate" finds two hits and gd finds exactly one.
export function validate(input: string): boolean {
  return input !== "";
}
