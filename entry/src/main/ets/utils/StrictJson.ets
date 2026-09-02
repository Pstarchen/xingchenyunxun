export type JsonRecord = Record<string, Object>

export class StrictJson {
  static parseRecord(raw: string, context: string): JsonRecord {
    if (raw.trim().length === 0) {
      throw new Error(`${context}: empty JSON response`)
    }
    const parsed: Object = JSON.parse(raw) as Object
    if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) {
      throw new Error(`${context}: expected object`)
    }
    return parsed as JsonRecord
  }

  static parseRecords(raw: string, context: string): JsonRecord[] {
    if (raw.trim().length === 0) {
      throw new Error(`${context}: empty JSON response`)
    }
    const parsed: Object = JSON.parse(raw) as Object
    if (!Array.isArray(parsed)) {
      throw new Error(`${context}: expected array`)
    }
    const sourceItems: Object[] = parsed as Object[]
    const items: JsonRecord[] = []
    for (let index: number = 0; index < sourceItems.length; index++) {
      const item: Object = sourceItems[index]
      if (item === null || typeof item !== 'object' || Array.isArray(item)) {
        throw new Error(`${context}[${index}]: expected object`)
      }
      items.push(item as JsonRecord)
    }
    return items
  }

  static record(source: JsonRecord, key: string, context: string): JsonRecord {
    const value: Object | undefined = source[key]
    if (value === undefined || value === null || typeof value !== 'object' || Array.isArray(value)) {
      throw new Error(`${context}.${key}: expected object`)
    }
    return value as JsonRecord
  }

  static optionalRecord(source: JsonRecord, key: string, context: string): JsonRecord | undefined {
    const value: Object | undefined = source[key]
    if (value === undefined || value === null) {
      return undefined
    }
    if (typeof value !== 'object' || Array.isArray(value)) {
      throw new Error(`${context}.${key}: expected optional object`)
    }
    return value as JsonRecord
  }

  static string(source: JsonRecord, key: string, context: string): string {
    const value: Object | undefined = source[key]
    if (typeof value !== 'string') {
      throw new Error(`${context}.${key}: expected string`)
    }
    return String(value)
  }

  static optionalString(source: JsonRecord, key: string, context: string): string {
    const value: Object | undefined = source[key]
    if (value === undefined || value === null) {
      return ''
    }
    if (typeof value !== 'string') {
      throw new Error(`${context}.${key}: expected optional string`)
    }
    return String(value)
  }

  static optionalStringOrNumber(source: JsonRecord, key: string, context: string): string {
    const value: Object | undefined = source[key]
    if (value === undefined || value === null) {
      return ''
    }
    if (typeof value !== 'string' && typeof value !== 'number') {
      throw new Error(`${context}.${key}: expected optional string or number`)
    }
    return String(value)
  }

  static number(source: JsonRecord, key: string, context: string): number {
    const value: Object | undefined = source[key]
    if (typeof value !== 'number' || !Number.isFinite(Number(value))) {
      throw new Error(`${context}.${key}: expected finite number`)
    }
    return Number(value)
  }

  static optionalNumber(source: JsonRecord, key: string, fallback: number, context: string): number {
    const value: Object | undefined = source[key]
    if (value === undefined || value === null) {
      return fallback
    }
    if (typeof value !== 'number' || !Number.isFinite(Number(value))) {
      throw new Error(`${context}.${key}: expected optional finite number`)
    }
    return Number(value)
  }

  static boolean(source: JsonRecord, key: string, context: string): boolean {
    const value: Object | undefined = source[key]
    if (typeof value !== 'boolean') {
      throw new Error(`${context}.${key}: expected boolean`)
    }
    return Boolean(value)
  }

  static optionalBoolean(source: JsonRecord, key: string, fallback: boolean, context: string): boolean {
    const value: Object | undefined = source[key]
    if (value === undefined || value === null) {
      return fallback
    }
    if (typeof value !== 'boolean') {
      throw new Error(`${context}.${key}: expected optional boolean`)
    }
    return Boolean(value)
  }

  static records(source: JsonRecord, key: string, context: string): JsonRecord[] {
    const value: Object | undefined = source[key]
    if (!Array.isArray(value)) {
      throw new Error(`${context}.${key}: expected array`)
    }
    const sourceItems: Object[] = value as Object[]
    const items: JsonRecord[] = []
    for (let index: number = 0; index < sourceItems.length; index++) {
      const item: Object = sourceItems[index]
      if (item === null || typeof item !== 'object' || Array.isArray(item)) {
        throw new Error(`${context}.${key}[${index}]: expected object`)
      }
      items.push(item as JsonRecord)
    }
    return items
  }

  static optionalRecords(source: JsonRecord, key: string, context: string): JsonRecord[] {
    const value: Object | undefined = source[key]
    if (value === undefined || value === null) {
      return []
    }
    return StrictJson.records(source, key, context)
  }

  static strings(source: JsonRecord, key: string, context: string): string[] {
    const value: Object | undefined = source[key]
    if (!Array.isArray(value)) {
      throw new Error(`${context}.${key}: expected string array`)
    }
    const sourceItems: Object[] = value as Object[]
    const items: string[] = []
    for (let index: number = 0; index < sourceItems.length; index++) {
      if (typeof sourceItems[index] !== 'string') {
        throw new Error(`${context}.${key}[${index}]: expected string`)
      }
      items.push(String(sourceItems[index]))
    }
    return items
  }

  static optionalStrings(source: JsonRecord, key: string, context: string): string[] {
    const value: Object | undefined = source[key]
    if (value === undefined || value === null) {
      return []
    }
    return StrictJson.strings(source, key, context)
  }

  static numbers(source: JsonRecord, key: string, context: string): number[] {
    const value: Object | undefined = source[key]
    if (!Array.isArray(value)) {
      throw new Error(`${context}.${key}: expected number array`)
    }
    const sourceItems: Object[] = value as Object[]
    const items: number[] = []
    for (let index: number = 0; index < sourceItems.length; index++) {
      if (typeof sourceItems[index] !== 'number' || !Number.isFinite(Number(sourceItems[index]))) {
        throw new Error(`${context}.${key}[${index}]: expected finite number`)
      }
      items.push(Number(sourceItems[index]))
    }
    return items
  }
}
