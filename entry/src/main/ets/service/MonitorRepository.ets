import { AlertQuery, AlertV2Item, AlertV2Page, AlertV2Summary, BulkAcknowledgeRequest, BulkAcknowledgeResult } from '../model/AlertModels'
import { ClientBootstrap } from '../model/BootstrapModels'
import { DeviceDiagnostics, MetricHistoryRange, MetricHistoryResponse } from '../model/DiagnosticModels'
import {
  CreateMobileInstallationRequest,
  MobileInstallation,
  TestNotificationDelivery,
  UpdateNotificationPreferencesRequest,
  UpdatePushTokenRequest
} from '../model/NotificationModels'
import { RealtimeEnvelope, RealtimeTicket } from '../model/RealtimeModels'
import { MonitorApi } from '../utils/MonitorApi'
import { MonitorResponseParser } from './MonitorResponseParser'

export class MonitorRepository {
  private api: MonitorApi

  constructor(api: MonitorApi) {
    this.api = api
  }

  async bootstrap(): Promise<ClientBootstrap> {
    return MonitorResponseParser.bootstrap(await this.api.getJson('/client/bootstrap'))
  }

  async diagnostics(deviceId: string): Promise<DeviceDiagnostics> {
    const path: string = `/v2/devices/${encodeURIComponent(deviceId)}/diagnostics`
    return MonitorResponseParser.diagnostics(await this.api.getJson(path))
  }

  async history(deviceId: string, range: MetricHistoryRange): Promise<MetricHistoryResponse> {
    const path: string = `/v2/devices/${encodeURIComponent(deviceId)}/metrics/history?range=${encodeURIComponent(range)}`
    return MonitorResponseParser.history(await this.api.getJson(path))
  }

  async alerts(query: AlertQuery): Promise<AlertV2Page> {
    return MonitorResponseParser.alertPage(await this.api.getJson(this.alertQueryPath(query)))
  }

  async alert(alertId: number): Promise<AlertV2Item> {
    return MonitorResponseParser.alert(await this.api.getJson(`/v2/alerts/${alertId}`))
  }

  async alertSummary(lastReadAlertId: number): Promise<AlertV2Summary> {
    const path: string = `/v2/alerts/summary?lastReadAlertId=${encodeURIComponent(String(Math.max(0, lastReadAlertId)))}`
    return MonitorResponseParser.alertSummary(await this.api.getJson(path))
  }

  async acknowledgeAlerts(ids: number[]): Promise<BulkAcknowledgeResult> {
    const request: BulkAcknowledgeRequest = new BulkAcknowledgeRequest()
    request.ids = ids
    return MonitorResponseParser.bulkAcknowledge(
      await this.api.postJson('/v2/alerts/acknowledge', request))
  }

  async realtimeTicket(afterEventId: string): Promise<RealtimeTicket> {
    const cursor: string = afterEventId.trim()
    const suffix: string = cursor.length === 0 ? '' : `?afterEventId=${encodeURIComponent(cursor)}`
    const path: string = `/realtime/tickets${suffix}`
    return MonitorResponseParser.realtimeTicket(await this.api.postJson(path))
  }

  async parseRealtimeEnvelope(raw: string): Promise<RealtimeEnvelope> {
    return Promise.resolve(MonitorResponseParser.realtimeEnvelope(raw))
  }

  async installations(): Promise<MobileInstallation[]> {
    return MonitorResponseParser.installations(await this.api.getJson('/mobile/installations'))
  }

  async createInstallation(request: CreateMobileInstallationRequest): Promise<MobileInstallation> {
    return MonitorResponseParser.installation(await this.api.postJson('/mobile/installations', request))
  }

  async updatePushToken(installationId: string, request: UpdatePushTokenRequest): Promise<MobileInstallation> {
    const path: string = `/mobile/installations/${encodeURIComponent(installationId)}/token`
    return MonitorResponseParser.installation(await this.api.putJson(path, request))
  }

  async updateNotificationPreferences(installationId: string,
    request: UpdateNotificationPreferencesRequest): Promise<MobileInstallation> {
    const path: string = `/mobile/installations/${encodeURIComponent(installationId)}/preferences`
    return MonitorResponseParser.installation(await this.api.putJson(path, request))
  }

  async deleteInstallation(installationId: string): Promise<void> {
    await this.api.deleteJson(`/mobile/installations/${encodeURIComponent(installationId)}`)
  }

  async testInstallation(installationId: string): Promise<TestNotificationDelivery> {
    const path: string = `/mobile/installations/${encodeURIComponent(installationId)}/test`
    return MonitorResponseParser.testDelivery(await this.api.postJson(path))
  }

  private alertQueryPath(query: AlertQuery): string {
    const values: string[] = []
    values.push(`limit=${encodeURIComponent(String(Math.max(1, Math.min(200, query.limit))))}`)
    if (query.cursor.length > 0) {
      values.push(`cursor=${encodeURIComponent(query.cursor)}`)
    }
    for (let index: number = 0; index < query.statuses.length; index++) {
      values.push(`status=${encodeURIComponent(query.statuses[index])}`)
    }
    for (let index: number = 0; index < query.severities.length; index++) {
      values.push(`severity=${encodeURIComponent(query.severities[index])}`)
    }
    if (query.deviceId.length > 0) {
      values.push(`deviceId=${encodeURIComponent(query.deviceId)}`)
    }
    return `/v2/alerts?${values.join('&')}`
  }
}
