import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { detectBarcode, scanBarcode, scanCore } from '@kit.ScanKit'
import { common } from '@kit.AbilityKit'
import { MonitorConnection } from '../model/MonitorModels'

const BINDING_TYPE: string = 'xingchenyunxun-bind'

export function normalizeBindingBaseUrl(raw: string): string {
  const value = raw.trim()
  const match = /^(https?):\/\/([^\/?#\s]+)(\/[^?#\s]*)?(?:[?#].*)?$/i.exec(value)
  if (!match || match[2].includes('@')) return ''
  const path = (match[3] ?? '').replace(/\/+$/, '')
  return `${match[1].toLowerCase()}://${match[2]}${path}`
}

export function normalizeBindingToken(raw: string): string {
  const value = raw.trim()
  return /^nzp_[A-Za-z0-9_-]+$/.test(value) ? value : ''
}

function scopesFromValue(value: Object | undefined): string[] {
  if (!value || !Array.isArray(value)) return []
  return (value as Array<Object>)
    .map((item: Object) => String(item).trim())
    .filter((item: string) => /^nezha:[a-z][a-z0-9-]*:(read|write|delete|exec|\*)$/.test(item) || item === 'nezha:*')
}

function buildConnection(baseUrlValue: string, tokenValue: string, scopes: string[] = []): MonitorConnection | null {
  const baseUrl = normalizeBindingBaseUrl(baseUrlValue)
  const token = normalizeBindingToken(tokenValue)
  if (!baseUrl || !token) return null
  return scopes.length ? { baseUrl, token, scopes } : { baseUrl, token }
}

export function parseBindingPayload(raw: string): MonitorConnection | null {
  const value = raw.trim()
  if (!value) {
    return null
  }
  try {
    const parsed = JSON.parse(value) as Record<string, Object>
    const type = String(parsed['type'] ?? '')
    if (type && type !== BINDING_TYPE) return null
    const baseUrl = String(parsed['baseUrl'] ?? parsed['url'] ?? '')
    const token = String(parsed['token'] ?? parsed['pat'] ?? parsed['secret'] ?? '')
    const scopes = scopesFromValue(parsed['scopes'])
    const connection = buildConnection(baseUrl, token, scopes)
    if (connection) return connection
  } catch (_) {
    // QR payload may be a URL-like xingchen://bind string.
  }

  try {
    const queryIndex = value.indexOf('?')
    if (queryIndex >= 0) {
      const params: Record<string, string> = {}
      value.substring(queryIndex + 1).split('&').forEach((part: string) => {
        const separator = part.indexOf('=')
        if (separator <= 0) return
        const key = decodeURIComponent(part.substring(0, separator))
        const item = decodeURIComponent(part.substring(separator + 1))
        params[key] = item
      })
      const type = params['type'] ?? ''
      if (type && type !== BINDING_TYPE) return null
      const baseUrl = params['baseUrl'] ?? params['url'] ?? ''
      const token = params['token'] ?? params['pat'] ?? params['secret'] ?? ''
      const scopes = (params['scopes'] ?? '').split(',').map((item: string) => item.trim()).filter((item: string) => item.length > 0)
      return buildConnection(baseUrl, token, scopes)
    }
  } catch (_) {
    return null
  }
  return null
}

export async function chooseBindingQr(context: common.Context, useCamera: boolean = true): Promise<MonitorConnection | null> {
  const scanOptions: scanBarcode.ScanOptions = {
    scanTypes: [scanCore.ScanType.QR_CODE],
    enableMultiMode: false,
    enableAlbum: true
  }
  if (useCamera) {
    try {
      const scanResult = await scanBarcode.startScanForResult(context, scanOptions)
      const livePayload = parseBindingPayload(scanResult.originalValue)
      if (livePayload) return livePayload
    } catch (_) {
      // Fall back to an image from the album when live scanning is unavailable.
    }
  }

  try {
    const picker = new photoAccessHelper.PhotoViewPicker()
    const result = await picker.select({
      MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
      maxSelectNumber: 1
    })
    const uri = result.photoUris[0]
    if (!uri) return null
    const inputImage: detectBarcode.InputImage = { uri }
    const decoded: Array<scanBarcode.ScanResult> = await detectBarcode.decode(inputImage, scanOptions)
    if (!decoded.length) return null
    return parseBindingPayload(decoded[0].originalValue)
  } catch (_) {
    return null
  }
}
