import { curves } from '@kit.ArkUI'
import { hdsEffect } from '@kit.UIDesignKit'
import { Device, MonitorConnection, NetworkService, ServiceCategory, ServiceCheckResult, ServiceCheckType, ServiceMetric, ServiceStateFilter } from '../model/MonitorModels'
import { MonitorApi, MonitorApiError } from '../utils/MonitorApi'
import { getThemePalette, ThemeId, ThemePalette } from '../model/ThemeModels'
import { getNavigationWidth, getPageHorizontalPadding, getServiceContentMaxWidth, LayoutSize } from '../model/ResponsiveLayout'
import { ReferenceIcon, ReferenceServiceSummaryCard } from './ReferenceComponents'
import { NetworkServiceDetailOverlay } from './NetworkServiceDetailOverlay'

@Component
struct ServiceFilterChip {
  @Prop label: string = ''
  @Prop selected: boolean = false
  @StorageLink('themeId') themeId: ThemeId = 'gold'
  @StorageLink('isDarkMode') isDarkMode: boolean = false
  onSelect: () => void = () => {}

  @State isPressed: boolean = false
  @State lightSource: hdsEffect.PointLightSourceType = hdsEffect.PointLightSourceType.NONE

  build() {
    Row({ space: 5 }) {
      if (this.selected) {
        Text('✓')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themePalette().primary)
          .transition(TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.7, y: 0.7 })).animation({ duration: 180, curve: curves.springMotion(0.55, 0.7) }))
      }
      Text(this.label)
        .fontSize(11)
        .fontWeight(this.selected ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.selected ? this.themePalette().primary : this.themePalette().secondary)
    }
      .justifyContent(FlexAlign.Center)
      .padding({ left: this.selected ? 11 : 13, right: this.selected ? 11 : 13, top: 8, bottom: 8 })
      .backgroundColor(this.isPressed ? this.themePalette().cardPressed : this.selected ? this.themePalette().primarySoft : this.themePalette().card)
      .borderRadius(14)
      .border({ width: this.selected ? 2 : 1, color: this.selected ? this.themePalette().primary : this.themePalette().divider, radius: 14 })
      .scale({ x: this.isPressed ? 0.94 : this.selected ? 1.03 : 1, y: this.isPressed ? 0.94 : this.selected ? 1.03 : 1 })
      .animation({ duration: 240, curve: curves.springMotion(0.55, 0.7) })
      .visualEffect(new hdsEffect.HdsEffectBuilder()
        .pointLight({
          sourceType: this.lightSource,
          illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER
        })
        .buildEffect())
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.isPressed = true
          this.lightSource = hdsEffect.PointLightSourceType.BRIGHT
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.isPressed = false
          this.lightSource = hdsEffect.PointLightSourceType.NONE
        }
      })
      .onClick(() => {
        this.isPressed = false
        this.lightSource = hdsEffect.PointLightSourceType.NONE
        this.onSelect()
      })
  }

  private themePalette(): ThemePalette {
    return getThemePalette(this.themeId, this.isDarkMode)
  }
}

@Component
export struct ServiceAvailabilityView {
  @Prop services: NetworkService[] = []
  @Prop devices: Device[] = []
  @Prop connection: MonitorConnection | null = null
  @Prop isLoading: boolean = false
  @Prop errorMessage: string = ''
  @Prop runningServiceId: number = -1
  @Prop canRunChecks: boolean = true
  @Prop @Watch('onContentVisibleChanged') contentVisible: boolean = false
  @Prop topInset: number = 0
  @Prop bottomInset: number = 120
  @Prop dataRevision: number = 0
  @Prop @Watch('onDetailBackRequestChanged') detailBackRequest: number = 0
  @Prop layoutSize: LayoutSize = 'compact'
  @Prop windowWidthVp: number = 360
  @Prop windowHeightVp: number = 800
  scroller: Scroller = new Scroller()
  @StorageLink('themeId') themeId: ThemeId = 'gold'
  @StorageLink('isDarkMode') isDarkMode: boolean = false
  onRefresh: () => void = () => {}
  onCheck: (service: NetworkService) => void = (_service: NetworkService) => {}
  onDetailVisibilityChanged: (visible: boolean) => void = (_visible: boolean) => {}

