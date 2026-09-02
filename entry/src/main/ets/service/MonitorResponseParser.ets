import {
  BootstrapController,
  BootstrapPrincipal,
  BootstrapServer,
  ClientBootstrap
} from '../model/BootstrapModels'
import {
  DeviceDiagnostics,
  DiagnosticHealthSummary,
  DiagnosticTotals,
  DiskDiagnostic,
  MetricHistoryPoint,
  MetricHistoryRange,
  MetricHistoryResponse,
  NetworkInterfaceDiagnostic,
  ProcessDiagnostic,
  SmartDiagnostic
} from '../model/DiagnosticModels'
import {
  AlertV2Item,
  AlertV2Page,
  AlertV2Severity,
  AlertV2Status,
  AlertV2Summary,
  BulkAcknowledgeResult
} from '../model/AlertModels'
import { RealtimeEnvelope, RealtimeEventType, RealtimeTicket } from '../model/RealtimeModels'
import { MobileInstallation, TestNotificationDelivery } from '../model/NotificationModels'
import { isValidCapability, isValidControllerId, normalizeMonitorScopes } from '../utils/ScopePolicy'
import { JsonRecord, StrictJson } from '../utils/StrictJson'

function parseSeverity(value: string, context: string): AlertV2Severity {
  if (value === 'INFO' || value === 'WARNING' || value === 'CRITICAL') {
    return value
  }
  throw new Error(`${context}: unsupported severity`)
}

function parseStatus(value: string, context: string): AlertV2Status {
  if (value === 'OPEN' || value === 'ACKNOWLEDGED' || value === 'RESOLVED') {
    return value
  }
  throw new Error(`${context}: unsupported status`)
}

function parseRange(value: string, context: string): MetricHistoryRange {
  if (value === '1H' || value === '6H' || value === '24H' || value === '7D' || value === '30D') {
    return value
  }
  throw new Error(`${context}: unsupported history range`)
}

function parseRealtimeEventType(value: string, context: string): RealtimeEventType {
  if (value === 'metric.updated' || value === 'device.status' || value === 'alert.opened' ||
    value === 'alert.updated' || value === 'alert.acknowledged' || value === 'alert.resolved' ||
    value === 'resync.required') {
    return value
  }
  throw new Error(`${context}: unsupported realtime event type`)
}

function parseProcess(source: JsonRecord, context: string): ProcessDiagnostic {
  const result: ProcessDiagnostic = new ProcessDiagnostic()
  result.pid = StrictJson.number(source, 'pid', context)
  result.name = StrictJson.string(source, 'name', context)
  result.username = StrictJson.optionalString(source, 'username', context)
  result.cpuPercent = StrictJson.number(source, 'cpuPercent', context)
  result.memoryPercent = StrictJson.number(source, 'memoryPercent', context)
  result.status = StrictJson.optionalString(source, 'status', context)
  return result
}

function parseProcesses(source: JsonRecord, key: string, context: string): ProcessDiagnostic[] {
  const records: JsonRecord[] = StrictJson.records(source, key, context)
  const results: ProcessDiagnostic[] = []
  for (let index: number = 0; index < records.length; index++) {
    results.push(parseProcess(records[index], `${context}.${key}[${index}]`))
  }
  return results
}

function parseAlert(source: JsonRecord, context: string): AlertV2Item {
  const item: AlertV2Item = new AlertV2Item()
  item.id = StrictJson.number(source, 'id', context)
  item.deviceId = StrictJson.string(source, 'deviceId', context)
  item.deviceName = StrictJson.string(source, 'deviceName', context)
  item.ruleId = StrictJson.number(source, 'ruleId', context)
  item.ruleName = StrictJson.string(source, 'ruleName', context)
  item.severity = parseSeverity(StrictJson.string(source, 'severity', context), `${context}.severity`)
  item.status = parseStatus(StrictJson.string(source, 'status', context), `${context}.status`)
  item.value = StrictJson.number(source, 'value', context)
  item.message = StrictJson.string(source, 'message', context)
  item.startedAt = StrictJson.string(source, 'startedAt', context)
  item.acknowledgedAt = StrictJson.optionalString(source, 'acknowledgedAt', context)
  item.acknowledgedBy = StrictJson.optionalString(source, 'acknowledgedBy', context)
  item.resolvedAt = StrictJson.optionalString(source, 'resolvedAt', context)
  return item
}

