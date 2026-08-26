import { common } from '@kit.AbilityKit'
import { updateManager } from '@kit.AppGalleryKit'

export enum AppUpdateOutcome {
  BUSY,
  UP_TO_DATE,
  DIALOG_SHOWN,
  DIALOG_FAILED,
  FAILED
}

class AppUpdate {
  private isChecking: boolean = false

  async checkAndShow(context: common.UIAbilityContext): Promise<AppUpdateOutcome> {
    if (this.isChecking) return AppUpdateOutcome.BUSY
    this.isChecking = true
    try {
      const result: updateManager.CheckUpdateResult = await updateManager.checkAppUpdate(context)
      if (result.updateAvailable !== updateManager.UpdateAvailableCode.LATER_VERSION_EXIST) {
        return AppUpdateOutcome.UP_TO_DATE
      }
      const dialogResult: updateManager.ShowUpdateResultCode = await updateManager.showUpdateDialog(context)
      if (dialogResult === updateManager.ShowUpdateResultCode.SHOW_DIALOG_SUCCESS) {
        return AppUpdateOutcome.DIALOG_SHOWN
      }
      return AppUpdateOutcome.DIALOG_FAILED
    } catch (_) {
      return AppUpdateOutcome.FAILED
    } finally {
      this.isChecking = false
    }
  }
}

export const appUpdate: AppUpdate = new AppUpdate()
