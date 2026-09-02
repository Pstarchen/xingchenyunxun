const SCOPE_PATTERN: RegExp = new RegExp('^nezha:[a-z][a-z0-9-]*:(read|write|delete|exec|\\*)$')
const CAPABILITY_PATTERN: RegExp = new RegExp('^[a-z][a-z0-9-]*-v[0-9]+$')
const CONTROLLER_ID_PATTERN: RegExp = new RegExp('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$')

export function isValidMonitorScope(scope: string): boolean {
  const value: string = scope.trim()
  return value === 'nezha:*' || SCOPE_PATTERN.test(value)
}

export function normalizeMonitorScopes(scopes: string[]): string[] | undefined {
  const normalized: string[] = []
  for (let index: number = 0; index < scopes.length; index++) {
    const scope: string = scopes[index].trim()
    if (!isValidMonitorScope(scope)) {
      return undefined
    }
    if (normalized.indexOf(scope) < 0) {
      normalized.push(scope)
    }
  }
  return normalized
}

export function hasMonitorScope(scopes: string[], requiredScope: string): boolean {
  if (!isValidMonitorScope(requiredScope)) {
    return false
  }
  if (scopes.indexOf('nezha:*') >= 0 || scopes.indexOf(requiredScope) >= 0) {
    return true
  }
  const separator: number = requiredScope.lastIndexOf(':')
  if (separator <= 0) {
    return false
  }
  const wildcard: string = `${requiredScope.substring(0, separator)}:*`
  return scopes.indexOf(wildcard) >= 0
}

export function isValidCapability(capability: string): boolean {
  return CAPABILITY_PATTERN.test(capability.trim())
}

export function normalizeCapabilities(capabilities: string[]): string[] | undefined {
  const normalized: string[] = []
  for (let index: number = 0; index < capabilities.length; index++) {
    const capability: string = capabilities[index].trim()
    if (!isValidCapability(capability)) {
      return undefined
    }
    if (normalized.indexOf(capability) < 0) {
      normalized.push(capability)
    }
  }
  return normalized
}

export function isValidControllerId(controllerId: string): boolean {
  return CONTROLLER_ID_PATTERN.test(controllerId.trim())
}
