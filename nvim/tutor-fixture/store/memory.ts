import { Store } from "./iface";

export class MemoryStore implements Store {
  private data = new Map<string, string>();

  get(key: string): string | undefined {
    return this.data.get(key);
  }

  put(key: string, value: string): void {
    this.data.set(key, value);
  }
}
