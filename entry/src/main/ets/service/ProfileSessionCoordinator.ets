import { common } from '@kit.AbilityKit'
import { ClientBootstrap } from '../model/BootstrapModels'
import {
  ControllerProfile,
  LegacyMigrationState
} from '../model/ControllerProfileModels'
import { MonitorConnection } from '../model/MonitorModels'
import { LegacyProfileMigrator } from './LegacyProfileMigrator'
import { ControllerProfileStorage } from '../utils/ControllerProfileStorage'
import { MonitorStorage } from '../utils/MonitorStorage'
import { SecureCredentialStore } from '../utils/SecureCredentialStore'
import { bindingMatchesBootstrap, normalizeBindingTokenValue } from '../utils/BindingPayloadParser'

export class ProfileSessionSnapshot {
  profiles: ControllerProfile[] = []
  activeProfile: ControllerProfile | undefined = undefined
  connection: MonitorConnection | undefined = undefined
  migrationState: LegacyMigrationState = 'NOT_NEEDED'
  message: string = ''
}

export class ProfileSessionCoordinator {
  private legacyStorage: MonitorStorage
  private profileStorage: ControllerProfileStorage
  private credentials: SecureCredentialStore
  private migrator: LegacyProfileMigrator
  private activeProfileId: string = ''
  private cachedSnapshot: ProfileSessionSnapshot | undefined = undefined
  private initializing: Promise<ProfileSessionSnapshot> | undefined = undefined

  private static sharedCoordinator: ProfileSessionCoordinator | undefined = undefined

  static shared(): ProfileSessionCoordinator {
    if (ProfileSessionCoordinator.sharedCoordinator === undefined) {
      ProfileSessionCoordinator.sharedCoordinator = new ProfileSessionCoordinator(
        MonitorStorage.getInstance(), new ControllerProfileStorage(), new SecureCredentialStore())
    }
    return ProfileSessionCoordinator.sharedCoordinator
  }

  constructor(legacyStorage: MonitorStorage, profileStorage: ControllerProfileStorage,
    credentials: SecureCredentialStore) {
    this.legacyStorage = legacyStorage
    this.profileStorage = profileStorage
    this.credentials = credentials
    this.migrator = new LegacyProfileMigrator(legacyStorage, profileStorage, credentials)
  }

  async initialize(context: common.Context): Promise<ProfileSessionSnapshot> {
    if (this.cachedSnapshot !== undefined) {
      return this.cachedSnapshot
    }
    if (this.initializing !== undefined) {
      return this.initializing
    }
    const pending: Promise<ProfileSessionSnapshot> = this.initializeInternal(context)
    this.initializing = pending
    try {
      const snapshot: ProfileSessionSnapshot = await pending
      this.cachedSnapshot = snapshot
      return snapshot
    } finally {
      this.initializing = undefined
    }
  }

  private async initializeInternal(context: common.Context): Promise<ProfileSessionSnapshot> {
    const snapshot: ProfileSessionSnapshot = new ProfileSessionSnapshot()
    await this.legacyStorage.init(context)
    if (!await this.profileStorage.init(context)) {
      snapshot.message = '监控空间本地存储初始化失败'
      return snapshot
    }
    let profiles: ControllerProfile[] = []
    try {
      profiles = await this.profileStorage.listProfiles()
      this.activeProfileId = await this.profileStorage.loadActiveProfileId()
    } catch (_) {
      snapshot.message = '监控空间配置读取失败'
      return snapshot
    }
    if (profiles.length === 0) {
      const migration = await this.migrator.migrate()
      snapshot.migrationState = migration.state
      snapshot.message = migration.message
      try {
        profiles = await this.profileStorage.listProfiles()
        this.activeProfileId = await this.profileStorage.loadActiveProfileId()
      } catch (_) {
        snapshot.message = '迁移后的监控空间配置读取失败'
      }
    }
    if (profiles.length > 0 && this.findProfile(profiles, this.activeProfileId) === undefined) {
      this.activeProfileId = profiles[0].profileId
      await this.profileStorage.saveActiveProfileId(this.activeProfileId)
    }
    snapshot.profiles = profiles
    const activeProfile: ControllerProfile | undefined = this.findProfile(profiles, this.activeProfileId)
    snapshot.activeProfile = activeProfile
    if (activeProfile !== undefined) {
      snapshot.connection = await this.connectionForProfile(activeProfile)
      if (snapshot.connection === undefined && snapshot.message.length === 0) {
        snapshot.message = '当前监控空间的安全凭据不可用，请重新绑定'
      }
    }
    return snapshot
  }

