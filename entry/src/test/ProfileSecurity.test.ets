import { describe, expect, it } from '@ohos/hypium'
import { ClientBootstrap } from '../main/ets/model/BootstrapModels'
import { ControllerProfile, ControllerProfileDocument, LegacyConnectionSnapshot } from '../main/ets/model/ControllerProfileModels'
import { AlertV2Page } from '../main/ets/model/AlertModels'
import { DeviceDiagnostics, MetricHistoryResponse } from '../main/ets/model/DiagnosticModels'
import { MonitorResponseParser } from '../main/ets/service/MonitorResponseParser'
import { LegacyMigrationPolicy } from '../main/ets/utils/LegacyMigrationPolicy'
import { ControllerProfileCodec } from '../main/ets/utils/ControllerProfileCodec'
import { bindingMatchesBootstrap, normalizeBindingTokenValue, parseBindingPayloadValue } from '../main/ets/utils/BindingPayloadParser'
import {
  hasMonitorScope,
  isValidControllerId,
  isValidMonitorScope,
  normalizeMonitorScopes
} from '../main/ets/utils/ScopePolicy'
import { buildRealtimeSocketUrl } from '../main/ets/utils/RealtimeUrl'

const CONTROLLER_ID: string = '123e4567-e89b-12d3-a456-426614174000'
const SECOND_CONTROLLER_ID: string = '123e4567-e89b-12d3-a456-426614174001'

function validProfile(controllerId: string, profileId: string): ControllerProfile {
  const profile: ControllerProfile = new ControllerProfile()
  profile.profileId = profileId
  profile.controllerId = controllerId
  profile.controllerName = 'Primary controller'
  profile.baseUrl = 'https://monitor.example.com'
  profile.canonicalEntry = 'monitor.example.com'
  profile.apiVersion = 2
  profile.capabilities = ['client-bootstrap-v1', 'realtime-v2']
  profile.tokenId = '27'
  profile.tokenPrefix = 'nzp_demo'
  profile.tokenExpiresAt = '2030-01-01T00:00:00Z'
  profile.scopes = ['nezha:inventory:read', 'nezha:alert:read']
  profile.credentialAlias = 'profile:123e4567-e89b-12d3-a456-426614174000'
  profile.createdAt = '2026-01-01T00:00:00Z'
  profile.updatedAt = '2026-01-01T00:00:00Z'
  return profile
}

function bootstrap(): ClientBootstrap {
  const value: ClientBootstrap = new ClientBootstrap()
  value.controller.id = CONTROLLER_ID
  value.controller.name = 'Primary controller'
  value.controller.canonicalEntry = 'monitor.example.com'
  value.controller.timezone = 'UTC'
  value.server.apiVersion = 2
  value.capabilities = ['client-bootstrap-v1', 'realtime-v2']
  value.principal.scopes = ['nezha:inventory:read', 'nezha:alert:read']
  value.principal.tokenId = '27'
  value.principal.tokenPrefix = 'nzp_demo'
  value.principal.expiresAt = '2030-01-01T00:00:00Z'
  return value
}