export class MonitorResponseParser {
  static bootstrap(raw: string): ClientBootstrap {
    const source: JsonRecord = StrictJson.parseRecord(raw, 'bootstrap')
    const controllerSource: JsonRecord = StrictJson.record(source, 'controller', 'bootstrap')
    const serverSource: JsonRecord = StrictJson.record(source, 'server', 'bootstrap')
    const principalSource: JsonRecord = StrictJson.record(source, 'principal', 'bootstrap')
    const controller: BootstrapController = new BootstrapController()
    controller.id = StrictJson.string(controllerSource, 'id', 'bootstrap.controller')
    controller.name = StrictJson.string(controllerSource, 'name', 'bootstrap.controller')
    controller.canonicalEntry = StrictJson.string(controllerSource, 'canonicalEntry', 'bootstrap.controller')
    controller.timezone = StrictJson.string(controllerSource, 'timezone', 'bootstrap.controller')
    if (!isValidControllerId(controller.id) || controller.name.trim().length === 0) {
      throw new Error('bootstrap.controller: invalid identity')
    }
    const server: BootstrapServer = new BootstrapServer()
    server.version = StrictJson.string(serverSource, 'version', 'bootstrap.server')
    server.buildTime = StrictJson.optionalString(serverSource, 'buildTime', 'bootstrap.server')
    server.apiVersion = StrictJson.number(serverSource, 'apiVersion', 'bootstrap.server')
    server.minimumClientApiVersion = StrictJson.number(serverSource, 'minimumClientApiVersion', 'bootstrap.server')
    server.serverTime = StrictJson.string(serverSource, 'serverTime', 'bootstrap.server')
    if (!Number.isInteger(server.apiVersion) || server.apiVersion < 1 ||
      !Number.isInteger(server.minimumClientApiVersion) || server.minimumClientApiVersion < 1) {
      throw new Error('bootstrap.server: invalid API version')
    }
    const capabilities: string[] = StrictJson.strings(source, 'capabilities', 'bootstrap')
    for (let index: number = 0; index < capabilities.length; index++) {
      if (!isValidCapability(capabilities[index])) {
        throw new Error(`bootstrap.capabilities[${index}]: invalid capability`)
      }
    }
    const principal: BootstrapPrincipal = new BootstrapPrincipal()
    principal.authenticationType = StrictJson.string(principalSource, 'authenticationType', 'bootstrap.principal').toUpperCase()
    principal.username = StrictJson.string(principalSource, 'username', 'bootstrap.principal')
    principal.role = StrictJson.string(principalSource, 'role', 'bootstrap.principal')
    principal.tokenId = StrictJson.optionalStringOrNumber(principalSource, 'tokenId', 'bootstrap.principal')
    principal.tokenPrefix = StrictJson.optionalString(principalSource, 'tokenPrefix', 'bootstrap.principal')
    const parsedScopes: string[] = StrictJson.strings(principalSource, 'scopes', 'bootstrap.principal')
    const scopes: string[] | undefined = normalizeMonitorScopes(parsedScopes)
    if (scopes === undefined) {
      throw new Error('bootstrap.principal.scopes: invalid scope')
    }
    principal.scopes = scopes
    principal.serverIds = StrictJson.strings(principalSource, 'serverIds', 'bootstrap.principal')
    principal.expiresAt = StrictJson.optionalString(principalSource, 'expiresAt', 'bootstrap.principal')
    if (principal.authenticationType !== 'BEARER' && principal.authenticationType !== 'SESSION') {
      throw new Error('bootstrap.principal.authenticationType: unsupported authentication type')
    }
    const bootstrap: ClientBootstrap = new ClientBootstrap()
    bootstrap.controller = controller
    bootstrap.server = server
    bootstrap.capabilities = capabilities
    bootstrap.principal = principal
    return bootstrap
  }

