export interface Store {
  get(key: string): string | undefined;
  put(key: string, value: string): void;
}
