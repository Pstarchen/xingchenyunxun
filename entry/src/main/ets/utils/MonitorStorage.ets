import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { LegacyConnectionSnapshot } from '../model/ControllerProfileModels'
import { MonitorConnection } from '../model/MonitorModels'
import { ColorModePreference, ThemeId, ThemeSettings } from '../model/ThemeModels'
import { SecureCredentialStore } from './SecureCredentialStore'

const STORE_NAME: string = 'xingchenyunxun'
const BASE_URL_KEY: string = 'monitor_base_url'
const TOKEN_KEY: string = 'monitor_token'
const SCOPES_KEY: string = 'monitor_scopes'
const AUTO_REFRESH_ENABLED_KEY: string = 'setting_auto_refresh_enabled'
const REFRESH_INTERVAL_SECONDS_KEY: string = 'setting_refresh_interval_seconds'
const SHOW_SENSITIVE_VALUES_KEY: string = 'setting_show_sensitive_values'
const THEME_ID_KEY: string = 'setting_theme_id'
const COLOR_MODE_PREFERENCE_KEY: string = 'setting_color_mode_preference'
const AGREEMENT_VERSION_KEY: string = 'agreement_accepted_version'
const LEGACY_CREDENTIAL_ALIAS: string = 'legacy:active-connection'

export interface MonitorSettings {
  autoRefreshEnabled: boolean
  refreshIntervalSeconds: number
  showSensitiveValues: boolean
}

export class MonitorStorage {
  private static instance: MonitorStorage = new MonitorStorage()
  private store: preferences.Preferences | null = null
  private credentials: SecureCredentialStore = new SecureCredentialStore()

  static getInstance(): MonitorStorage {
    return MonitorStorage.instance
  }

  async init(context: common.Context): Promise<void> {
    if (this.store) {
      return
    }
    try {
      this.store = await preferences.getPreferences(context, STORE_NAME)
    } catch (_) {
      this.store = null
    }
  }

  async loadConnection(): Promise<MonitorConnection | null> {
    const currentStore: preferences.Preferences | null = this.store
    if (currentStore === null) {
      return null
    }
    try {
      const baseUrl: string = String(await currentStore.get(BASE_URL_KEY, ''))
      const storedToken: string = String(await currentStore.get(TOKEN_KEY, ''))
      const token: string = storedToken.length > 0 ? storedToken :
        await this.credentials.loadCredential(LEGACY_CREDENTIAL_ALIAS)
      if (baseUrl.length === 0 || token.length === 0) {
        return null
      }
      const scopesValue: string = String(await currentStore.get(SCOPES_KEY, ''))
      const sourceScopes: string[] = scopesValue.split('\n')
      const scopes: string[] = []
      for (let index: number = 0; index < sourceScopes.length; index++) {
        const scope: string = sourceScopes[index].trim()
        if (scope.length > 0 && scopes.indexOf(scope) < 0) {
          scopes.push(scope)
        }
      }
      const connection: MonitorConnection = { baseUrl: baseUrl, token: token, scopes: scopes }
      return connection
    } catch (_) {
      return null
    }
  }

  async loadLegacyConnectionSnapshot(): Promise<LegacyConnectionSnapshot | undefined> {
    const currentStore: preferences.Preferences | null = this.store
    if (currentStore === null) {
      return undefined
    }
    try {
      const baseUrl: string = String(await currentStore.get(BASE_URL_KEY, ''))
      const storedToken: string = String(await currentStore.get(TOKEN_KEY, ''))
      const token: string = storedToken.length > 0 ? storedToken :
        await this.credentials.loadCredential(LEGACY_CREDENTIAL_ALIAS)
      if (baseUrl.length === 0 || token.length === 0) {
        return undefined
      }
      const scopesValue: string = String(await currentStore.get(SCOPES_KEY, ''))
      const sourceScopes: string[] = scopesValue.split('\n')
      const scopes: string[] = []
      for (let index: number = 0; index < sourceScopes.length; index++) {
        const scope: string = sourceScopes[index].trim()
        if (scope.length > 0 && scopes.indexOf(scope) < 0) {
          scopes.push(scope)
        }
      }
      const snapshot: LegacyConnectionSnapshot = new LegacyConnectionSnapshot()
      snapshot.baseUrl = baseUrl
      snapshot.token = token
      snapshot.scopes = scopes
      return snapshot
    } catch (_) {
      return undefined
    }
  }

