import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { detectBarcode, scanBarcode, scanCore } from '@kit.ScanKit'
import { common } from '@kit.AbilityKit'
import { MonitorConnection } from '../model/MonitorModels'
import {
  normalizeBindingBaseUrlValue,
  normalizeBindingTokenValue,
  parseBindingPayloadValue
} from './BindingPayloadParser'

export function normalizeBindingBaseUrl(raw: string): string {
  return normalizeBindingBaseUrlValue(raw)
}

export function normalizeBindingToken(raw: string): string {
  return normalizeBindingTokenValue(raw)
}

export function parseBindingPayload(raw: string): MonitorConnection | null {
  return parseBindingPayloadValue(raw)
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
