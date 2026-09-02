import { AlertV2Severity } from './AlertModels'

export class MobileInstallation {
  id: string = ''
  clientInstallationId: string = ''
  platform: string = 'HARMONYOS'
  tokenSuffix: string = ''
  appVersion: string = ''
  deviceModel: string = ''
  deviceIds: string[] = []
  minimumSeverity: AlertV2Severity = 'WARNING'
  enabled: boolean = false
  lastRegisteredAt: string = ''
  createdAt: string = ''
  updatedAt: string = ''
}

export class CreateMobileInstallationRequest {
  clientInstallationId: string = ''
  platform: string = 'HARMONYOS'
  token: string = ''
  appVersion: string = ''
  deviceModel: string = ''
  deviceIds: string[] = []
  minimumSeverity: AlertV2Severity = 'WARNING'
}

export class UpdatePushTokenRequest {
  token: string = ''
  appVersion: string = ''
}

export class UpdateNotificationPreferencesRequest {
  enabled: boolean = false
  minimumSeverity: AlertV2Severity = 'WARNING'
  deviceIds: string[] = []
}

export class TestNotificationDelivery {
  status: string = ''
  deliveryId: number = 0
  message: string = ''
}