  static diagnostics(raw: string): DeviceDiagnostics {
    const source: JsonRecord = StrictJson.parseRecord(raw, 'diagnostics')
    const totalsSource: JsonRecord = StrictJson.record(source, 'totals', 'diagnostics')
    const totals: DiagnosticTotals = new DiagnosticTotals()
    totals.cpuUsage = StrictJson.number(totalsSource, 'cpuUsage', 'diagnostics.totals')
    totals.memoryUsage = StrictJson.number(totalsSource, 'memoryUsage', 'diagnostics.totals')
    totals.swapUsage = StrictJson.number(totalsSource, 'swapUsage', 'diagnostics.totals')
    totals.load1 = StrictJson.number(totalsSource, 'load1', 'diagnostics.totals')
    totals.load5 = StrictJson.number(totalsSource, 'load5', 'diagnostics.totals')
    totals.load15 = StrictJson.number(totalsSource, 'load15', 'diagnostics.totals')
    totals.temperatureCelsius = StrictJson.optionalNumber(totalsSource, 'temperatureCelsius', 0,
      'diagnostics.totals')
    totals.networkSentBps = StrictJson.number(totalsSource, 'networkSentBps', 'diagnostics.totals')
    totals.networkRecvBps = StrictJson.number(totalsSource, 'networkRecvBps', 'diagnostics.totals')
    totals.networkSentBytes = StrictJson.number(totalsSource, 'networkSentBytes', 'diagnostics.totals')
    totals.networkRecvBytes = StrictJson.number(totalsSource, 'networkRecvBytes', 'diagnostics.totals')
    totals.tcpConnections = StrictJson.number(totalsSource, 'tcpConnections', 'diagnostics.totals')
    const interfaces: NetworkInterfaceDiagnostic[] = []
    const interfaceRecords: JsonRecord[] = StrictJson.records(source, 'networkInterfaces', 'diagnostics')
    for (let index: number = 0; index < interfaceRecords.length; index++) {
      const item: NetworkInterfaceDiagnostic = new NetworkInterfaceDiagnostic()
      const context: string = `diagnostics.networkInterfaces[${index}]`
      item.name = StrictJson.string(interfaceRecords[index], 'name', context)
      item.mtu = StrictJson.number(interfaceRecords[index], 'mtu', context)
      item.flags = StrictJson.strings(interfaceRecords[index], 'flags', context)
      item.addresses = StrictJson.strings(interfaceRecords[index], 'addresses', context)
      interfaces.push(item)
    }
    const disks: DiskDiagnostic[] = []
    const diskRecords: JsonRecord[] = StrictJson.records(source, 'disks', 'diagnostics')
    for (let index: number = 0; index < diskRecords.length; index++) {
      const context: string = `diagnostics.disks[${index}]`
      const item: DiskDiagnostic = new DiskDiagnostic()
      item.device = StrictJson.string(diskRecords[index], 'device', context)
      item.mountpoint = StrictJson.string(diskRecords[index], 'mountpoint', context)
      item.fileSystem = StrictJson.string(diskRecords[index], 'fileSystem', context)
      item.totalBytes = StrictJson.number(diskRecords[index], 'totalBytes', context)
      item.usedBytes = StrictJson.number(diskRecords[index], 'usedBytes', context)
      item.freeBytes = StrictJson.number(diskRecords[index], 'freeBytes', context)
      item.usagePercent = StrictJson.number(diskRecords[index], 'usagePercent', context)
      item.readBytesPerSec = StrictJson.number(diskRecords[index], 'readBytesPerSec', context)
      item.writeBytesPerSec = StrictJson.number(diskRecords[index], 'writeBytesPerSec', context)
      const smartSource: JsonRecord = StrictJson.record(diskRecords[index], 'smart', context)
      const smart: SmartDiagnostic = new SmartDiagnostic()
      smart.available = StrictJson.boolean(smartSource, 'available', `${context}.smart`)
      smart.healthy = StrictJson.boolean(smartSource, 'healthy', `${context}.smart`)
      smart.status = StrictJson.string(smartSource, 'status', `${context}.smart`)
      smart.temperatureCelsius = StrictJson.optionalNumber(smartSource, 'temperatureCelsius', 0,
        `${context}.smart`)
      item.smart = smart
      disks.push(item)
    }
    const healthSource: JsonRecord = StrictJson.record(source, 'health', 'diagnostics')
    const health: DiagnosticHealthSummary = new DiagnosticHealthSummary()
    health.smartFailure = StrictJson.boolean(healthSource, 'smartFailure', 'diagnostics.health')
    health.integrityChanged = StrictJson.boolean(healthSource, 'integrityChanged', 'diagnostics.health')
    health.firewallEnabled = StrictJson.boolean(healthSource, 'firewallEnabled', 'diagnostics.health')
    health.messages = StrictJson.strings(healthSource, 'messages', 'diagnostics.health')
    const result: DeviceDiagnostics = new DeviceDiagnostics()
    result.deviceId = StrictJson.string(source, 'deviceId', 'diagnostics')
    result.collectedAt = StrictJson.string(source, 'collectedAt', 'diagnostics')
    result.online = StrictJson.boolean(source, 'online', 'diagnostics')
    result.totals = totals
    result.networkInterfaces = interfaces
    result.disks = disks
    result.topCpuProcesses = parseProcesses(source, 'topCpuProcesses', 'diagnostics')
    result.topMemoryProcesses = parseProcesses(source, 'topMemoryProcesses', 'diagnostics')
    result.health = health
    return result
  }

