import { ClientBootstrap } from '../model/BootstrapModels'
import { BindingMetadata } from '../model/ControllerProfileModels'
import { MonitorConnection } from '../model/MonitorModels'
import { isValidControllerId, normalizeCapabilities, normalizeMonitorScopes } from './ScopePolicy'
import { JsonRecord, StrictJson } from './StrictJson'

const BINDING_TYPE: string = 'xingchenyunxun-bind'
const MAX_BINDING_SCHEMA_VERSION: number = 2
const URL_PATTERN: RegExp = new RegExp('^(https?):\\/\\/([^\\/?#\\s]+)(\\/[^?#\\s]*)?(?:[?#].*)?$', 'i')
const TRAILING_SLASH_PATTERN: RegExp = new RegExp('/+$')
const TOKEN_PATTERN: RegExp = new RegExp('^nzp_[A-Za-z0-9_-]+$')

export function normalizeBindingBaseUrlValue(raw: string): string {
  const value: string = raw.trim()
  const match: RegExpExecArray | null = URL_PATTERN.exec(value)
  if (match === null || match[2].includes('@')) {
    return ''
  }
  const rawPath: string = match[3] ?? ''
  const path: string = rawPath.replace(TRAILING_SLASH_PATTERN, '')
  return `${match[1].toLowerCase()}://${match[2]}${path}`
}

export function normalizeBindingTokenValue(raw: string): string {
  let value: string = raw.trim()
  const bearerPrefix: string = 'Bearer '
  if (value.length > bearerPrefix.length &&
    value.substring(0, bearerPrefix.length).toLowerCase() === bearerPrefix.toLowerCase()) {
    value = value.substring(bearerPrefix.length).trim()
  }
  return TOKEN_PATTERN.test(value) ? value : ''
}

function buildConnection(baseUrlValue: string, tokenValue: string, scopes: string[],
  binding: BindingMetadata | undefined = undefined): MonitorConnection | null {
  const baseUrl: string = normalizeBindingBaseUrlValue(baseUrlValue)
  const token: string = normalizeBindingTokenValue(tokenValue)
  if (baseUrl.length === 0 || token.length === 0) {
    return null
  }
  const connection: MonitorConnection = {
    baseUrl: baseUrl,
    token: token,
    scopes: scopes,
    binding: binding
  }
  return connection
}

function parseJsonPayload(value: string): MonitorConnection | null {
  const source: JsonRecord = StrictJson.parseRecord(value, 'binding')
  if (StrictJson.string(source, 'type', 'binding') !== BINDING_TYPE) {
    return null
  }
  const schemaVersion: number = StrictJson.optionalNumber(source, 'schemaVersion', 1, 'binding')
  if (!Number.isInteger(schemaVersion) || schemaVersion < 1 || schemaVersion > MAX_BINDING_SCHEMA_VERSION) {
    return null
  }
  const scopes: string[] | undefined = normalizeMonitorScopes(StrictJson.strings(source, 'scopes', 'binding'))
  if (scopes === undefined) {
    return null
  }
  const baseUrl: string = StrictJson.string(source, 'baseUrl', 'binding')
  const token: string = StrictJson.string(source, 'token', 'binding')
  if (schemaVersion === 1) {
    return buildConnection(baseUrl, token, scopes)
  }
  const controllerId: string = StrictJson.string(source, 'controllerId', 'binding').trim()
  const controllerName: string = StrictJson.string(source, 'controllerName', 'binding').trim()
  const apiVersion: number = StrictJson.number(source, 'apiVersion', 'binding')
  const capabilities: string[] | undefined = normalizeCapabilities(StrictJson.strings(source, 'capabilities', 'binding'))
  const tokenExpiresAt: string = StrictJson.string(source, 'tokenExpiresAt', 'binding').trim()
  if (!isValidControllerId(controllerId) || controllerName.length === 0 || controllerName.length > 128 ||
    !Number.isInteger(apiVersion) || apiVersion < 1 || capabilities === undefined) {
    return null
  }
  const metadata: BindingMetadata = new BindingMetadata()
  metadata.schemaVersion = schemaVersion
  metadata.controllerId = controllerId
  metadata.controllerName = controllerName
  metadata.apiVersion = apiVersion
  metadata.capabilities = capabilities
  metadata.tokenExpiresAt = tokenExpiresAt
  return buildConnection(baseUrl, token, scopes, metadata)
}

function parseQueryPayload(value: string): MonitorConnection | null {
  const queryIndex: number = value.indexOf('?')
  if (queryIndex < 0) {
    return null
  }
  const params: Record<string, string> = {}
  const parts: string[] = value.substring(queryIndex + 1).split('&')
  for (let index: number = 0; index < parts.length; index++) {
    const separator: number = parts[index].indexOf('=')
    if (separator <= 0) {
      return null
    }
    const key: string = decodeURIComponent(parts[index].substring(0, separator))
    const item: string = decodeURIComponent(parts[index].substring(separator + 1))
    params[key] = item
  }
  if ((params['type'] ?? '') !== BINDING_TYPE) {
    return null
  }
  const schemaVersion: number = Number(params['schemaVersion'] ?? '1')
  if (!Number.isInteger(schemaVersion) || schemaVersion < 1 || schemaVersion > MAX_BINDING_SCHEMA_VERSION) {
    return null
  }
  const scopeText: string = params['scopes'] ?? ''
  const scopeCandidates: string[] = scopeText.length === 0 ? [] : scopeText.split(',')
  const scopes: string[] | undefined = normalizeMonitorScopes(scopeCandidates)
  if (scopes === undefined) {
    return null
  }
  const baseUrl: string = params['baseUrl'] ?? ''
  const token: string = params['token'] ?? ''
  if (schemaVersion === 1) {
    return buildConnection(baseUrl, token, scopes)
  }
  const controllerId: string = (params['controllerId'] ?? '').trim()
  const controllerName: string = (params['controllerName'] ?? '').trim()
  const apiVersion: number = Number(params['apiVersion'] ?? '0')
  const capabilityText: string = params['capabilities'] ?? ''
  const capabilityCandidates: string[] = capabilityText.length === 0 ? [] : capabilityText.split(',')
  const capabilities: string[] | undefined = normalizeCapabilities(capabilityCandidates)
  if (!isValidControllerId(controllerId) || controllerName.length === 0 || controllerName.length > 128 ||
    !Number.isInteger(apiVersion) || apiVersion < 1 || capabilities === undefined) {
    return null
  }
  const metadata: BindingMetadata = new BindingMetadata()
  metadata.schemaVersion = schemaVersion
  metadata.controllerId = controllerId
  metadata.controllerName = controllerName
  metadata.apiVersion = apiVersion
  metadata.capabilities = capabilities
  metadata.tokenExpiresAt = params['tokenExpiresAt'] ?? ''
  return buildConnection(baseUrl, token, scopes, metadata)
}

export function parseBindingPayloadValue(raw: string): MonitorConnection | null {
  const value: string = raw.trim()
  if (value.length === 0) {
    return null
  }
  try {
    return parseJsonPayload(value)
  } catch (_) {
  }
  try {
    return parseQueryPayload(value)
  } catch (_) {
    return null
  }
}

export function bindingMatchesBootstrap(connection: MonitorConnection, bootstrap: ClientBootstrap): boolean {
  const binding: BindingMetadata | undefined = connection.binding
  if (binding === undefined || binding.schemaVersion === 1) {
    return true
  }
  return binding.controllerId === bootstrap.controller.id
}