  @State categoryFilter: ServiceCategory = 'ALL'
  @State stateFilter: ServiceStateFilter = 'ALL'
  @State showServiceDetail: boolean = false
  @State selectedServiceId: number = -1
  @State history: ServiceCheckResult[] = []
  @State historyLoading: boolean = false
  @State historyError: string = ''
  @State contentStage: number = 0

  private historyRequestToken: number = 0
  private detailCloseTimer: number = -1
  private contentAnimationTimer: number = -1
  private contentAnimationToken: number = 0
  private handledDetailBackRequest: number = 0

  private themePalette(): ThemePalette {
    return getThemePalette(this.themeId, this.isDarkMode)
  }

  private contentViewportWidth(): number {
    const viewportWidth: number = this.windowWidthVp - getNavigationWidth(this.layoutSize)
    return viewportWidth > 0 ? viewportWidth : this.windowWidthVp
  }

  private contentContainerMaxWidth(): number {
    return getServiceContentMaxWidth(this.layoutSize, this.contentViewportWidth())
  }

  private onDetailBackRequestChanged(): void {
    if (this.detailBackRequest === this.handledDetailBackRequest) return
    this.handledDetailBackRequest = this.detailBackRequest
    this.closeServiceDetail()
  }

  aboutToAppear(): void {
    this.onContentVisibleChanged()
  }

  private onContentVisibleChanged(): void {
    this.contentAnimationToken += 1
    const token = this.contentAnimationToken
    if (this.contentAnimationTimer >= 0) {
      clearTimeout(this.contentAnimationTimer)
      this.contentAnimationTimer = -1
    }
    if (!this.contentVisible) {
      this.contentStage = 0
      this.historyRequestToken += 1
      if (this.detailCloseTimer >= 0) {
        clearTimeout(this.detailCloseTimer)
        this.detailCloseTimer = -1
      }
      if (this.showServiceDetail) this.onDetailVisibilityChanged(false)
      this.showServiceDetail = false
      this.selectedServiceId = -1
      this.history = []
      this.historyError = ''
      this.historyLoading = false
      return
    }
    this.contentStage = 1
    this.contentAnimationTimer = setTimeout(() => {
      if (token !== this.contentAnimationToken) return
      this.contentStage = 2
      this.contentAnimationTimer = setTimeout(() => {
        if (token !== this.contentAnimationToken) return
        this.contentStage = 3
        this.contentAnimationTimer = -1
      }, 90)
    }, 90)
  }

  aboutToDisappear(): void {
    this.historyRequestToken += 1
    if (this.detailCloseTimer >= 0) {
      clearTimeout(this.detailCloseTimer)
      this.detailCloseTimer = -1
    }
    if (this.contentAnimationTimer >= 0) {
      clearTimeout(this.contentAnimationTimer)
      this.contentAnimationTimer = -1
    }
  }

  private filteredServices(): NetworkService[] {
    const values: NetworkService[] = []
    for (const service of this.services) {
      if (this.categoryFilter === 'HOST') continue
      if (!this.matchesState(this.networkState(service))) continue
      values.push(service)
    }
    return values
  }

  private filteredDevices(): Device[] {
    const values: Device[] = []
    for (const device of this.devices) {
      if (this.categoryFilter === 'NETWORK') continue
      if (this.filteredHostServices(device).length === 0) continue
      values.push(device)
    }
    return values
  }

  private matchesState(state: ServiceStateFilter): boolean {
    return this.stateFilter === 'ALL' || this.stateFilter === state
  }

  private networkState(service: NetworkService): ServiceStateFilter {
    if (!service.latest) return 'UNKNOWN'
    return service.latest.success ? 'HEALTHY' : 'UNHEALTHY'
  }

  private hostState(status: string): ServiceStateFilter {
    if (status.toLowerCase() === 'running') return 'HEALTHY'
    if (status.toLowerCase() === 'stopped') return 'UNHEALTHY'
    return 'UNKNOWN'
  }

  private hostServices(device: Device): ServiceMetric[] {
    return device.latest?.services ?? []
  }

  private filteredHostServices(device: Device): ServiceMetric[] {
    const values: ServiceMetric[] = []
    for (const service of this.hostServices(device)) {
      if (!this.matchesState(this.hostState(service.status))) continue
      values.push(service)
    }
    return values
  }

  private networkCountText(): string {
    return `${this.services.length} 个网络服务`
  }