  static history(raw: string): MetricHistoryResponse {
    const source: JsonRecord = StrictJson.parseRecord(raw, 'history')
    const pointRecords: JsonRecord[] = StrictJson.records(source, 'points', 'history')
    const points: MetricHistoryPoint[] = []
    for (let index: number = 0; index < pointRecords.length; index++) {
      const context: string = `history.points[${index}]`
      const point: MetricHistoryPoint = new MetricHistoryPoint()
      point.collectedAt = StrictJson.string(pointRecords[index], 'collectedAt', context)
      point.cpuUsage = StrictJson.number(pointRecords[index], 'cpuUsage', context)
      point.memoryUsage = StrictJson.number(pointRecords[index], 'memoryUsage', context)
      point.swapUsage = StrictJson.number(pointRecords[index], 'swapUsage', context)
      point.load1 = StrictJson.number(pointRecords[index], 'load1', context)
      point.load5 = StrictJson.number(pointRecords[index], 'load5', context)
      point.load15 = StrictJson.number(pointRecords[index], 'load15', context)
      point.temperatureCelsius = StrictJson.optionalNumber(pointRecords[index], 'temperatureCelsius', 0, context)
      point.diskUsage = StrictJson.number(pointRecords[index], 'diskUsage', context)
      point.networkSentBps = StrictJson.number(pointRecords[index], 'networkSentBps', context)
      point.networkRecvBps = StrictJson.number(pointRecords[index], 'networkRecvBps', context)
      points.push(point)
    }
    const result: MetricHistoryResponse = new MetricHistoryResponse()
    result.deviceId = StrictJson.string(source, 'deviceId', 'history')
    result.range = parseRange(StrictJson.string(source, 'range', 'history'), 'history.range')
    result.from = StrictJson.string(source, 'from', 'history')
    result.to = StrictJson.string(source, 'to', 'history')
    result.sampleStepSeconds = StrictJson.number(source, 'sampleStepSeconds', 'history')
    result.points = points
    if (points.length > 720) {
      throw new Error('history.points: exceeds 720 point limit')
    }
    if (!Number.isInteger(result.sampleStepSeconds) || result.sampleStepSeconds < 1) {
      throw new Error('history.sampleStepSeconds: invalid sample step')
    }
    return result
  }