export default function profileSecurityTest(): void {
  describe('profileSecurityTest', () => {
    it('validatesAndNormalizesScopes', 0, () => {
      expect(isValidMonitorScope('nezha:inventory:read')).assertTrue()
      expect(isValidMonitorScope('nezha:*')).assertTrue()
      expect(isValidMonitorScope('nezha:inventory')).assertFalse()
      const scopes: string[] | undefined = normalizeMonitorScopes([
        ' nezha:inventory:read ', 'nezha:inventory:read', 'nezha:alert:read'
      ])
      expect(scopes !== undefined).assertTrue()
      expect(scopes === undefined ? 0 : scopes.length).assertEqual(2)
      expect(hasMonitorScope(scopes ?? [], 'nezha:inventory:read')).assertTrue()
    })

    it('normalizesBearerPrefixedTokens', 0, () => {
      expect(normalizeBindingTokenValue(' Bearer nzp_demo_token ')).assertEqual('nzp_demo_token')
      expect(normalizeBindingTokenValue('Bearer invalid-token')).assertEqual('')
    })

    it('acceptsStrictQrVersionsAndRejectsMismatches', 0, () => {
      const legacy = parseBindingPayloadValue(
        '{"type":"xingchenyunxun-bind","baseUrl":"https://monitor.example.com/","token":"nzp_demo_token","scopes":["nezha:inventory:read"]}')
      expect(legacy !== null).assertTrue()

      const modern = parseBindingPayloadValue(
        '{"type":"xingchenyunxun-bind","schemaVersion":2,"baseUrl":"https://monitor.example.com","token":"nzp_demo_token","scopes":["nezha:inventory:read"],"controllerId":"123e4567-e89b-12d3-a456-426614174000","controllerName":"Primary controller","apiVersion":2,"capabilities":["client-bootstrap-v1"],"tokenExpiresAt":"2030-01-01T00:00:00Z"}')
      expect(modern !== null).assertTrue()
      if (modern !== null) {
        expect(bindingMatchesBootstrap(modern, bootstrap())).assertTrue()
      }

      const wrongType = parseBindingPayloadValue(
        '{"type":"other","baseUrl":"https://monitor.example.com","token":"nzp_demo_token","scopes":["nezha:inventory:read"]}')
      expect(wrongType === null).assertTrue()
      const unsupported = parseBindingPayloadValue(
        '{"type":"xingchenyunxun-bind","schemaVersion":3,"baseUrl":"https://monitor.example.com","token":"nzp_demo_token","scopes":["nezha:inventory:read"]}')
      expect(unsupported === null).assertTrue()
      const mismatchBootstrap: ClientBootstrap = bootstrap()
      mismatchBootstrap.controller.id = SECOND_CONTROLLER_ID
      if (modern !== null) {
        expect(bindingMatchesBootstrap(modern, mismatchBootstrap)).assertFalse()
      }
    })

    it('roundTripsProfilesAndRejectsDuplicateIdentities', 0, () => {
      const document: ControllerProfileDocument = new ControllerProfileDocument()
      document.profiles.push(validProfile(CONTROLLER_ID, CONTROLLER_ID))
      const encoded: string = ControllerProfileCodec.encode(document)
      const decoded: ControllerProfileDocument = ControllerProfileCodec.decode(encoded)
      expect(decoded.profiles.length).assertEqual(1)
      expect(decoded.profiles[0].controllerId).assertEqual(CONTROLLER_ID)

      const duplicate: ControllerProfileDocument = new ControllerProfileDocument()
      duplicate.profiles.push(validProfile(CONTROLLER_ID, CONTROLLER_ID))
      duplicate.profiles.push(validProfile(CONTROLLER_ID, SECOND_CONTROLLER_ID))
      let rejected: boolean = false
      try {
        ControllerProfileCodec.encode(duplicate)
      } catch (_) {
        rejected = true
      }
      expect(rejected).assertTrue()
      expect(isValidControllerId(CONTROLLER_ID)).assertTrue()
    })

    it('createsVerifiedMigrationProfile', 0, () => {
      const snapshot: LegacyConnectionSnapshot = new LegacyConnectionSnapshot()
      snapshot.baseUrl = 'https://monitor.example.com/'
      snapshot.token = 'nzp_demo_token'
      snapshot.scopes = ['nezha:inventory:read']
      const profile: ControllerProfile = LegacyMigrationPolicy.createProfile(
        snapshot, bootstrap(), CONTROLLER_ID, `profile:${CONTROLLER_ID}`, '2026-01-01T00:00:00Z')
      expect(profile.baseUrl).assertEqual('https://monitor.example.com')
      expect(profile.controllerId).assertEqual(CONTROLLER_ID)
      expect(profile.scopes.length).assertEqual(2)
      expect(LegacyMigrationPolicy.canResume(profile, bootstrap(), snapshot)).assertTrue()
    })
  })
}

