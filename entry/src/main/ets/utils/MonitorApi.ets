import { http } from '@kit.NetworkKit'
import { util } from '@kit.ArkTS'
import { MonitorConnection, Dashboard, Device, Metric, AlertEvent, NetworkService, ServiceCheckResult } from '../model/MonitorModels'

interface ErrorResponse {
  message?: string
}

export class MonitorApiError extends Error {
  status: number

  constructor(message: string, status: number = 0) {
    super(message)
    this.name = 'MonitorApiError'
    this.status = status
  }
}

export class MonitorApi {
  private connection: MonitorConnection

  constructor(connection: MonitorConnection) {
    this.connection = connection
  }

  private root(): string {
    let root = this.connection.baseUrl.trim()
    while (root.endsWith('/')) {
      root = root.substring(0, root.length - 1)
    }
    if (root.endsWith('/api')) {
      root = root.substring(0, root.length - 4)
    }
    return root
  }

  private responseText(result: string | Object | ArrayBuffer): string {
    if (typeof result === 'string') return result
    if (result instanceof ArrayBuffer) {
      return util.TextDecoder.create('utf-8', { ignoreBOM: true }).decodeToString(new Uint8Array(result))
    }
    return result ? JSON.stringify(result) : ''
  }

  private async request<T>(path: string, method: http.RequestMethod = http.RequestMethod.GET): Promise<T> {
    const request = http.createHttp()
    try {
      const options: http.HttpRequestOptions = {
        method,
        header: {
          'Accept': 'application/json',
          'Authorization': `Bearer ${this.connection.token}`
        },
        // Keep JSON parsing stable across HarmonyOS SDKs. HttpResponse.result
        // may otherwise be returned as an Object or ArrayBuffer.
        expectDataType: http.HttpDataType.STRING,
        usingCache: false,
        connectTimeout: 10_000,
        readTimeout: 15_000
      }
      const response = await request.request(`${this.root()}/api${path}`, options)
      const raw = this.responseText(response.result)
      let parsed: T = JSON.parse('{}') as T
      if (response.responseCode < 200 || response.responseCode >= 300) {
        let message = `请求失败（${response.responseCode}）`
        try {
          const errorBody: ErrorResponse = JSON.parse(raw) as ErrorResponse
          if (errorBody.message) message = errorBody.message
        } catch (_) {
          // Keep the status-based message when the server response is not JSON.
        }
        throw new MonitorApiError(message, response.responseCode)
      }
      if (raw) parsed = JSON.parse(raw) as T
      return parsed
    } catch (error) {
      if (error instanceof MonitorApiError) throw error
      throw new MonitorApiError('网络异常，请检查服务器地址和网络连接')
    } finally {
      request.destroy()
    }
  }

  async checkConnection(): Promise<Dashboard> {
    // API Tokens are deliberately blocked from the browser-session /auth/me
    // endpoint. Dashboard is the lightweight authenticated read probe exposed
    // to PAT clients and also validates the scopes needed by the app.
    return this.request<Dashboard>('/dashboard')
  }

  async dashboard(): Promise<Dashboard> {
    return this.request<Dashboard>('/dashboard')
  }

  async devices(): Promise<Device[]> {
    return this.request<Device[]>('/devices')
  }

  async device(id: string): Promise<Device> {
    return this.request<Device>(`/devices/${encodeURIComponent(id)}`)
  }

  async history(id: string, hours: number): Promise<Metric[]> {
    const to = new Date()
    const from = new Date(to.getTime() - hours * 3_600_000)
    const query = `?from=${encodeURIComponent(from.toISOString())}&to=${encodeURIComponent(to.toISOString())}`
    return this.request<Metric[]>(`/devices/${encodeURIComponent(id)}/metrics/history${query}`)
  }

  async alerts(): Promise<AlertEvent[]> {
    return this.request<AlertEvent[]>('/alerts?limit=50')
  }

  async services(): Promise<NetworkService[]> {
    return this.request<NetworkService[]>('/services')
  }

  async checkService(id: number): Promise<NetworkService> {
    return this.request<NetworkService>(`/services/${id}/check`, http.RequestMethod.POST)
  }

  async serviceHistory(id: number, hours: number): Promise<ServiceCheckResult[]> {
    const boundedHours = Math.max(1, Math.min(hours, 24 * 31))
    const to = new Date()
    const from = new Date(to.getTime() - boundedHours * 3_600_000)
    const query = `?from=${encodeURIComponent(from.toISOString())}&to=${encodeURIComponent(to.toISOString())}`
    return this.request<ServiceCheckResult[]>(`/services/${id}/history${query}`)
  }

  async acknowledgeAlert(id: number): Promise<AlertEvent> {
    return this.request<AlertEvent>(`/alerts/${id}/acknowledge`, http.RequestMethod.POST)
  }
}