  async connect(connection: MonitorConnection, bootstrap: ClientBootstrap): Promise<ControllerProfile | undefined> {
    if (!bindingMatchesBootstrap(connection, bootstrap)) {
      return undefined
    }
    const controllerId: string = bootstrap.controller.id
    const existing: ControllerProfile | undefined = await this.profileStorage.findProfileByControllerId(controllerId)
    const profile: ControllerProfile = existing === undefined ? new ControllerProfile() : existing
    const timestamp: string = new Date().toISOString()
    const alias: string = existing?.credentialAlias ?? `profile:${controllerId}`
    profile.profileId = controllerId
    profile.controllerId = controllerId
    profile.controllerName = bootstrap.controller.name
    profile.baseUrl = connection.baseUrl
    profile.canonicalEntry = bootstrap.controller.canonicalEntry.length > 0
      ? bootstrap.controller.canonicalEntry : connection.baseUrl
    profile.apiVersion = bootstrap.server.apiVersion
    profile.capabilities = bootstrap.capabilities.slice()
    profile.tokenId = bootstrap.principal.tokenId
    profile.tokenPrefix = bootstrap.principal.tokenPrefix
    profile.tokenExpiresAt = bootstrap.principal.expiresAt
    profile.scopes = bootstrap.principal.scopes.slice()
    profile.credentialAlias = alias
    profile.createdAt = existing?.createdAt ?? timestamp
    profile.updatedAt = timestamp
    if (!await this.credentials.saveCredential(alias, connection.token)) {
      return undefined
    }
    if (!await this.profileStorage.upsertProfile(profile)) {
      return undefined
    }
    if (!await this.profileStorage.saveActiveProfileId(profile.profileId)) {
      return undefined
    }
    this.activeProfileId = profile.profileId
    this.cachedSnapshot = undefined
    await this.legacyStorage.clearConnection()
    return profile
  }

  async activeConnection(): Promise<MonitorConnection | undefined> {
    const profile: ControllerProfile | undefined = await this.profileStorage.findProfile(this.activeProfileId)
    if (profile === undefined) {
      return undefined
    }
    return this.connectionForProfile(profile)
  }

  async switchProfile(profileId: string): Promise<MonitorConnection | undefined> {
    const profile: ControllerProfile | undefined = await this.profileStorage.findProfile(profileId)
    if (profile === undefined) {
      return undefined
    }
    const connection: MonitorConnection | undefined = await this.connectionForProfile(profile)
    if (connection === undefined || !await this.profileStorage.saveActiveProfileId(profileId)) {
      return undefined
    }
    this.activeProfileId = profileId
    this.cachedSnapshot = undefined
    return connection
  }

  async removeProfile(profileId: string): Promise<boolean> {
    const profile: ControllerProfile | undefined = await this.profileStorage.findProfile(profileId)
    if (profile === undefined) {
      return true
    }
    if (!await this.credentials.deleteCredential(profile.credentialAlias)) {
      return false
    }
    const removed: boolean = await this.profileStorage.removeProfile(profileId)
    if (removed && this.activeProfileId === profileId) {
      this.activeProfileId = await this.profileStorage.loadActiveProfileId()
    }
    if (removed) {
      this.cachedSnapshot = undefined
    }
    return removed
  }

  async listProfiles(): Promise<ControllerProfile[]> {
    return this.profileStorage.listProfiles()
  }

  getActiveProfileId(): string {
    return this.activeProfileId
  }

  private async connectionForProfile(profile: ControllerProfile): Promise<MonitorConnection | undefined> {
    const token: string = normalizeBindingTokenValue(await this.credentials.loadCredential(profile.credentialAlias))
    if (token.length === 0) {
      return undefined
    }
    const connection: MonitorConnection = {
      baseUrl: profile.baseUrl,
      token: token,
      scopes: profile.scopes.slice()
    }
    return connection
  }

  private findProfile(profiles: ControllerProfile[], profileId: string): ControllerProfile | undefined {
    for (let index: number = 0; index < profiles.length; index++) {
      if (profiles[index].profileId === profileId) {
        return profiles[index]
      }
    }
    return undefined
  }
}
