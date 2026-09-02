export const CONTROLLER_PROFILE_SCHEMA_VERSION: number = 1

export class BindingMetadata {
  schemaVersion: number = 1
  controllerId: string = ''
  controllerName: string = ''
  apiVersion: number = 1
  capabilities: string[] = []
  tokenExpiresAt: string = ''
}

export class ControllerProfile {
  profileId: string = ''
  controllerId: string = ''
  controllerName: string = ''
  baseUrl: string = ''
  canonicalEntry: string = ''
  apiVersion: number = 1
  capabilities: string[] = []
  tokenId: string = ''
  tokenPrefix: string = ''
  tokenExpiresAt: string = ''
  scopes: string[] = []
  credentialAlias: string = ''
  installationId: string = ''
  lastEventId: string = ''
  lastReadAlertId: number = 0
  pushEnabled: boolean = false
  createdAt: string = ''
  updatedAt: string = ''
}

export class ControllerProfileDocument {
  schemaVersion: number = CONTROLLER_PROFILE_SCHEMA_VERSION
  profiles: ControllerProfile[] = []
}

export class LegacyConnectionSnapshot {
  baseUrl: string = ''
  token: string = ''
  scopes: string[] = []
}

export type LegacyMigrationState = 'NOT_NEEDED' | 'MIGRATED' | 'RETRY_REQUIRED'

export class LegacyMigrationResult {
  state: LegacyMigrationState = 'NOT_NEEDED'
  profile: ControllerProfile | undefined = undefined
  message: string = ''
}
