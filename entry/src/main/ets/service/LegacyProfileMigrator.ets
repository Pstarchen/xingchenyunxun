import { LegacyMigrationResult, LegacyMigrationState, ControllerProfile, LegacyConnectionSnapshot } from '../model/ControllerProfileModels'
import { MonitorStorage } from '../utils/MonitorStorage'
import { ControllerProfileStorage } from '../utils/ControllerProfileStorage'
import { SecureCredentialStore } from '../utils/SecureCredentialStore'
import { LegacyMigrationPolicy } from '../utils/LegacyMigrationPolicy'
import { MonitorApi } from '../utils/MonitorApi'
import { MonitorRepository } from './MonitorRepository'
import { MonitorConnection } from '../model/MonitorModels'

export class LegacyProfileMigrator {
  private legacyStorage: MonitorStorage
  private profiles: ControllerProfileStorage
  private credentials: SecureCredentialStore

  constructor(legacyStorage: MonitorStorage, profiles: ControllerProfileStorage,
    credentials: SecureCredentialStore) {
    this.legacyStorage = legacyStorage
    this.profiles = profiles
    this.credentials = credentials
  }

  async migrate(): Promise<LegacyMigrationResult> {
    const snapshot: LegacyConnectionSnapshot | undefined = await this.legacyStorage.loadLegacyConnectionSnapshot()
    if (snapshot === undefined) {
      return this.result('NOT_NEEDED', undefined, '')
    }
    try {
      const connection: MonitorConnection = {
        baseUrl: snapshot.baseUrl,
        token: snapshot.token,
        scopes: snapshot.scopes
      }
      const repository: MonitorRepository = new MonitorRepository(new MonitorApi(connection))
      const bootstrap = await repository.bootstrap()
      const profileId: string = bootstrap.controller.id
      const alias: string = `profile:${profileId}`
      const existing: ControllerProfile | undefined = await this.profiles.findProfile(profileId)
      if (existing !== undefined && LegacyMigrationPolicy.canResume(existing, bootstrap, snapshot) &&
        await this.credentials.verifyCredential(alias, snapshot.token)) {
        await this.activateAndClear(profileId)
        return this.result('MIGRATED', existing, '旧连接已完成迁移')
      }
      if (!await this.credentials.saveCredential(alias, snapshot.token)) {
        return this.result('RETRY_REQUIRED', undefined, '安全凭据写入失败，请重试迁移')
      }
      const profile: ControllerProfile = LegacyMigrationPolicy.createProfile(snapshot, bootstrap, profileId, alias,
        new Date().toISOString())
      if (!await this.profiles.upsertProfile(profile)) {
        return this.result('RETRY_REQUIRED', undefined, '监控 profile 保存失败，请重试迁移')
      }
      const saved: ControllerProfile | undefined = await this.profiles.findProfile(profileId)
      if (saved === undefined || !LegacyMigrationPolicy.canResume(saved, bootstrap, snapshot) ||
        !await this.credentials.verifyCredential(alias, snapshot.token)) {
        return this.result('RETRY_REQUIRED', undefined, '迁移校验失败，旧连接仍被保留')
      }
      if (!await this.activateAndClear(profileId)) {
        return this.result('RETRY_REQUIRED', saved, '迁移激活或旧连接清理失败，请重试')
      }
      return this.result('MIGRATED', saved, '旧连接已迁移到安全 profile')
    } catch (_) {
      return this.result('RETRY_REQUIRED', undefined, '旧连接迁移失败，请检查连接后重试')
    }
  }

  private async activateAndClear(profileId: string): Promise<boolean> {
    if (!await this.profiles.saveActiveProfileId(profileId)) {
      return false
    }
    if (!await this.legacyStorage.clearConnection()) {
      return false
    }
    return (await this.legacyStorage.loadLegacyConnectionSnapshot()) === undefined
  }

  private result(state: LegacyMigrationState, profile: ControllerProfile | undefined,
    message: string): LegacyMigrationResult {
    const result: LegacyMigrationResult = new LegacyMigrationResult()
    result.state = state
    result.profile = profile
    result.message = message
    return result
  }
}