  async saveConnection(connection: MonitorConnection): Promise<void> {
    const currentStore: preferences.Preferences | null = this.store
    if (currentStore === null) {
      return
    }
    try {
      if (!await this.credentials.saveCredential(LEGACY_CREDENTIAL_ALIAS, connection.token)) {
        return
      }
      await currentStore.put(BASE_URL_KEY, connection.baseUrl)
      await currentStore.delete(TOKEN_KEY)
      await currentStore.put(SCOPES_KEY, (connection.scopes ?? []).join('\n'))
      await currentStore.flush()
    } catch (_) {
    }
  }

  async loadSettings(): Promise<MonitorSettings> {
    const defaults: MonitorSettings = {
      autoRefreshEnabled: true,
      refreshIntervalSeconds: 30,
      showSensitiveValues: false
    }
    if (!this.store) return defaults
    try {
      const storedInterval = Number(await this.store.get(REFRESH_INTERVAL_SECONDS_KEY, defaults.refreshIntervalSeconds))
      const refreshIntervalSeconds = storedInterval === 15 || storedInterval === 30 || storedInterval === 60 || storedInterval === 300
        ? storedInterval
        : defaults.refreshIntervalSeconds
      const settings: MonitorSettings = {
        autoRefreshEnabled: Boolean(await this.store.get(AUTO_REFRESH_ENABLED_KEY, defaults.autoRefreshEnabled)),
        refreshIntervalSeconds,
        showSensitiveValues: Boolean(await this.store.get(SHOW_SENSITIVE_VALUES_KEY, defaults.showSensitiveValues))
      }
      return settings
    } catch (_) {
      return defaults
    }
  }

  async saveSettings(settings: MonitorSettings): Promise<void> {
    if (!this.store) return
    try {
      await this.store.put(AUTO_REFRESH_ENABLED_KEY, settings.autoRefreshEnabled)
      await this.store.put(REFRESH_INTERVAL_SECONDS_KEY, settings.refreshIntervalSeconds)
      await this.store.put(SHOW_SENSITIVE_VALUES_KEY, settings.showSensitiveValues)
      await this.store.flush()
    } catch (_) {
    }
  }

  async loadThemeSettings(): Promise<ThemeSettings> {
    const defaults: ThemeSettings = {
      themeId: 'gold',
      colorModePreference: 'SYSTEM'
    }
    if (!this.store) return defaults
    try {
      const storedThemeId = String(await this.store.get(THEME_ID_KEY, defaults.themeId))
      const storedMode = String(await this.store.get(COLOR_MODE_PREFERENCE_KEY, defaults.colorModePreference))
      const themeId: ThemeId = storedThemeId === 'ocean' || storedThemeId === 'forest' ? storedThemeId : defaults.themeId
      const colorModePreference: ColorModePreference = storedMode === 'LIGHT' || storedMode === 'DARK' ? storedMode : defaults.colorModePreference
      return { themeId, colorModePreference }
    } catch (_) {
      return defaults
    }
  }

  async saveThemeSettings(settings: ThemeSettings): Promise<void> {
    if (!this.store) return
    try {
      await this.store.put(THEME_ID_KEY, settings.themeId)
      await this.store.put(COLOR_MODE_PREFERENCE_KEY, settings.colorModePreference)
      await this.store.flush()
    } catch (_) {
    }
  }

  async loadAgreementVersion(): Promise<string> {
    if (!this.store) return ''
    try {
      return String(await this.store.get(AGREEMENT_VERSION_KEY, ''))
    } catch (_) {
      return ''
    }
  }

  async saveAgreementVersion(version: string): Promise<boolean> {
    if (!this.store) return false
    try {
      await this.store.put(AGREEMENT_VERSION_KEY, version)
      await this.store.flush()
      return String(await this.store.get(AGREEMENT_VERSION_KEY, '')) === version
    } catch (_) {
      return false
    }
  }

  async clearConnection(): Promise<boolean> {
    const currentStore: preferences.Preferences | null = this.store
    if (currentStore === null) {
      return false
    }
    try {
      const credentialCleared: boolean = await this.credentials.deleteCredential(LEGACY_CREDENTIAL_ALIAS)
      await currentStore.delete(BASE_URL_KEY)
      await currentStore.delete(TOKEN_KEY)
      await currentStore.delete(SCOPES_KEY)
      await currentStore.flush()
      const preferencesCleared: boolean = (await currentStore.get(BASE_URL_KEY, '')) === '' &&
        (await currentStore.get(TOKEN_KEY, '')) === '' && (await currentStore.get(SCOPES_KEY, '')) === ''
      return credentialCleared && preferencesCleared
    } catch (_) {
      return false
    }
  }
}
