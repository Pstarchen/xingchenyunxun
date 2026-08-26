import http from 'node:http'

const devices = [
  { id: 'dev-1', name: '生产 API', hostname: 'api-prod', os: 'Ubuntu 24.04', architecture: 'amd64', primaryIp: '10.0.0.8', location: '上海', groupName: '生产', status: 'ONLINE', lastSeenAt: '2026-08-24T06:40:00Z', agentKeyPrefix: 'nz', controllerManaged: true, createdAt: '2026-01-01T00:00:00Z', hardware: {}, latest: { cpuUsage: 36, memoryUsage: 52, diskUsage: 61, services: [{ name: 'nginx', status: 'running' }, { name: 'redis', status: 'stopped' }] } },
  { id: 'dev-2', name: '数据库节点', hostname: 'db-prod', os: 'Debian 12', architecture: 'amd64', primaryIp: '10.0.0.9', location: '北京', groupName: '生产', status: 'ONLINE', lastSeenAt: '2026-08-24T06:39:00Z', agentKeyPrefix: 'nz', controllerManaged: false, createdAt: '2026-01-01T00:00:00Z', hardware: {}, latest: { cpuUsage: 68, memoryUsage: 72, diskUsage: 64, services: [{ name: 'postgresql', status: 'running' }, { name: 'docker', status: 'unsupported' }] } },
  { id: 'dev-3', name: '备份节点', hostname: 'backup', os: 'Ubuntu 22.04', architecture: 'amd64', primaryIp: '10.0.0.10', location: '杭州', groupName: '备份', status: 'OFFLINE', lastSeenAt: '2026-08-23T23:12:00Z', agentKeyPrefix: 'nz', controllerManaged: false, createdAt: '2026-01-01T00:00:00Z', hardware: {}, latest: { cpuUsage: 10, memoryUsage: 22, diskUsage: 80, services: [{ name: 'backup-agent', status: 'not_found' }] } }
]
const alert = { id: 1, deviceId: 'dev-2', deviceName: '数据库节点', ruleId: 4, ruleName: '内存使用率', severity: 'WARNING', status: 'OPEN', value: 72, message: '内存使用率超过阈值', startedAt: '2026-08-24T06:20:00Z', acknowledgedAt: null, acknowledgedBy: null, resolvedAt: null }
const dashboard = { totalDevices: 3, onlineDevices: 2, offlineDevices: 1, pendingDevices: 0, activeAlerts: 1, averageCpu: 42, averageMemory: 58, averageDisk: 63, networkSentBps: 20480, networkRecvBps: 65536, devices, topDevices: devices, recentAlerts: [alert] }

const history = Array.from({ length: 24 }, (_, index) => ({ id: index + 1, deviceId: 'dev-1', collectedAt: new Date(Date.now() - (23 - index) * 15 * 60 * 1000).toISOString(), cpuUsage: 30 + (index % 8), memoryUsage: 48 + (index % 6), swapUsage: 0, load1: 0, load5: 0, load15: 0, diskUsage: 60, diskReadBps: 0, diskWriteBps: 0, networkSentBps: 0, networkRecvBps: 0, networkSentBytes: 0, networkRecvBytes: 0, tcpConnections: 10, disks: [], processes: [], services: [] }))

const services = [
  { id: 1, name: '生产 API', target: 'https://api.example.com/health', type: 'HTTP_GET', intervalSeconds: 30, timeoutMs: 5000, publicVisible: true, sortOrder: 10, enabled: true, failureThreshold: 2, latencyThresholdMs: 500, certificateThresholdDays: 14, alertActive: false, createdAt: '2026-01-01T00:00:00Z', updatedAt: '2026-08-24T06:40:00Z', latest: { checkedAt: '2026-08-24T06:40:00Z', success: true, latencyMs: 86, statusCode: 200, certificateExpiresAt: '2026-12-18T00:00:00Z', error: null } },
  { id: 2, name: '数据库端口', target: 'db-prod:5432', type: 'TCPING', intervalSeconds: 30, timeoutMs: 3000, publicVisible: false, sortOrder: 9, enabled: true, failureThreshold: 1, latencyThresholdMs: 0, certificateThresholdDays: 14, alertActive: true, createdAt: '2026-01-01T00:00:00Z', updatedAt: '2026-08-24T06:39:00Z', latest: { checkedAt: '2026-08-24T06:39:00Z', success: false, latencyMs: 3000, statusCode: null, certificateExpiresAt: null, error: '连接超时' } },
  { id: 3, name: '备份节点 Ping', target: '10.0.0.10', type: 'ICMP_PING', intervalSeconds: 60, timeoutMs: 3000, publicVisible: false, sortOrder: 8, enabled: true, failureThreshold: 1, latencyThresholdMs: 0, certificateThresholdDays: 14, alertActive: false, createdAt: '2026-01-01T00:00:00Z', updatedAt: '2026-08-24T06:38:00Z', latest: null }
]

const serviceHistory = Array.from({ length: 12 }, (_, index) => ({ checkedAt: new Date(Date.now() - (11 - index) * 30 * 60 * 1000).toISOString(), success: index !== 8, latencyMs: 70 + (index % 5) * 8, statusCode: index === 8 ? null : 200, certificateExpiresAt: '2026-12-18T00:00:00Z', error: index === 8 ? '连接超时' : null }))

const server = http.createServer((request, response) => {
  const path = request.url?.split('?')[0] ?? ''
  let body = {}
  if (path === '/api/dashboard') body = dashboard
  else if (path === '/api/devices') body = devices
  else if (path === '/api/alerts') body = [alert]
  else if (path === '/api/devices/dev-1') body = devices[0]
  else if (path === '/api/devices/dev-2') body = devices[1]
  else if (path === '/api/devices/dev-3') body = devices[2]
  else if (path === '/api/services') body = services
  else if (path === '/api/services/1/check' && request.method === 'POST') {
    services[0].latest = { checkedAt: new Date().toISOString(), success: true, latencyMs: 74, statusCode: 200, certificateExpiresAt: '2026-12-18T00:00:00Z', error: null }
    body = services[0]
  } else if (path === '/api/services/2/check' && request.method === 'POST') {
    services[1].latest = { checkedAt: new Date().toISOString(), success: false, latencyMs: 3000, statusCode: null, certificateExpiresAt: null, error: '连接超时' }
    body = services[1]
  } else if (path === '/api/services/3/check' && request.method === 'POST') {
    services[2].latest = { checkedAt: new Date().toISOString(), success: false, latencyMs: 3000, statusCode: null, certificateExpiresAt: null, error: '主机不可达' }
    body = services[2]
  } else if (path === '/api/services/1/history') body = serviceHistory
  else if (path === '/api/services/2/history') body = serviceHistory.map((item, index) => ({ ...item, success: index % 4 !== 0, error: index % 4 === 0 ? '连接超时' : null, statusCode: index % 4 === 0 ? null : 200 }))
  else if (path === '/api/services/3/history') body = []
  else if (path.endsWith('/metrics/history')) body = history
  response.writeHead(200, { 'Content-Type': 'application/json' })
  response.end(JSON.stringify(body))
})

server.listen(18081, '127.0.0.1', () => console.log('MOCK_MONITOR_READY'))
