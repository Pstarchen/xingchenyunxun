import { webSocket } from '@kit.NetworkKit'
import { util } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'
import { MonitorConnection } from '../model/MonitorModels'
import { RealtimeEnvelope, RealtimeTicket } from '../model/RealtimeModels'
import { MonitorApi } from '../utils/MonitorApi'
import { buildRealtimeSocketUrl } from '../utils/RealtimeUrl'
import { MonitorRepository } from './MonitorRepository'
import { MonitorResponseParser } from './MonitorResponseParser'

export type RealtimeConnectionState = 'DISCONNECTED' | 'CONNECTING' | 'CONNECTED' | 'RECONNECTING'

export class RealtimeSession {
  private connection: MonitorConnection
  private controllerId: string
  private onEvent: (event: RealtimeEnvelope) => void
  private onStateChanged: (state: RealtimeConnectionState) => void
  private socket: webSocket.WebSocket | undefined = undefined
  private reconnectTimer: number = -1
  private reconnectAttempt: number = 0
  private generation: number = 0
  private stopped: boolean = true
  private lastEventId: string = ''

  constructor(connection: MonitorConnection, controllerId: string,
    onEvent: (event: RealtimeEnvelope) => void,
    onStateChanged: (state: RealtimeConnectionState) => void) {
    this.connection = connection
    this.controllerId = controllerId
    this.onEvent = onEvent
    this.onStateChanged = onStateChanged
  }

  start(afterEventId: string): void {
    if (!this.stopped) return
    this.stopped = false
    this.lastEventId = afterEventId.trim()
    this.reconnectAttempt = 0
    this.generation += 1
    this.connect(this.generation)
  }

  stop(): void {
    this.stopped = true
    this.generation += 1
    if (this.reconnectTimer >= 0) {
      clearTimeout(this.reconnectTimer)
      this.reconnectTimer = -1
    }
    const current: webSocket.WebSocket | undefined = this.socket
    this.socket = undefined
    if (current !== undefined) this.releaseSocket(current, true)
    this.onStateChanged('DISCONNECTED')
  }

  private async connect(generation: number): Promise<void> {
    if (this.stopped || generation !== this.generation) return
    this.onStateChanged(this.reconnectAttempt === 0 ? 'CONNECTING' : 'RECONNECTING')
    try {
      const repository: MonitorRepository = new MonitorRepository(new MonitorApi(this.connection))
      const ticket: RealtimeTicket = await repository.realtimeTicket(this.lastEventId)
      if (this.stopped || generation !== this.generation) return
      const socket: webSocket.WebSocket = webSocket.createWebSocket()
      this.socket = socket
      this.subscribe(socket, generation)
      await socket.connect(buildRealtimeSocketUrl(this.connection.baseUrl, ticket.socketPath, ticket.ticket))
    } catch (_) {
      const current: webSocket.WebSocket | undefined = this.socket
      if (current !== undefined && generation === this.generation) {
        this.socket = undefined
        this.releaseSocket(current, true)
      }
      if (generation === this.generation) this.scheduleReconnect(generation)
    }
  }

  private subscribe(socket: webSocket.WebSocket, generation: number): void {
    socket.on('open', (error: BusinessError, _data: Object): void => {
      if (error || this.stopped || generation !== this.generation || socket !== this.socket) return
      this.reconnectAttempt = 0
      this.onStateChanged('CONNECTED')
    })
    socket.on('message', (error: BusinessError, data: string | ArrayBuffer): void => {
      if (error || this.stopped || generation !== this.generation || socket !== this.socket) return
      this.handleMessage(data)
    })
    socket.on('close', (_error: BusinessError, _data: webSocket.CloseResult): void => {
      if (generation !== this.generation || socket !== this.socket) return
      this.releaseSocket(socket, false)
      this.socket = undefined
      this.scheduleReconnect(generation)
    })
    socket.on('error', (_error: BusinessError): void => {
      if (generation !== this.generation || socket !== this.socket) return
      this.releaseSocket(socket, true)
      this.socket = undefined
      this.scheduleReconnect(generation)
    })
  }

  private handleMessage(data: string | ArrayBuffer): void {
    const raw: string = typeof data === 'string' ? data :
      util.TextDecoder.create('utf-8', { ignoreBOM: true }).decodeToString(new Uint8Array(data))
    try {
      if (MonitorResponseParser.isRealtimeControlMessage(raw)) return
      const envelope: RealtimeEnvelope = MonitorResponseParser.realtimeEnvelope(raw)
      if (envelope.controllerId !== this.controllerId) return
      this.lastEventId = envelope.eventId
      this.onEvent(envelope)
    } catch (_) {
    }
  }

  private scheduleReconnect(generation: number): void {
    if (this.stopped || generation !== this.generation || this.reconnectTimer >= 0) return
    const delays: number[] = [1_000, 2_000, 5_000, 10_000, 30_000]
    const index: number = Math.min(this.reconnectAttempt, delays.length - 1)
    this.reconnectAttempt += 1
    this.onStateChanged('RECONNECTING')
    this.reconnectTimer = setTimeout((): void => {
      this.reconnectTimer = -1
      this.connect(generation)
    }, delays[index])
  }

  private releaseSocket(socket: webSocket.WebSocket, close: boolean): void {
    socket.off('open')
    socket.off('message')
    socket.off('close')
    socket.off('error')
    if (close) socket.close().catch((_error: BusinessError): void => {})
  }
}
