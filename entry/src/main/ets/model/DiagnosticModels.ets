export type MetricHistoryRange = '1H' | '6H' | '24H' | '7D' | '30D'

export class DiagnosticTotals {
  cpuUsage: number = 0
  memoryUsage: number = 0
  swapUsage: number = 0
  load1: number = 0
  load5: number = 0
  load15: number = 0
  temperatureCelsius: number = 0
  networkSentBps: number = 0
  networkRecvBps: number = 0
  networkSentBytes: number = 0
  networkRecvBytes: number = 0
  tcpConnections: number = 0
}

export class NetworkInterfaceDiagnostic {
  name: string = ''
  mtu: number = 0
  flags: string[] = []
  addresses: string[] = []
}

export class SmartDiagnostic {
  available: boolean = false
  healthy: boolean = false
  status: string = ''
  temperatureCelsius: number = 0
}

export class DiskDiagnostic {
  device: string = ''
  mountpoint: string = ''
  fileSystem: string = ''
  totalBytes: number = 0
  usedBytes: number = 0
  freeBytes: number = 0
  usagePercent: number = 0
  readBytesPerSec: number = 0
  writeBytesPerSec: number = 0
  smart: SmartDiagnostic = new SmartDiagnostic()
}

export class ProcessDiagnostic {
  pid: number = 0
  name: string = ''
  username: string = ''
  cpuPercent: number = 0
  memoryPercent: number = 0
  status: string = ''
}

export class DiagnosticHealthSummary {
  smartFailure: boolean = false
  integrityChanged: boolean = false
  firewallEnabled: boolean = false
  messages: string[] = []
}

export class DeviceDiagnostics {
  deviceId: string = ''
  collectedAt: string = ''
  online: boolean = false
  totals: DiagnosticTotals = new DiagnosticTotals()
  networkInterfaces: NetworkInterfaceDiagnostic[] = []
  disks: DiskDiagnostic[] = []
  topCpuProcesses: ProcessDiagnostic[] = []
  topMemoryProcesses: ProcessDiagnostic[] = []
  health: DiagnosticHealthSummary = new DiagnosticHealthSummary()
}

export class MetricHistoryPoint {
  collectedAt: string = ''
  cpuUsage: number = 0
  memoryUsage: number = 0
  swapUsage: number = 0
  load1: number = 0
  load5: number = 0
  load15: number = 0
  temperatureCelsius: number = 0
  diskUsage: number = 0
  networkSentBps: number = 0
  networkRecvBps: number = 0
}

export class MetricHistoryResponse {
  deviceId: string = ''
  range: MetricHistoryRange = '1H'
  from: string = ''
  to: string = ''
  sampleStepSeconds: number = 0
  points: MetricHistoryPoint[] = []
}
