import { asset } from '@kit.AssetStoreKit'
import { util } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'

const CREDENTIAL_LABEL: string = 'xingchenyunxun-profile-pat'

function encodeText(value: string): Uint8Array {
  const encoder: util.TextEncoder = new util.TextEncoder()
  return encoder.encodeInto(value)
}

function decodeText(value: Uint8Array): string {
  const decoder: util.TextDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true })
  return decoder.decodeToString(value, { stream: false })
}

function assetQuery(alias: string): asset.AssetMap {
  const query: asset.AssetMap = new Map<asset.Tag, asset.Value>()
  query.set(asset.Tag.ALIAS, encodeText(alias))
  query.set(asset.Tag.DATA_LABEL_NORMAL_LOCAL_1, encodeText(CREDENTIAL_LABEL))
  query.set(asset.Tag.SYNC_TYPE, asset.SyncType.NEVER)
  return query
}

export class SecureCredentialStore {
  async saveCredential(alias: string, credential: string): Promise<boolean> {
    const normalizedAlias: string = alias.trim()
    const normalizedCredential: string = credential.trim()
    if (normalizedAlias.length === 0 || normalizedAlias.length > 256 ||
      normalizedCredential.length === 0 || normalizedCredential.length > 1024) {
      return false
    }
    const attributes: asset.AssetMap = new Map<asset.Tag, asset.Value>()
    attributes.set(asset.Tag.SECRET, encodeText(normalizedCredential))
    attributes.set(asset.Tag.ALIAS, encodeText(normalizedAlias))
    attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED)
    attributes.set(asset.Tag.AUTH_TYPE, asset.AuthType.NONE)
    attributes.set(asset.Tag.SYNC_TYPE, asset.SyncType.NEVER)
    // Omitting IS_PERSISTENT keeps credentials uninstall-scoped without requiring a restricted permission.
    attributes.set(asset.Tag.DATA_LABEL_NORMAL_LOCAL_1, encodeText(CREDENTIAL_LABEL))
    attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE)
    try {
      await asset.add(attributes)
      const saved: string = await SecureCredentialStore.loadStoredCredential(normalizedAlias)
      return saved === normalizedCredential
    } catch (_) {
      return false
    }
  }

  async loadCredential(alias: string): Promise<string> {
    const normalizedAlias: string = alias.trim()
    if (normalizedAlias.length === 0 || normalizedAlias.length > 256) {
      return ''
    }
    return SecureCredentialStore.loadStoredCredential(normalizedAlias)
  }

  private static async loadStoredCredential(alias: string): Promise<string> {
    const query: asset.AssetMap = assetQuery(alias)
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL)
    try {
      const results: asset.AssetMap[] = await asset.query(query)
      if (results.length !== 1) {
        return ''
      }
      const secret: asset.Value | undefined = results[0].get(asset.Tag.SECRET)
      if (secret === undefined || !(secret instanceof Uint8Array)) {
        return ''
      }
      return decodeText(secret)
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      if (businessError.code === asset.ErrorCode.NOT_FOUND) {
        return ''
      }
      return ''
    }
  }

  async deleteCredential(alias: string): Promise<boolean> {
    const normalizedAlias: string = alias.trim()
    if (normalizedAlias.length === 0 || normalizedAlias.length > 256) {
      return false
    }
    try {
      await asset.remove(assetQuery(normalizedAlias))
      return true
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      return businessError.code === asset.ErrorCode.NOT_FOUND
    }
  }

  async verifyCredential(alias: string, expectedCredential: string): Promise<boolean> {
    const stored: string = await SecureCredentialStore.loadStoredCredential(alias.trim())
    return stored.length > 0 && stored === expectedCredential.trim()
  }
}
