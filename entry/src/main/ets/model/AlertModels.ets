export type AlertV2Severity = 'INFO' | 'WARNING' | 'CRITICAL'
export type AlertV2Status = 'OPEN' | 'ACKNOWLEDGED' | 'RESOLVED'

export class AlertV2Item {
  id: number = 0
  deviceId: string = ''
  deviceName: string = ''
  ruleId: number = 0
  ruleName: string = ''
  severity: AlertV2Severity = 'INFO'
  status: AlertV2Status = 'OPEN'
  value: number = 0
  message: string = ''
  startedAt: string = ''
  acknowledgedAt: string = ''
  acknowledgedBy: string = ''
  resolvedAt: string = ''
}

export class AlertV2Page {
  items: AlertV2Item[] = []
  nextCursor: string = ''
  hasMore: boolean = false
  snapshotAt: string = ''
}

export class AlertV2Summary {
  openCount: number = 0
  acknowledgedCount: number = 0
  resolvedCount: number = 0
  infoCount: number = 0
  warningCount: number = 0
  criticalCount: number = 0
  latestAlertId: number = 0
  newAlertCount: number = 0
}

export class AlertQuery {
  limit: number = 50
  cursor: string = ''
  statuses: AlertV2Status[] = []
  severities: AlertV2Severity[] = []
  deviceId: string = ''
}

export class BulkAcknowledgeRequest {
  ids: number[] = []
}

export class BulkAcknowledgeResult {
  acknowledged: AlertV2Item[] = []
}
