import { bundleManager } from '@kit.AbilityKit'

export class AppInfo {
  static async getVersionName(): Promise<string> {
    try {
      const bundleInfo: bundleManager.BundleInfo = await bundleManager.getBundleInfoForSelf(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT
      )
      return bundleInfo.versionName
    } catch (_) {
      return '未知'
    }
  }
}
