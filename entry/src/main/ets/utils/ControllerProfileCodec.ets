import {
  CONTROLLER_PROFILE_SCHEMA_VERSION,
  ControllerProfile,
  ControllerProfileDocument
} from '../model/ControllerProfileModels'
import { isValidCapability, isValidControllerId, normalizeCapabilities, normalizeMonitorScopes } from './ScopePolicy'
import { normalizeBindingBaseUrlValue } from './BindingPayloadParser'
import { JsonRecord, StrictJson } from './StrictJson'

const PROFILE_ID_PATTERN: RegExp = new RegExp('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$')
const ALIAS_PATTERN: RegExp = new RegExp('^[A-Za-z0-9._:-]{8,256}$')

function parseProfile(source: JsonRecord, context: string): ControllerProfile {
  const profile: ControllerProfile = new ControllerProfile()
  profile.profileId = StrictJson.string(source, 'profileId', context).trim()
  profile.controllerId = StrictJson.string(source, 'controllerId', context).trim()
  profile.controllerName = StrictJson.string(source, 'controllerName', context).trim()
  profile.baseUrl = StrictJson.string(source, 'baseUrl', context).trim()
  profile.canonicalEntry = StrictJson.string(source, 'canonicalEntry', context).trim()
  profile.apiVersion = StrictJson.number(source, 'apiVersion', context)
  profile.capabilities = StrictJson.strings(source, 'capabilities', context)
  profile.tokenId = StrictJson.optionalString(source, 'tokenId', context).trim()
  profile.tokenPrefix = StrictJson.optionalString(source, 'tokenPrefix', context).trim()
  profile.tokenExpiresAt = StrictJson.optionalString(source, 'tokenExpiresAt', context).trim()
  profile.scopes = StrictJson.strings(source, 'scopes', context)
  profile.credentialAlias = StrictJson.string(source, 'credentialAlias', context).trim()
  profile.installationId = StrictJson.optionalString(source, 'installationId', context).trim()
  profile.lastEventId = StrictJson.optionalString(source, 'lastEventId', context).trim()
  profile.lastReadAlertId = StrictJson.optionalNumber(source, 'lastReadAlertId', 0, context)
  profile.pushEnabled = StrictJson.optionalBoolean(source, 'pushEnabled', false, context)
  profile.createdAt = StrictJson.string(source, 'createdAt', context).trim()
  profile.updatedAt = StrictJson.string(source, 'updatedAt', context).trim()
  if (!isValidControllerProfile(profile)) {
    throw new Error(`${context}: invalid controller profile`)
  }
  const capabilities: string[] | undefined = normalizeCapabilities(profile.capabilities)
  const scopes: string[] | undefined = normalizeMonitorScopes(profile.scopes)
  if (capabilities === undefined || scopes === undefined) {
    throw new Error(`${context}: invalid policy metadata`)
  }
  profile.capabilities = capabilities
  profile.scopes = scopes
  return profile
}

export function isValidControllerProfile(profile: ControllerProfile): boolean {
  if (!PROFILE_ID_PATTERN.test(profile.profileId) || !isValidControllerId(profile.controllerId)) {
    return false
  }
  if (profile.controllerName.length === 0 || profile.controllerName.length > 128 ||
    normalizeBindingBaseUrlValue(profile.baseUrl) !== profile.baseUrl ||
    profile.canonicalEntry.length === 0 || !Number.isInteger(profile.apiVersion) || profile.apiVersion < 1) {
    return false
  }
  if (!ALIAS_PATTERN.test(profile.credentialAlias) ||
    profile.lastEventId.length > 0 && !isValidControllerId(profile.lastEventId) ||
    !Number.isSafeInteger(profile.lastReadAlertId) || profile.lastReadAlertId < 0) {
    return false
  }
  if (profile.createdAt.length === 0 || profile.updatedAt.length === 0) {
    return false
  }
  for (let index: number = 0; index < profile.capabilities.length; index++) {
    if (!isValidCapability(profile.capabilities[index])) {
      return false
    }
  }
  return normalizeMonitorScopes(profile.scopes) !== undefined
}

export class ControllerProfileCodec {
  static encode(document: ControllerProfileDocument): string {
    if (document.schemaVersion !== CONTROLLER_PROFILE_SCHEMA_VERSION) {
      throw new Error('profiles: unsupported schema version')
    }
    const profileIds: string[] = []
    const controllerIds: string[] = []
    for (let index: number = 0; index < document.profiles.length; index++) {
      if (!isValidControllerProfile(document.profiles[index])) {
        throw new Error(`profiles[${index}]: invalid controller profile`)
      }
      if (profileIds.indexOf(document.profiles[index].profileId) >= 0 ||
        controllerIds.indexOf(document.profiles[index].controllerId) >= 0) {
        throw new Error(`profiles[${index}]: duplicate identity`)
      }
      profileIds.push(document.profiles[index].profileId)
      controllerIds.push(document.profiles[index].controllerId)
    }
    return JSON.stringify(document)
  }

  static decode(raw: string): ControllerProfileDocument {
    const source: JsonRecord = StrictJson.parseRecord(raw, 'profiles')
    const schemaVersion: number = StrictJson.number(source, 'schemaVersion', 'profiles')
    if (schemaVersion !== CONTROLLER_PROFILE_SCHEMA_VERSION) {
      throw new Error('profiles.schemaVersion: unsupported schema version')
    }
    const records: JsonRecord[] = StrictJson.records(source, 'profiles', 'profiles')
    const document: ControllerProfileDocument = new ControllerProfileDocument()
    const profileIds: string[] = []
    const controllerIds: string[] = []
    for (let index: number = 0; index < records.length; index++) {
      const profile: ControllerProfile = parseProfile(records[index], `profiles.profiles[${index}]`)
      if (profileIds.indexOf(profile.profileId) >= 0 || controllerIds.indexOf(profile.controllerId) >= 0) {
        throw new Error(`profiles.profiles[${index}]: duplicate identity`)
      }
      profileIds.push(profile.profileId)
      controllerIds.push(profile.controllerId)
      document.profiles.push(profile)
    }
    return document
  }
}
