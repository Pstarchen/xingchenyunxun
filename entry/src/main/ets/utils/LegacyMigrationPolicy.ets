import { ClientBootstrap } from '../model/BootstrapModels'
import { ControllerProfile, LegacyConnectionSnapshot } from '../model/ControllerProfileModels'
import { normalizeBindingBaseUrlValue } from './BindingPayloadParser'
import { normalizeCapabilities, normalizeMonitorScopes } from './ScopePolicy'

export class LegacyMigrationPolicy {
  static createProfile(snapshot: LegacyConnectionSnapshot, bootstrap: ClientBootstrap, profileId: string,
    credentialAlias: string, timestamp: string): ControllerProfile {
    const normalizedBaseUrl: string = normalizeBindingBaseUrlValue(snapshot.baseUrl)
    const scopes: string[] | undefined = normalizeMonitorScopes(bootstrap.principal.scopes)
    const capabilities: string[] | undefined = normalizeCapabilities(bootstrap.capabilities)
    if (normalizedBaseUrl.length === 0 || scopes === undefined || scopes.length === 0 || capabilities === undefined) {
      throw new Error('legacy migration: invalid verified connection')
    }
    const profile: ControllerProfile = new ControllerProfile()
    profile.profileId = profileId
    profile.controllerId = bootstrap.controller.id
    profile.controllerName = bootstrap.controller.name
    profile.baseUrl = normalizedBaseUrl
    profile.canonicalEntry = bootstrap.controller.canonicalEntry
    profile.apiVersion = bootstrap.server.apiVersion
    profile.capabilities = capabilities
    profile.tokenId = bootstrap.principal.tokenId
    profile.tokenPrefix = bootstrap.principal.tokenPrefix
    profile.tokenExpiresAt = bootstrap.principal.expiresAt
    profile.scopes = scopes
    profile.credentialAlias = credentialAlias
    profile.createdAt = timestamp
    profile.updatedAt = timestamp
    return profile
  }

  static canResume(profile: ControllerProfile, bootstrap: ClientBootstrap, snapshot: LegacyConnectionSnapshot): boolean {
    return profile.controllerId === bootstrap.controller.id &&
      profile.baseUrl === normalizeBindingBaseUrlValue(snapshot.baseUrl) && profile.credentialAlias.length > 0
  }
}