  private healthyNetworkCount(): number {
    let count = 0
    for (const service of this.services) {
      if (this.networkState(service) === 'HEALTHY') count += 1
    }
    return count
  }

  private healthyHostCount(): number {
    let count = 0
    for (const device of this.devices) {
      for (const service of this.hostServices(device)) {
        if (this.hostState(service.status) === 'HEALTHY') count += 1
      }
    }
    return count
  }

  private hostCount(): number {
    let count = 0
    for (const device of this.devices) count += this.hostServices(device).length
    return count
  }

  private serviceTypeLabel(type: ServiceCheckType): string {
    if (type === 'HTTP_GET') return 'HTTP GET'
    if (type === 'ICMP_PING') return 'ICMP Ping'
    return 'TCPing'
  }

  private serviceStateLabel(service: NetworkService): string {
    if (!service.latest) return '未探测'
    return service.latest.success ? '正常' : '异常'
  }

  private serviceStateColor(service: NetworkService): string {
    const state = this.networkState(service)
    if (state === 'HEALTHY') return this.themePalette().success
    if (state === 'UNHEALTHY') return this.themePalette().danger
    return this.themePalette().muted
  }

  private hostStateLabel(status: string): string {
    const normalized = status.toLowerCase()
    if (normalized === 'running') return '运行中'
    if (normalized === 'stopped') return '已停止'
    if (normalized === 'not_found') return '未找到'
    if (normalized === 'unsupported') return '不支持'
    return '未知'
  }

  private hostStateColor(status: string): string {
    const state = this.hostState(status)
    if (state === 'HEALTHY') return this.themePalette().success
    if (state === 'UNHEALTHY') return this.themePalette().danger
    return this.themePalette().muted
  }

  private latencyLabel(result: ServiceCheckResult | null): string {
    if (!result) return '--'
    return `${Math.max(0, Math.round(result.latencyMs))} ms`
  }