  static alertPage(raw: string): AlertV2Page {
    const source: JsonRecord = StrictJson.parseRecord(raw, 'alerts')
    const records: JsonRecord[] = StrictJson.records(source, 'items', 'alerts')
    const items: AlertV2Item[] = []
    for (let index: number = 0; index < records.length; index++) {
      items.push(parseAlert(records[index], `alerts.items[${index}]`))
    }
    const page: AlertV2Page = new AlertV2Page()
    page.items = items
    page.nextCursor = StrictJson.optionalString(source, 'nextCursor', 'alerts')
    page.hasMore = StrictJson.boolean(source, 'hasMore', 'alerts')
    page.snapshotAt = StrictJson.string(source, 'snapshotAt', 'alerts')
    if (page.items.length > 200 || page.hasMore && page.nextCursor.length === 0) {
      throw new Error('alerts: invalid page boundary')
    }
    return page
  }

  static alert(raw: string): AlertV2Item {
    return parseAlert(StrictJson.parseRecord(raw, 'alert'), 'alert')
  }

  static alertSummary(raw: string): AlertV2Summary {
    const source: JsonRecord = StrictJson.parseRecord(raw, 'alertSummary')
    const summary: AlertV2Summary = new AlertV2Summary()
    summary.openCount = StrictJson.number(source, 'openCount', 'alertSummary')
    summary.acknowledgedCount = StrictJson.number(source, 'acknowledgedCount', 'alertSummary')
    summary.resolvedCount = StrictJson.number(source, 'resolvedCount', 'alertSummary')
    summary.infoCount = StrictJson.number(source, 'infoCount', 'alertSummary')
    summary.warningCount = StrictJson.number(source, 'warningCount', 'alertSummary')
    summary.criticalCount = StrictJson.number(source, 'criticalCount', 'alertSummary')
    summary.latestAlertId = StrictJson.number(source, 'latestAlertId', 'alertSummary')
    summary.newAlertCount = StrictJson.number(source, 'newAlertCount', 'alertSummary')
    return summary
  }

  static bulkAcknowledge(raw: string): BulkAcknowledgeResult {
    const source: JsonRecord = StrictJson.parseRecord(raw, 'bulkAcknowledge')
    const records: JsonRecord[] = StrictJson.records(source, 'acknowledged', 'bulkAcknowledge')
    const result: BulkAcknowledgeResult = new BulkAcknowledgeResult()
    for (let index: number = 0; index < records.length; index++) {
      result.acknowledged.push(parseAlert(records[index], `bulkAcknowledge.acknowledged[${index}]`))
    }
    return result
  }

  static realtimeTicket(raw: string): RealtimeTicket {
    const source: JsonRecord = StrictJson.parseRecord(raw, 'realtimeTicket')
    const ticket: RealtimeTicket = new RealtimeTicket()
    ticket.ticket = StrictJson.string(source, 'ticket', 'realtimeTicket')
    ticket.socketPath = StrictJson.optionalString(source, 'socketPath', 'realtimeTicket')
    if (ticket.socketPath.length === 0) {
      ticket.socketPath = '/ws/realtime'
    }
    ticket.latestEventId = StrictJson.optionalString(source, 'latestEventId', 'realtimeTicket')
    ticket.expiresAt = StrictJson.string(source, 'expiresAt', 'realtimeTicket')
    if (ticket.ticket.length === 0) {
      throw new Error('realtimeTicket: invalid ticket')
    }
    return ticket
  }

