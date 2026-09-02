import { http } from '@kit.NetworkKit'
import { util } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'
import { MonitorConnection, Dashboard, Device, Metric, AlertEvent, NetworkService, ServiceCheckResult } from '../model/MonitorModels'
import { normalizeBindingTokenValue } from './BindingPayloadParser'
import { JsonRecord, StrictJson } from './StrictJson'

export type MonitorApiErrorKind = 'UNAUTHORIZED' | 'FORBIDDEN' | 'UNSUPPORTED' | 'TIMEOUT' |
  'CURSOR_INVALID' | 'CONFLICT' | 'PROVIDER_UNAVAILABLE' | 'SERVER' | 'NETWORK'

export class MonitorApiErrorBody {
  message: string = ''
  code: string = ''
  requiredScope: string = ''
}

class AlertAcknowledgeRequest {
  ids: number[] = []
}

export class MonitorApiError extends Error {
  status: number
  kind: MonitorApiErrorKind
  code: string
  requiredScope: string

  constructor(message: string, status: number = 0, kind: MonitorApiErrorKind = 'NETWORK', code: string = '',
    requiredScope: string = '') {
    super(message)
    this.name = 'MonitorApiError'
    this.status = status
    this.kind = kind
    this.code = code
    this.requiredScope = requiredScope
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

  private parseErrorBody(raw: string): MonitorApiErrorBody {
    const errorBody: MonitorApiErrorBody = new MonitorApiErrorBody()
    if (raw.trim().length === 0) {
      return errorBody
    }
    try {
      const source: JsonRecord = StrictJson.parseRecord(raw, 'error')
      errorBody.message = StrictJson.optionalString(source, 'message', 'error')
      errorBody.code = StrictJson.optionalString(source, 'code', 'error')
      errorBody.requiredScope = StrictJson.optionalString(source, 'requiredScope', 'error')
      const fallback: string = StrictJson.optionalString(source, 'error', 'error')
      errorBody.message = errorBody.message.length > 0 ? errorBody.message : fallback
    } catch (_) {
      return errorBody
    }
    return errorBody
  }

  private errorKind(status: number, code: string): MonitorApiErrorKind {
    if (status === 401) return 'UNAUTHORIZED'
    if (status === 403) return 'FORBIDDEN'
    if (status === 404 || status === 501) return 'UNSUPPORTED'
    if (status === 408 || status === 504) return 'TIMEOUT'
    if (status === 409) return 'CONFLICT'
    if (status === 410 || code === 'CURSOR_INVALID' || code === 'CURSOR_EXPIRED') return 'CURSOR_INVALID'
    if (code === 'PUSH_PROVIDER_DISABLED' || code === 'PROVIDER_NOT_CONFIGURED') return 'PROVIDER_UNAVAILABLE'
    return 'SERVER'
  }

  private defaultErrorMessage(status: number, kind: MonitorApiErrorKind, requiredScope: string): string {
    if (kind === 'UNAUTHORIZED') return 'Token 已失效，请重新绑定'
    if (kind === 'FORBIDDEN' && requiredScope.length > 0) return `当前 Token 缺少权限：${requiredScope}`
    if (kind === 'FORBIDDEN') return '当前 Token 缺少所需权限'
    if (kind === 'UNSUPPORTED') return '当前服务器版本不支持此功能'
    if (kind === 'TIMEOUT') return '请求超时，请稍后重试'
    if (kind === 'CURSOR_INVALID') return '分页游标已失效，请刷新列表'
    if (kind === 'PROVIDER_UNAVAILABLE') return '服务器推送服务尚未配置'
    return `请求失败（${status}）`
  }

  private errorMessage(body: MonitorApiErrorBody, status: number, kind: MonitorApiErrorKind): string {
    if (kind === 'UNAUTHORIZED') {
      return this.defaultErrorMessage(status, kind, body.requiredScope)
    }
    if (kind === 'FORBIDDEN' && body.requiredScope.length > 0) {
      return `当前 Token 缺少权限：${body.requiredScope}`
    }
    return body.message.length > 0 ? body.message : this.defaultErrorMessage(status, kind, body.requiredScope)
  }

  async requestJson(path: string, method: http.RequestMethod = http.RequestMethod.GET,
    body: Object | undefined = undefined): Promise<string> {
    const request = http.createHttp()
    try {
      const token: string = normalizeBindingTokenValue(this.connection.token)
      if (token.length === 0) {
        throw new MonitorApiError('Token 已失效，请重新绑定', 401, 'UNAUTHORIZED')
      }
      const headers: Record<string, string> = body === undefined ? {
        'Accept': 'application/json',
        'Authorization': `Bearer ${token}`
      } : {
        'Accept': 'application/json',
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
      let options: http.HttpRequestOptions
      if (body === undefined) {
        options = {
          method: method,
          header: headers,
          expectDataType: http.HttpDataType.STRING,
          usingCache: false,
          connectTimeout: 10_000,
          readTimeout: 15_000
        }
      } else {
        options = {
          method: method,
          header: headers,
          extraData: JSON.stringify(body),
          expectDataType: http.HttpDataType.STRING,
          usingCache: false,
          connectTimeout: 10_000,
          readTimeout: 15_000
        }
      }
      const response: http.HttpResponse = await request.request(`${this.root()}/api${path}`, options)
      const raw: string = this.responseText(response.result)
      const status: number = Number(response.responseCode)
      if (status < 200 || status >= 300) {
        const errorBody: MonitorApiErrorBody = this.parseErrorBody(raw)
        const kind: MonitorApiErrorKind = this.errorKind(status, errorBody.code)
        const message: string = this.errorMessage(errorBody, status, kind)
        throw new MonitorApiError(message, status, kind, errorBody.code, errorBody.requiredScope)
      }
      return raw
    } catch (error) {
      if (error instanceof MonitorApiError) {
        throw error
      }
      const businessError: BusinessError = error as BusinessError
      if (businessError.code === 2300028) {
        throw new MonitorApiError('请求超时，请稍后重试', 0, 'TIMEOUT')
      }
      throw new MonitorApiError('网络异常，请检查服务器地址和网络连接', 0, 'NETWORK')
    } finally {
      request.destroy()
    }
  }

  async getJson(path: string): Promise<string> {
    return this.requestJson(path, http.RequestMethod.GET)
  }

  async postJson(path: string, body: Object | undefined = undefined): Promise<string> {
    return this.requestJson(path, http.RequestMethod.POST, body)
  }

  async putJson(path: string, body: Object): Promise<string> {
    return this.requestJson(path, http.RequestMethod.PUT, body)
  }

  async deleteJson(path: string): Promise<string> {
    return this.requestJson(path, http.RequestMethod.DELETE)
  }

  private async request<T>(path: string, method: http.RequestMethod = http.RequestMethod.GET): Promise<T> {
    const raw: string = await this.requestJson(path, method)
    if (raw.length === 0) {
      return JSON.parse('{}') as T
    }
    return JSON.parse(raw) as T
  }

  async checkConnection(): Promise<Dashboard> {
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

  async acknowledgeAlerts(ids: number[]): Promise<AlertEvent[]> {
    const request: AlertAcknowledgeRequest = new AlertAcknowledgeRequest()
    request.ids = ids.slice()
    const raw: string = await this.postJson('/alerts/acknowledge', request)
    return JSON.parse(raw) as AlertEvent[]
  }
}
