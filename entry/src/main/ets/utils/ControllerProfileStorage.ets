import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { ControllerProfile, ControllerProfileDocument } from '../model/ControllerProfileModels'
import { ControllerProfileCodec } from './ControllerProfileCodec'

const PROFILE_STORE_NAME: string = 'xingchenyunxun_controller_profiles'
const PROFILE_DOCUMENT_KEY: string = 'controller_profile_document'
const ACTIVE_PROFILE_ID_KEY: string = 'active_controller_profile_id'

export class ControllerProfileStorage {
  private store: preferences.Preferences | undefined = undefined

  async init(context: common.Context): Promise<boolean> {
    if (this.store !== undefined) {
      return true
    }
    try {
      this.store = await preferences.getPreferences(context, PROFILE_STORE_NAME)
      return true
    } catch (_) {
      this.store = undefined
      return false
    }
  }

  async loadDocument(): Promise<ControllerProfileDocument> {
    const currentStore: preferences.Preferences | undefined = this.store
    if (currentStore === undefined) {
      throw new Error('controller profiles storage is not initialized')
    }
    const raw: string = String(await currentStore.get(PROFILE_DOCUMENT_KEY, ''))
    if (raw.length === 0) {
      return new ControllerProfileDocument()
    }
    return ControllerProfileCodec.decode(raw)
  }

  async saveDocument(document: ControllerProfileDocument): Promise<boolean> {
    const currentStore: preferences.Preferences | undefined = this.store
    if (currentStore === undefined) {
      return false
    }
    const encoded: string = ControllerProfileCodec.encode(document)
    try {
      await currentStore.put(PROFILE_DOCUMENT_KEY, encoded)
      await currentStore.flush()
      const stored: string = String(await currentStore.get(PROFILE_DOCUMENT_KEY, ''))
      ControllerProfileCodec.decode(stored)
      return stored === encoded
    } catch (_) {
      return false
    }
  }

  async listProfiles(): Promise<ControllerProfile[]> {
    const document: ControllerProfileDocument = await this.loadDocument()
    return document.profiles
  }

  async findProfile(profileId: string): Promise<ControllerProfile | undefined> {
    const profiles: ControllerProfile[] = await this.listProfiles()
    for (let index: number = 0; index < profiles.length; index++) {
      if (profiles[index].profileId === profileId) {
        return profiles[index]
      }
    }
    return undefined
  }

  async findProfileByControllerId(controllerId: string): Promise<ControllerProfile | undefined> {
    const profiles: ControllerProfile[] = await this.listProfiles()
    for (let index: number = 0; index < profiles.length; index++) {
      if (profiles[index].controllerId === controllerId) {
        return profiles[index]
      }
    }
    return undefined
  }

  async upsertProfile(profile: ControllerProfile): Promise<boolean> {
    const document: ControllerProfileDocument = await this.loadDocument()
    let replacementIndex: number = -1
    for (let index: number = 0; index < document.profiles.length; index++) {
      const existing: ControllerProfile = document.profiles[index]
      if (existing.profileId === profile.profileId) {
        replacementIndex = index
      } else if (existing.controllerId === profile.controllerId) {
        return false
      }
    }
    if (replacementIndex >= 0) {
      document.profiles[replacementIndex] = profile
    } else {
      document.profiles.push(profile)
    }
    return this.saveDocument(document)
  }

  async removeProfile(profileId: string): Promise<boolean> {
    const document: ControllerProfileDocument = await this.loadDocument()
    const retained: ControllerProfile[] = []
    let removed: boolean = false
    for (let index: number = 0; index < document.profiles.length; index++) {
      if (document.profiles[index].profileId === profileId) {
        removed = true
      } else {
        retained.push(document.profiles[index])
      }
    }
    if (!removed) {
      return true
    }
    document.profiles = retained
    if (!await this.saveDocument(document)) {
      return false
    }
    if (await this.loadActiveProfileId() === profileId) {
      const nextProfileId: string = retained.length > 0 ? retained[0].profileId : ''
      return this.saveActiveProfileId(nextProfileId)
    }
    return true
  }

  async loadActiveProfileId(): Promise<string> {
    const currentStore: preferences.Preferences | undefined = this.store
    if (currentStore === undefined) {
      return ''
    }
    return String(await currentStore.get(ACTIVE_PROFILE_ID_KEY, ''))
  }

  async saveActiveProfileId(profileId: string): Promise<boolean> {
    const currentStore: preferences.Preferences | undefined = this.store
    if (currentStore === undefined) {
      return false
    }
    if (profileId.length > 0 && await this.findProfile(profileId) === undefined) {
      return false
    }
    try {
      await currentStore.put(ACTIVE_PROFILE_ID_KEY, profileId)
      await currentStore.flush()
      return String(await currentStore.get(ACTIVE_PROFILE_ID_KEY, '')) === profileId
    } catch (_) {
      return false
    }
  }
}