  static realtimeEnvelope(raw: string): RealtimeEnvelope {
    const source: JsonRecord = StrictJson.parseRecord(raw, 'realtimeEnvelope')
    const payload: JsonRecord = StrictJson.record(source, 'payload', 'realtimeEnvelope')
    const envelope: RealtimeEnvelope = new RealtimeEnvelope()
    envelope.schemaVersion = StrictJson.number(source, 'schemaVersion', 'realtimeEnvelope')
    envelope.eventId = StrictJson.string(source, 'eventId', 'realtimeEnvelope')
    envelope.type = parseRealtimeEventType(StrictJson.string(source, 'type', 'realtimeEnvelope'),
      'realtimeEnvelope.type')
    envelope.occurredAt = StrictJson.string(source, 'occurredAt', 'realtimeEnvelope')
    envelope.controllerId = StrictJson.string(source, 'controllerId', 'realtimeEnvelope')
    envelope.payloadJson = JSON.stringify(payload)
    if (envelope.schemaVersion !== 2 || !isValidControllerId(envelope.eventId) ||
      !isValidControllerId(envelope.controllerId)) {
      throw new Error('realtimeEnvelope: invalid envelope')
    }
    return envelope
  }

  static isRealtimeControlMessage(raw: string): boolean {
    const source: JsonRecord = StrictJson.parseRecord(raw, 'realtimeControl')
    return StrictJson.string(source, 'type', 'realtimeControl') === 'replay.completed'
  }

  static installation(raw: string): MobileInstallation {
    const source: JsonRecord = StrictJson.parseRecord(raw, 'installation')
    const result: MobileInstallation = new MobileInstallation()
    result.id = StrictJson.string(source, 'id', 'installation')
    result.clientInstallationId = StrictJson.string(source, 'clientInstallationId', 'installation')
    result.platform = StrictJson.string(source, 'platform', 'installation')
    result.tokenSuffix = StrictJson.optionalString(source, 'tokenSuffix', 'installation')
    result.appVersion = StrictJson.optionalString(source, 'appVersion', 'installation')
    result.deviceModel = StrictJson.optionalString(source, 'deviceModel', 'installation')
    result.deviceIds = StrictJson.optionalStrings(source, 'deviceIds', 'installation')
    result.minimumSeverity = parseSeverity(StrictJson.string(source, 'minimumSeverity', 'installation'),
      'installation.minimumSeverity')
    result.enabled = StrictJson.boolean(source, 'enabled', 'installation')
    result.lastRegisteredAt = StrictJson.optionalString(source, 'lastRegisteredAt', 'installation')
    result.createdAt = StrictJson.string(source, 'createdAt', 'installation')
    result.updatedAt = StrictJson.string(source, 'updatedAt', 'installation')
    if (result.id.length === 0 || result.clientInstallationId.length === 0 || result.platform !== 'HARMONYOS') {
      throw new Error('installation: invalid installation')
    }
    return result
  }

  static installations(raw: string): MobileInstallation[] {
    const records: JsonRecord[] = StrictJson.parseRecords(raw, 'installations')
    const results: MobileInstallation[] = []
    for (let index: number = 0; index < records.length; index++) {
      results.push(MonitorResponseParser.installation(JSON.stringify(records[index])))
    }
    return results
  }

  static testDelivery(raw: string): TestNotificationDelivery {
    const source: JsonRecord = StrictJson.parseRecord(raw, 'testDelivery')
    const result: TestNotificationDelivery = new TestNotificationDelivery()
    result.status = StrictJson.string(source, 'status', 'testDelivery')
    result.deliveryId = StrictJson.number(source, 'deliveryId', 'testDelivery')
    result.message = StrictJson.string(source, 'message', 'testDelivery')
    if (!Number.isSafeInteger(result.deliveryId) || result.deliveryId < 1) {
      throw new Error('testDelivery.deliveryId: invalid delivery ID')
    }
    return result
  }
}
