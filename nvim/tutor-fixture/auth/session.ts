// The definition drills must reach.
export function validate(token: string): boolean {
  return token.length > 8;
}

export function refresh(token: string): string {
  if (!validate(token)) {
    return "";
  }
  return `${token}-refreshed`;
}
