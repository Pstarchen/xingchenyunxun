import { BindingMetadata } from './ControllerProfileModels'

export type DeviceStatus = 'PENDING' | 'ONLINE' | 'OFFLINE'
export type AlertSeverity = 'INFO' | 'WARNING' | 'CRITICAL'
export type AlertStatus = 'OPEN' | 'ACKNOWLEDGED' | 'RESOLVED'
export type ServiceCheckType = 'HTTP_GET' | 'ICMP_PING' | 'TCPING'
export type ServiceCategory = 'ALL' | 'NETWORK' | 'HOST'
export type ServiceStateFilter = 'ALL' | 'HEALTHY' | 'UNHEALTHY' | 'UNKNOWN'

export interface MonitorConnection {
  baseUrl: string
  token: string
  /** Scopes are included by Web-generated binding QR codes. Manual tokens may omit them. */
  scopes?: string[]
  /** Strictly parsed QR v2 metadata. Bootstrap remains authoritative. */
  binding?: BindingMetadata
}

export interface Metric {
  id: number
  deviceId: string
  collectedAt: string
  cpuUsage: number
  memoryUsage: number
  swapUsage: number
  load1: number
  load5: number
  load15: number
  diskUsage: number
  diskReadBps: number
  diskWriteBps: number
  networkSentBps: number
  networkRecvBps: number
  networkSentBytes: number
  networkRecvBytes: number
  tcpConnections: number
  disks: DiskMetric[]
  processes: ProcessMetric[]
  services: ServiceMetric[]
}

export interface DiskMetric {
  device: string
  mountpoint: string
  fileSystem: string
  totalBytes: number
  usedBytes: number
  freeBytes: number
  usagePercent: number
  readBytesPerSec: number
  writeBytesPerSec: number
}

export interface ProcessMetric {
  pid: number
  name: string
  username: string
  cpuPercent: number
  memoryPercent: number
  status: string
}

export interface ServiceMetric {
  name: string
  status: string
}

export interface ServiceCheckResult {
  checkedAt: string
  success: boolean
  latencyMs: number
  statusCode: number | null
  certificateExpiresAt: string | null
  error: string | null
}

export interface NetworkService {
  id: number
  name: string
  target: string
  type: ServiceCheckType
  intervalSeconds: number
  timeoutMs: number
  publicVisible: boolean
  sortOrder: number
  enabled: boolean
  failureThreshold: number
  latencyThresholdMs: number
  certificateThresholdDays: number
  alertActive: boolean
  createdAt: string
  updatedAt: string
  latest: ServiceCheckResult | null
}

export interface Device {
  id: string
  name: string
  hostname: string | null
  os: string | null
  architecture: string | null
  primaryIp: string | null
  location: string | null
  groupName: string | null
  status: DeviceStatus
  lastSeenAt: string | null
  agentKeyPrefix: string
  controllerManaged: boolean
  createdAt: string
  hardware: Record<string, Object>
  latest: Metric | null
}

export interface AlertEvent {
  id: number
  deviceId: string
  deviceName: string
  ruleId: number
  ruleName: string
  severity: AlertSeverity
  status: AlertStatus
  value: number
  message: string
  startedAt: string
  acknowledgedAt: string | null
  acknowledgedBy: string | null
  resolvedAt: string | null
}

export interface Dashboard {
  totalDevices: number
  onlineDevices: number
  offlineDevices: number
  pendingDevices: number
  activeAlerts: number
  averageCpu: number
  averageMemory: number
  averageDisk: number
  networkSentBps: number
  networkRecvBps: number
  devices: Device[]
  topDevices: Device[]
  recentAlerts: AlertEvent[]
}

export interface UserProfile {
  id: number
  username: string
  displayName: string
  role: string
  enabled: boolean
  createdAt: string
}
