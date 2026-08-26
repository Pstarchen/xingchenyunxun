import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { MonitorConnection } from '../model/MonitorModels'
import { ColorModePreference, ThemeId, ThemeSettings } from '../model/ThemeModels'

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

export interface MonitorSettings {
  autoRefreshEnabled: boolean
  refreshIntervalSeconds: number
  showSensitiveValues: boolean
}

export class MonitorStorage {
  private static instance: MonitorStorage = new MonitorStorage()
  private store: preferences.Preferences | null = null

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
    if (!this.store) {
      return null
    }
    try {
      const baseUrl = String(await this.store.get(BASE_URL_KEY, ''))
      const token = String(await this.store.get(TOKEN_KEY, ''))
      if (!baseUrl || !token) return null
      const scopesValue = String(await this.store.get(SCOPES_KEY, ''))
      const scopes = scopesValue.split('\n').map((value: string) => value.trim()).filter((value: string) => value.length > 0)
      return scopes.length ? { baseUrl, token, scopes } : { baseUrl, token }
    } catch (_) {
      return null
    }
  }

  async saveConnection(connection: MonitorConnection): Promise<void> {
    if (!this.store) {
      return
    }
    try {
      await this.store.put(BASE_URL_KEY, connection.baseUrl)
      await this.store.put(TOKEN_KEY, connection.token)
      await this.store.put(SCOPES_KEY, (connection.scopes ?? []).join('\n'))
      await this.store.flush()
    } catch (_) {
      // Keep the in-memory connection active when persistence is unavailable.
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

  async clearConnection(): Promise<void> {
    if (!this.store) {
      return
    }
    try {
      await this.store.delete(BASE_URL_KEY)
      await this.store.delete(TOKEN_KEY)
      await this.store.delete(SCOPES_KEY)
      await this.store.flush()
    } catch (_) {
      // Clearing local storage is best effort; no credential is sent after unbind.
    }
  }
}
