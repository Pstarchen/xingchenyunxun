export type RealtimeEventType = 'metric.updated' | 'device.status' | 'alert.opened' | 'alert.updated' |
  'alert.acknowledged' | 'alert.resolved' | 'resync.required'

export class RealtimeTicket {
  ticket: string = ''
  socketPath: string = '/ws/realtime'
  latestEventId: string = ''
  expiresAt: string = ''
}

export class RealtimeEnvelope {
  schemaVersion: number = 2
  eventId: string = ''
  type: RealtimeEventType = 'resync.required'
  occurredAt: string = ''
  controllerId: string = ''
  payloadJson: string = ''
}