  private time(value: string | null): string {
    if (!value) return '暂无记录'
    return new Date(value).toLocaleString('zh-CN', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' })
  }

  private selectedServiceValue(): NetworkService | null {
    for (const service of this.services) {
      if (service.id === this.selectedServiceId) return service
    }
    return null
  }

  private selectedServices(): NetworkService[] {
    const selected: NetworkService | null = this.selectedServiceValue()
    if (!selected) return []
    return [selected]
  }

  private transitionId(serviceId: number): string {
    return `network-service-detail-${serviceId}`
  }

  private openServiceDetail(service: NetworkService): void {
    if (this.showServiceDetail) return
    if (this.detailCloseTimer >= 0) {
      clearTimeout(this.detailCloseTimer)
      this.detailCloseTimer = -1
    }
    this.selectedServiceId = service.id
    this.onDetailVisibilityChanged(true)
    this.history = []
    this.historyError = ''
    this.historyLoading = true
    this.getUIContext().animateTo({ duration: 420, curve: curves.springMotion(0.5, 0.76) }, () => {
      this.showServiceDetail = true
    })
    this.loadHistory(service.id)
  }

  private closeServiceDetail(): void {
    if (!this.showServiceDetail) return
    this.onDetailVisibilityChanged(false)
    this.historyRequestToken += 1
    this.getUIContext().animateTo({ duration: 380, curve: curves.springMotion(0.5, 0.76) }, () => {
      this.showServiceDetail = false
    })
    if (this.detailCloseTimer >= 0) clearTimeout(this.detailCloseTimer)
    this.detailCloseTimer = setTimeout(() => {
      this.detailCloseTimer = -1
      this.selectedServiceId = -1
      this.history = []
      this.historyError = ''
      this.historyLoading = false
    }, 400)
  }

  private refreshSelectedHistory(): void {
    if (this.selectedServiceId < 0) return
    this.historyLoading = true
    this.historyError = ''
    this.loadHistory(this.selectedServiceId)
  }

  private async loadHistory(serviceId: number): Promise<void> {
    if (!this.connection) {
      this.historyLoading = false
      this.historyError = '请先绑定监控服务器'
      return
    }
    const requestToken = this.historyRequestToken + 1
    this.historyRequestToken = requestToken
    try {
      const values = await new MonitorApi(this.connection).serviceHistory(serviceId, 6)
      if (requestToken !== this.historyRequestToken) return
      this.history = values.slice()
    } catch (error) {
      if (requestToken !== this.historyRequestToken) return
      const apiError = error as MonitorApiError
      this.historyError = apiError?.message ?? '历史探测结果加载失败'
    } finally {
      if (requestToken === this.historyRequestToken) this.historyLoading = false
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Scroll(this.scroller) {
        Column() {
          Column({ space: 14 }) {
            Blank().height(this.topInset)
            Row() {
              Column() {
                Text('服务可用性').fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.themePalette().text)
                Text(`${this.networkCountText()} · ${this.hostCount()} 个主机服务`).fontSize(11).fontColor(this.themePalette().secondary).margin({ top: 5 })
              }.alignItems(HorizontalAlign.Start)
              Blank()
              Button('刷新').height(38).type(ButtonType.Capsule).backgroundColor(this.themePalette().primarySoft).fontColor(this.themePalette().primary).onClick(() => this.onRefresh())
            }.width('100%').opacity(this.contentVisible ? 1 : 0).translate({ y: this.contentVisible ? 0 : 18 })
            Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween,
              alignItems: ItemAlign.Stretch }) {
              this.SummaryMetric('网络正常', `${this.healthyNetworkCount()}/${this.services.length}`, this.themePalette().success)
              this.SummaryMetric('主机运行', `${this.healthyHostCount()}/${this.hostCount()}`, this.themePalette().primary)
              this.SummaryMetric('异常关注', `${this.unhealthyCount()}`, this.themePalette().danger)
            }.width('100%').opacity(this.contentVisible ? 1 : 0).translate({ y: this.contentVisible ? 0 : 22 })
            this.FilterRow()
            if (this.errorMessage) {
              Row({ space: 8 }) {
                SymbolGlyph($r('sys.symbol.questionmark_circle')).fontSize(17).fontColor([this.themePalette().danger])
                Text(this.errorMessage).fontSize(12).fontColor(this.themePalette().danger).layoutWeight(1).maxLines(2)
                Text('重试').fontSize(12).fontColor(this.themePalette().primary).onClick(() => this.onRefresh())
              }.width('100%').padding(14).backgroundColor(this.themePalette().dangerSoft).borderRadius(16)
                .opacity(this.contentStage >= 2 ? 1 : 0)
                .translate({ y: this.contentStage >= 2 ? 0 : 14 })
                .animation({ duration: 360, curve: curves.springMotion(0.48, 0.76) })
            }
            if (this.isLoading && this.services.length === 0 && this.devices.length === 0) {
              Column({ space: 12 }) {
                LoadingProgress().width(34).height(34).color(this.themePalette().primary)
                Text('正在加载服务状态…').fontSize(13).fontColor(this.themePalette().secondary)
              }.width('100%').padding({ top: 68, bottom: 68 })
            } else {
              Column({ space: 22 }) {
                if (this.categoryFilter !== 'HOST') {
                  this.NetworkSection()
                }
                if (this.categoryFilter !== 'NETWORK') {
                  this.HostSection()
                }
              }.width('100%')
            }
            Blank().height(this.bottomInset)
          }
          .width('100%')
          .constraintSize({ maxWidth: this.contentContainerMaxWidth() })
          .padding({ left: getPageHorizontalPadding(this.layoutSize), right: getPageHorizontalPadding(this.layoutSize) })
          .justifyContent(FlexAlign.Start)
          .alignItems(HorizontalAlign.Start)
        }.width('100%').alignItems(HorizontalAlign.Center)
      }.width('100%').height('100%').edgeEffect(EdgeEffect.Spring).scrollBar(BarState.Off).clip(false)
      if (this.showServiceDetail) {
        ForEach(this.selectedServices(), (service: NetworkService) => {
          NetworkServiceDetailOverlay({
            service: service,
            history: this.history,
            historyLoading: this.historyLoading,
            historyError: this.historyError,
            canRunChecks: this.canRunChecks,
             runningServiceId: this.runningServiceId,
             transitionId: this.transitionId(service.id),
             bottomInset: this.bottomInset,
             layoutSize: this.layoutSize,
             windowWidthVp: this.windowWidthVp,
             windowHeightVp: this.windowHeightVp,
             onClose: () => { this.closeServiceDetail() },
            onCheck: () => { this.onCheck(service) },
            onRefreshHistory: () => { this.refreshSelectedHistory() }
          })
        }, (service: NetworkService) => `service-detail-${service.id}`)
      }
    }
    .width('100%').height('100%')
  }

  private unhealthyCount(): number {
    let count = 0
    for (const service of this.services) {
      if (this.networkState(service) === 'UNHEALTHY') count += 1
    }
    for (const device of this.devices) {
      for (const service of this.hostServices(device)) {
        if (this.hostState(service.status) === 'UNHEALTHY') count += 1
      }
    }
    return count
  }

  @Builder
  private SummaryMetric(label: string, value: string, color: string) {
    Column() {
      Text(value).fontSize(18).fontWeight(FontWeight.Bold).fontColor(color)
      Text(label).fontSize(10).fontColor(this.themePalette().secondary).margin({ top: 4 })
    }
    .flexBasis(94)
    .flexGrow(1)
    .margin({ left: 5, right: 5, bottom: 10 })
    .padding({ top: 12, bottom: 12 })
    .backgroundColor(this.themePalette().card)
    .borderRadius(16)
  }

  @Builder
  private FilterRow() {
    Column({ space: 9 }) {
      Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start,
        alignItems: ItemAlign.Center }) {
        ServiceFilterChip({ label: '全部', selected: this.categoryFilter === 'ALL', onSelect: () => { this.categoryFilter = 'ALL' } }).flexShrink(0).margin({ right: 8, bottom: 8 })
        ServiceFilterChip({ label: '网络', selected: this.categoryFilter === 'NETWORK', onSelect: () => { this.categoryFilter = 'NETWORK' } }).flexShrink(0).margin({ right: 8, bottom: 8 })
        ServiceFilterChip({ label: '主机', selected: this.categoryFilter === 'HOST', onSelect: () => { this.categoryFilter = 'HOST' } }).flexShrink(0).margin({ right: 8, bottom: 8 })
      }.width('100%')
      Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start,
        alignItems: ItemAlign.Center }) {
        ServiceFilterChip({ label: '全部状态', selected: this.stateFilter === 'ALL', onSelect: () => { this.stateFilter = 'ALL' } }).flexShrink(0).margin({ right: 8, bottom: 8 })
        ServiceFilterChip({ label: '正常', selected: this.stateFilter === 'HEALTHY', onSelect: () => { this.stateFilter = 'HEALTHY' } }).flexShrink(0).margin({ right: 8, bottom: 8 })
        ServiceFilterChip({ label: '异常', selected: this.stateFilter === 'UNHEALTHY', onSelect: () => { this.stateFilter = 'UNHEALTHY' } }).flexShrink(0).margin({ right: 8, bottom: 8 })
        ServiceFilterChip({ label: '未知', selected: this.stateFilter === 'UNKNOWN', onSelect: () => { this.stateFilter = 'UNKNOWN' } }).flexShrink(0).margin({ right: 8, bottom: 8 })
      }.width('100%')
    }.width('100%')
      .opacity(this.contentStage >= 1 ? 1 : 0)
      .translate({ y: this.contentStage >= 1 ? 0 : 14 })
      .animation({ duration: 380, curve: curves.springMotion(0.48, 0.76) })
  }

  @Builder
  private NetworkSection() {
    Column({ space: 10 }) {
      Row() {
        Text('网络服务').fontSize(17).fontWeight(FontWeight.Bold).fontColor(this.themePalette().text)
        Blank()
        Text(`${this.filteredServices().length} 项`).fontSize(12).fontColor(this.themePalette().primary)
      }.width('100%').padding({ left: 4, right: 4 })
      if (this.filteredServices().length) {
        ForEach(this.filteredServices(), (service: NetworkService) => {
          this.NetworkServiceCard(service)
        }, (service: NetworkService) => `network-${service.id}-${this.dataRevision}`)
      } else if (this.categoryFilter !== 'HOST') {
        this.EmptyState('暂无网络服务', this.services.length ? '当前筛选条件下没有匹配的网络服务。' : '请在监控服务器中配置 HTTP、Ping 或 TCPing 服务。')
      }
    }.width('100%')
      .opacity(this.contentStage >= 2 ? 1 : 0)
      .translate({ y: this.contentStage >= 2 ? 0 : 20 })
      .animation({ duration: 420, curve: curves.springMotion(0.5, 0.76) })
  }

  @Builder
  private NetworkServiceCard(service: NetworkService) {
    ReferenceServiceSummaryCard({
      serviceName: service.name,
      typeText: this.serviceTypeLabel(service.type),
      targetText: service.target,
      stateText: this.serviceStateLabel(service),
      latencyText: this.latencyLabel(service.latest),
      stateColor: this.serviceStateColor(service),
      iconBackground: service.latest?.success === true ? this.themePalette().iconSuccess : service.latest?.success === false ? this.themePalette().iconDanger : this.themePalette().shadow,
      serviceEnabled: service.enabled,
      transitionId: this.transitionId(service.id),
      detailVisible: this.showServiceDetail && this.selectedServiceId === service.id,
      onActivate: () => { this.openServiceDetail(service) }
    })
  }

  @Builder
  private HostSection() {
    Column({ space: 10 }) {
      Row() {
        Text('主机系统服务').fontSize(17).fontWeight(FontWeight.Bold).fontColor(this.themePalette().text)
        Blank()
        Text(`${this.filteredDevices().length} 台服务器`).fontSize(12).fontColor(this.themePalette().primary)
      }.width('100%').padding({ left: 4, right: 4 })
      if (this.filteredDevices().length) {
        ForEach(this.filteredDevices(), (device: Device) => {
          this.HostDeviceCard(device)
        }, (device: Device) => `host-${device.id}-${this.dataRevision}`)
      } else if (this.categoryFilter !== 'NETWORK') {
        this.EmptyState('暂无主机服务上报', 'Agent 上报系统服务后，这里会按服务器展示运行状态。')
      }
    }.width('100%')
      .opacity(this.contentStage >= 3 ? 1 : 0)
      .translate({ y: this.contentStage >= 3 ? 0 : 20 })
      .animation({ duration: 420, curve: curves.springMotion(0.5, 0.76) })
  }

  @Builder
  private HostDeviceCard(device: Device) {
    Column({ space: 9 }) {
      Row() {
        ReferenceIcon({ name: device.name, icon: $r('sys.symbol.square_grid_2x2'), iconSize: 42, iconRadius: 13, tint: this.themePalette().primary, iconBackground: this.themePalette().iconPrimary })
        Column() {
          Text(device.name).fontSize(15).fontWeight(FontWeight.Bold).fontColor(this.themePalette().text).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(device.hostname || device.primaryIp || '等待主机信息').fontSize(11).fontColor(this.themePalette().secondary).margin({ top: 4 }).maxLines(1)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 11 })
        Text(this.time(device.lastSeenAt)).fontSize(10).fontColor(this.themePalette().muted)
      }.width('100%')
      ForEach(this.filteredHostServices(device), (service: ServiceMetric) => {
        this.HostServiceRow(service)
      }, (service: ServiceMetric) => `${device.id}-${service.name}`)
    }.width('100%').padding(15).backgroundColor(this.themePalette().card).borderRadius(22).border({ width: 1, color: this.themePalette().border, radius: 22 }).shadow({ radius: 15, color: this.themePalette().shadow, offsetY: 6 })
  }

  @Builder
  private HostServiceRow(service: ServiceMetric) {
    Row() {
      Circle({ width: 8, height: 8 }).fill(this.hostStateColor(service.status))
      Text(service.name).fontSize(13).fontColor(this.themePalette().text).layoutWeight(1).margin({ left: 9 })
      Text(this.hostStateLabel(service.status)).fontSize(11).fontColor(this.hostStateColor(service.status))
    }.width('100%').padding({ top: 8, bottom: 8 }).border({ width: { bottom: 1 }, color: this.themePalette().divider })
  }

  @Builder
  private EmptyState(title: string, description: string) {
    Column() {
      Stack() { Circle({ width: 42, height: 42 }).fill(this.themePalette().surface); SymbolGlyph($r('sys.symbol.questionmark_circle')).fontSize(22).fontColor([this.themePalette().muted]) }
      Text(title).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.themePalette().text).margin({ top: 10 })
      Text(description).fontSize(11).fontColor(this.themePalette().muted).margin({ top: 5 }).textAlign(TextAlign.Center).maxLines(3)
    }.width('100%').padding({ top: 26, bottom: 26, left: 18, right: 18 }).backgroundColor(this.themePalette().card).borderRadius(20)
  }

}