export function responseParserTest(): void {
  describe('responseParserTest', () => {
    it('parsesBoundedHistoryAndAlertPage', 0, () => {
      const history: MetricHistoryResponse = MonitorResponseParser.history(
        '{"deviceId":"device-1","range":"24H","from":"2026-01-01T00:00:00Z","to":"2026-01-02T00:00:00Z","sampleStepSeconds":300,"points":[]}')
      expect(history.range).assertEqual('24H')
      expect(history.sampleStepSeconds).assertEqual(300)
      const page: AlertV2Page = MonitorResponseParser.alertPage(
        '{"items":[],"nextCursor":"","hasMore":false,"snapshotAt":"2026-01-02T00:00:00Z"}')
      expect(page.hasMore).assertFalse()
      expect(page.snapshotAt).assertEqual('2026-01-02T00:00:00Z')
    })

    it('parsesMobileDeviceDiagnostics', 0, () => {
      const diagnostics: DeviceDiagnostics = MonitorResponseParser.diagnostics(
        '{"deviceId":"device-1","collectedAt":"2026-01-02T00:00:00Z","online":true,' +
        '"totals":{"cpuUsage":42.5,"memoryUsage":50,"swapUsage":0,"load1":0.4,"load5":0.3,' +
        '"load15":0.2,"temperatureCelsius":47,"networkSentBps":10,"networkRecvBps":20,' +
        '"networkSentBytes":1000,"networkRecvBytes":2000,"tcpConnections":3},' +
        '"networkInterfaces":[{"name":"eth0","mtu":1500,"flags":["up"],"addresses":["10.0.0.2"]}],' +
        '"disks":[{"device":"sda","mountpoint":"/","fileSystem":"ext4","totalBytes":1024,' +
        '"usedBytes":512,"freeBytes":512,"usagePercent":50,"readBytesPerSec":10,' +
        '"writeBytesPerSec":5,"smart":{"available":true,"healthy":true,"status":"PASSED",' +
        '"temperatureCelsius":36}}],"topCpuProcesses":[{"pid":42,"name":"worker","username":"root",' +
        '"cpuPercent":12.5,"memoryPercent":2.5,"status":"running"}],"topMemoryProcesses":[],' +
        '"health":{"smartFailure":false,"integrityChanged":false,"firewallEnabled":true,"messages":[]}}')
      expect(diagnostics.deviceId).assertEqual('device-1')
      expect(diagnostics.networkInterfaces[0].name).assertEqual('eth0')
      expect(diagnostics.disks[0].smart.healthy).assertTrue()
      expect(diagnostics.topCpuProcesses[0].pid).assertEqual(42)
    })

    it('rejectsInvalidRealtimeEnvelope', 0, () => {
      let rejected: boolean = false
      try {
        MonitorResponseParser.realtimeEnvelope(
          '{"schemaVersion":1,"eventId":"123e4567-e89b-12d3-a456-426614174000","type":"metric.updated","occurredAt":"2026-01-02T00:00:00Z","controllerId":"123e4567-e89b-12d3-a456-426614174000","payload":{}}')
      } catch (_) {
        rejected = true
      }
      expect(rejected).assertTrue()
    })

    it('buildsRealtimeUrlsAndRecognizesReplayControlMessages', 0, () => {
      expect(buildRealtimeSocketUrl('https://monitor.example.com/api/', '/ws/realtime', 'a+b'))
        .assertEqual('wss://monitor.example.com/ws/realtime?ticket=a%2Bb')
      expect(buildRealtimeSocketUrl('http://10.0.0.2:8080', '/ws/realtime?mode=mobile', 'ticket'))
        .assertEqual('ws://10.0.0.2:8080/ws/realtime?mode=mobile&ticket=ticket')
      expect(MonitorResponseParser.isRealtimeControlMessage(
        '{"type":"replay.completed","nextEventId":"","latestEventId":"","hasMore":false}')).assertTrue()
    })

    it('normalizesBootstrapAuthenticationTypeAndParsesRealtimeTicket', 0, () => {
      const parsed: ClientBootstrap = MonitorResponseParser.bootstrap(
        '{"controller":{"id":"123e4567-e89b-12d3-a456-426614174000","name":"Primary controller","canonicalEntry":"monitor.example.com","timezone":"UTC"},"server":{"version":"1","buildTime":null,"apiVersion":2,"minimumClientApiVersion":1,"serverTime":"2026-01-02T00:00:00Z"},"capabilities":["client-bootstrap-v1"],"principal":{"authenticationType":"bearer","username":"operator","role":"OPERATOR","tokenId":27,"tokenPrefix":"nzp_demo","scopes":["nezha:inventory:read"],"serverIds":[],"expiresAt":null}}')
      expect(parsed.principal.authenticationType).assertEqual('BEARER')
      const ticket = MonitorResponseParser.realtimeTicket(
        '{"ticket":"ticket-value","expiresAt":"2026-01-02T00:01:00Z","socketPath":"/ws/realtime","latestEventId":"123e4567-e89b-12d3-a456-426614174000"}')
      expect(ticket.latestEventId).assertEqual('123e4567-e89b-12d3-a456-426614174000')
      const delivery = MonitorResponseParser.testDelivery(
        '{"status":"QUEUED","deliveryId":42,"message":"queued"}')
      expect(delivery.deliveryId).assertEqual(42)
    })
  })
}
