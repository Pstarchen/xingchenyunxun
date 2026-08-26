import { curves } from '@kit.ArkUI'
import { hdsEffect } from '@kit.UIDesignKit'
import { NetworkService, ServiceCheckResult, ServiceCheckType } from '../model/MonitorModels'
import { getDetailPanelWidth, getNavigationWidth, LayoutSize } from '../model/ResponsiveLayout'
import { getThemePalette, ThemeId, ThemePalette } from '../model/ThemeModels'
import { ReferenceIcon } from './ReferenceComponents'

interface OverlayHistoryItem {
  key: string
  result: ServiceCheckResult
}

@Component
export struct NetworkServiceDetailOverlay {
  @Prop service: NetworkService
  @Prop history: ServiceCheckResult[] = []
  @Prop historyLoading: boolean = false
  @Prop historyError: string = ''
  @Prop canRunChecks: boolean = true
  @Prop runningServiceId: number = -1
  @Prop transitionId: string = ''
  @Prop bottomInset: number = 0
  @Prop layoutSize: LayoutSize = 'compact'
  @Prop windowWidthVp: number = 360
  @Prop windowHeightVp: number = 800
  @StorageLink('themeId') themeId: ThemeId = 'gold'
  @StorageLink('isDarkMode') isDarkMode: boolean = false
  onClose: () => void = () => {}
  onCheck: () => void = () => {}
  onRefreshHistory: () => void = () => {}

  @State checkPressed: boolean = false
  @State refreshPressed: boolean = false
  @State checkLight: hdsEffect.PointLightSourceType = hdsEffect.PointLightSourceType.NONE
  @State refreshLight: hdsEffect.PointLightSourceType = hdsEffect.PointLightSourceType.NONE

  build() {
    Stack({ alignContent: this.layoutSize === 'expanded' ? Alignment.End : Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.themePalette().page)
        .opacity(0.82)
        .backgroundBlurStyle(BlurStyle.Regular)
        .transition(TransitionEffect.OPACITY.animation({ duration: 320, curve: Curve.EaseOut }))
        .onClick(() => this.onClose())
      Column() {
        Scroll() {
          Column({ space: 14 }) {
            this.HeroHeader()
            Row({ space: 9 }) {
              this.SummaryMetric('当前状态', this.stateLabel(), this.stateColor())
              this.SummaryMetric('延迟', this.latencyLabel(this.service.latest), this.themePalette().primary)
              this.SummaryMetric('状态码', this.statusCodeLabel(), this.themePalette().purple)
            }.width('100%')
            Column() {
              this.DetailLine('探测类型', this.serviceTypeLabel(this.service.type))
              this.DetailLine('服务状态', this.service.enabled ? '已启用' : '已停用')
              this.DetailLine('探测间隔', `${this.service.intervalSeconds} 秒`)
              this.DetailLine('最近探测', this.time(this.service.latest?.checkedAt ?? null))
              this.DetailLine('证书到期', this.time(this.service.latest?.certificateExpiresAt ?? null))
              this.DetailLine('错误信息', this.service.latest?.error ?? '--')
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .backgroundColor(this.themePalette().surface)
            .borderRadius(20)
            .border({ width: 1, color: this.themePalette().divider, radius: 20 })
            Row({ space: 10 }) {
              this.CheckButton()
              this.RefreshButton()
            }.width('100%')
            if (this.history.length > 0) {
              this.AvailabilityRecordCard()
              this.StatusStripCard()
            }
            Row() {
              Text('历史记录')
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.themePalette().text)
              Blank()
              Text(this.historyCountLabel())
                .fontSize(11)
                .fontColor(this.themePalette().muted)
            }.width('100%').padding({ left: 3, right: 3, top: 2 })
            this.HistoryContent()
            Blank().height(this.bottomInset + 16)
          }
          .width('100%')
          .padding({ left: 18, right: 18, top: 18 })
        }
        .width('100%')
        .height('100%')
        .edgeEffect(EdgeEffect.Spring)
        .scrollBar(BarState.Off)
      }
      .width(this.detailPanelWidth())
      .height(this.detailPanelHeight())
      .margin({ right: this.layoutSize === 'expanded' ? 32 : 0 })
      .backgroundColor(this.themePalette().card)
      .borderRadius(32)
      .border({ width: 1, color: this.themePalette().border, radius: 32 })
      .shadow({ radius: 38, color: this.themePalette().shadowStrong, offsetY: 12 })
      .clip(true)
      .geometryTransition(this.transitionId)
      .transition(TransitionEffect.OPACITY.animation({ duration: 380, curve: curves.springMotion(0.5, 0.76) }))
      .onClick((_event: ClickEvent) => {})
    }
    .width('100%')
    .height('100%')
    .zIndex(999)
  }

  @Builder
  private HeroHeader() {
    Column({ space: 13 }) {
      Row() {
        ReferenceIcon({
          name: this.service.name,
          icon: $r('sys.symbol.share'),
          iconSize: 62,
          iconRadius: 20,
          tint: this.themePalette().heroText,
          iconBackground: this.themePalette().heroShadow
        }).margin({ right: 14 })
        Column() {
          Text(this.service.name)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themePalette().heroText)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${this.serviceTypeLabel(this.service.type)} · ${this.service.enabled ? '已启用' : '已停用'}`)
            .fontSize(12)
            .fontColor(this.themePalette().heroText)
            .opacity(0.72)
            .margin({ top: 6 })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Button() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(17)
            .fontColor([this.themePalette().heroText])
        }
        .width(38)
        .height(38)
        .type(ButtonType.Circle)
        .backgroundColor(this.themePalette().heroShadow)
        .onClick(() => this.onClose())
      }.width('100%').alignItems(VerticalAlign.Center)
      Text(this.service.target)
        .fontSize(12)
        .fontColor(this.themePalette().heroText)
        .opacity(0.78)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      Row({ space: 7 }) {
        Circle({ width: 8, height: 8 }).fill(this.stateColor())
        Text(this.stateLabel())
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themePalette().heroText)
      }
      .alignSelf(ItemAlign.Start)
      .padding({ left: 11, right: 11, top: 7, bottom: 7 })
      .backgroundColor(this.themePalette().heroShadow)
      .borderRadius(14)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(18)
    .linearGradient({ angle: 135, colors: [[this.themePalette().heroStart, 0.0], [this.themePalette().heroEnd, 1.0]] })
    .borderRadius(24)
  }

  @Builder
  private SummaryMetric(label: string, value: string, color: ResourceColor) {
    Column() {
      Text(value)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(label).fontSize(9).fontColor(this.themePalette().muted).margin({ top: 4 })
    }
    .layoutWeight(1)
    .padding({ left: 5, right: 5, top: 11, bottom: 11 })
    .backgroundColor(this.themePalette().surface)
    .borderRadius(14)
  }

  @Builder
  private DetailLine(label: string, value: string) {
    Row() {
      Text(label).fontSize(12).fontColor(this.themePalette().secondary)
      Blank().width(16)
      Text(value)
        .fontSize(12)
        .fontColor(this.themePalette().text)
        .textAlign(TextAlign.End)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .border({ width: { bottom: 1 }, color: this.themePalette().divider })
  }

  @Builder
  private CheckButton() {
    Button() {
      Row({ space: 7 }) {
        SymbolGlyph($r('sys.symbol.arrow_clockwise')).fontSize(17).fontColor([this.themePalette().heroText])
        Text(this.checkButtonLabel()).fontSize(13).fontWeight(FontWeight.Medium).fontColor(this.themePalette().heroText)
      }
    }
    .layoutWeight(1)
    .height(46)
    .type(ButtonType.Capsule)
    .linearGradient({ angle: 135, colors: [[this.themePalette().heroStart, 0.0], [this.themePalette().heroEnd, 1.0]] })
    .enabled(this.checkEnabled())
    .opacity(this.checkEnabled() ? 1 : 0.55)
    .scale({ x: this.checkPressed ? 0.95 : 1, y: this.checkPressed ? 0.95 : 1 })
    .animation({ duration: 160, curve: curves.springMotion(0.6, 0.5) })
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pointLight({ sourceType: this.checkLight, illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER })
      .buildEffect())
    .onTouch((event: TouchEvent) => {
      if (!this.checkEnabled()) return
      if (event.type === TouchType.Down) {
        this.checkPressed = true
        this.checkLight = hdsEffect.PointLightSourceType.BRIGHT
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.checkPressed = false
        this.checkLight = hdsEffect.PointLightSourceType.NONE
      }
    })
    .onClick(() => this.onCheck())
  }

  @Builder
  private RefreshButton() {
    Button() {
      Row({ space: 7 }) {
        SymbolGlyph($r('sys.symbol.arrow_clockwise')).fontSize(17).fontColor([this.themePalette().primary])
        Text(this.historyLoading ? '刷新中…' : '刷新历史').fontSize(13).fontWeight(FontWeight.Medium).fontColor(this.themePalette().primary)
      }
    }
    .layoutWeight(1)
    .height(46)
    .type(ButtonType.Capsule)
    .backgroundColor(this.themePalette().primarySoft)
    .border({ width: 1, color: this.themePalette().primary, radius: 23 })
    .enabled(!this.historyLoading)
    .opacity(this.historyLoading ? 0.55 : 1)
    .scale({ x: this.refreshPressed ? 0.95 : 1, y: this.refreshPressed ? 0.95 : 1 })
    .animation({ duration: 160, curve: curves.springMotion(0.6, 0.5) })
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pointLight({ sourceType: this.refreshLight, illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER })
      .buildEffect())
    .onTouch((event: TouchEvent) => {
      if (this.historyLoading) return
      if (event.type === TouchType.Down) {
        this.refreshPressed = true
        this.refreshLight = hdsEffect.PointLightSourceType.BRIGHT
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.refreshPressed = false
        this.refreshLight = hdsEffect.PointLightSourceType.NONE
      }
    })
    .onClick(() => this.onRefreshHistory())
  }

  @Builder
  private AvailabilityRecordCard() {
    Column({ space: 14 }) {
      Row() {
        Column() {
          Text('可用性记录')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themePalette().text)
          Text('最近 6 小时探测样本')
            .fontSize(10)
            .fontColor(this.themePalette().muted)
            .margin({ top: 4 })
        }.alignItems(HorizontalAlign.Start)
        Blank()
        Text(this.availabilityLabel())
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.availabilityColor())
      }.width('100%').alignItems(VerticalAlign.Center)
      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(8)
          .backgroundColor(this.themePalette().divider)
          .borderRadius(4)
        Row()
          .width(this.availabilityWidth())
          .height(8)
          .backgroundColor(this.availabilityColor())
          .borderRadius(4)
      }.width('100%').height(8)
      Row({ space: 8 }) {
        this.AvailabilityMetric('成功', `${this.successCount()} 次`, this.themePalette().success)
        this.AvailabilityMetric('失败', `${this.failureCount()} 次`, this.themePalette().danger)
        this.AvailabilityMetric('平均延迟', this.averageLatencyLabel(), this.themePalette().primary)
      }.width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.themePalette().surface)
    .borderRadius(20)
    .border({ width: 1, color: this.themePalette().divider, radius: 20 })
  }

  @Builder
  private AvailabilityMetric(label: string, value: string, color: ResourceColor) {
    Column() {
      Text(value)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .maxLines(1)
      Text(label)
        .fontSize(9)
        .fontColor(this.themePalette().muted)
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .padding({ top: 9, bottom: 9 })
    .backgroundColor(this.themePalette().card)
    .borderRadius(12)
  }

  @Builder
  private StatusStripCard() {
    Column({ space: 11 }) {
      Row() {
        Text('探测状态条')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themePalette().text)
        Blank()
        Text('由旧到新')
          .fontSize(10)
          .fontColor(this.themePalette().muted)
      }.width('100%')
      Row({ space: 3 }) {
        ForEach(this.historyStatusItems(), (item: OverlayHistoryItem) => {
          Row()
            .height(10)
            .layoutWeight(1)
            .backgroundColor(item.result.success ? this.themePalette().success : this.themePalette().danger)
            .borderRadius(3)
        }, (item: OverlayHistoryItem) => `status-${item.key}`)
      }.width('100%').height(10)
      Row() {
        Text(this.statusStartLabel()).fontSize(9).fontColor(this.themePalette().muted)
        Blank()
        Row({ space: 10 }) {
          Row({ space: 4 }) {
            Circle({ width: 6, height: 6 }).fill(this.themePalette().success)
            Text('成功').fontSize(9).fontColor(this.themePalette().secondary)
          }
          Row({ space: 4 }) {
            Circle({ width: 6, height: 6 }).fill(this.themePalette().danger)
            Text('失败').fontSize(9).fontColor(this.themePalette().secondary)
          }
        }
        Blank()
        Text(this.statusEndLabel()).fontSize(9).fontColor(this.themePalette().muted)
      }.width('100%').alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(15)
    .backgroundColor(this.themePalette().surface)
    .borderRadius(20)
    .border({ width: 1, color: this.themePalette().divider, radius: 20 })
  }

  @Builder
  private HistoryContent() {
    Column({ space: 10 }) {
      if (this.historyLoading && this.history.length === 0) {
        LoadingProgress().width(32).height(32).color(this.themePalette().primary)
        Text('正在加载历史结果…').fontSize(12).fontColor(this.themePalette().secondary)
      } else if (this.historyError && this.history.length === 0) {
        SymbolGlyph($r('sys.symbol.questionmark_circle')).fontSize(28).fontColor([this.themePalette().danger])
        Text(this.historyError).fontSize(12).fontColor(this.themePalette().text).textAlign(TextAlign.Center).maxLines(3)
        Text('点击重试').fontSize(12).fontWeight(FontWeight.Medium).fontColor(this.themePalette().primary).onClick(() => this.onRefreshHistory())
      } else if (this.historyItems().length) {
        if (this.historyLoading) {
          Row({ space: 8 }) {
            LoadingProgress().width(18).height(18).color(this.themePalette().primary)
            Text('正在刷新历史记录…').fontSize(11).fontColor(this.themePalette().secondary)
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .backgroundColor(this.themePalette().primarySoft)
          .borderRadius(14)
        } else if (this.historyError) {
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.questionmark_circle')).fontSize(17).fontColor([this.themePalette().danger])
            Text(this.historyError).fontSize(11).fontColor(this.themePalette().danger).layoutWeight(1).maxLines(2)
            Text('重试').fontSize(11).fontWeight(FontWeight.Medium).fontColor(this.themePalette().primary).onClick(() => this.onRefreshHistory())
          }
          .width('100%')
          .padding(12)
          .backgroundColor(this.themePalette().dangerSoft)
          .borderRadius(14)
        }
        ForEach(this.historyItems(), (item: OverlayHistoryItem) => {
          this.HistoryRecordCard(item.result)
        }, (item: OverlayHistoryItem) => item.key)
      } else {
        SymbolGlyph($r('sys.symbol.questionmark_circle')).fontSize(28).fontColor([this.themePalette().muted])
        Text('暂无历史结果').fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.themePalette().text)
        Text('服务完成首次探测后，历史记录会出现在这里。').fontSize(11).fontColor(this.themePalette().muted).textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .padding({ top: 4, bottom: 10 })
  }

  @Builder
  private HistoryRecordCard(result: ServiceCheckResult) {
    Row() {
      Column()
        .width(4)
        .height(68)
        .backgroundColor(result.success ? this.themePalette().success : this.themePalette().danger)
        .borderRadius(2)
        .margin({ right: 12 })
      Column({ space: 9 }) {
        Row() {
          Text(result.success ? '探测成功' : '探测失败')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(result.success ? this.themePalette().success : this.themePalette().danger)
            .padding({ left: 9, right: 9, top: 5, bottom: 5 })
            .backgroundColor(result.success ? this.themePalette().successSoft : this.themePalette().dangerSoft)
            .borderRadius(10)
          Text(this.time(result.checkedAt))
            .fontSize(10)
            .fontColor(this.themePalette().muted)
            .margin({ left: 8 })
          Blank()
          Text(this.latencyLabel(result))
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(result.success ? this.themePalette().success : this.themePalette().danger)
        }.width('100%').alignItems(VerticalAlign.Center)
        Row() {
          Text(this.resultDetailLabel(result))
            .fontSize(10)
            .fontColor(this.themePalette().secondary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (result.statusCode !== null) {
            Text(`HTTP ${result.statusCode}`)
              .fontSize(9)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.themePalette().purple)
              .margin({ left: 8 })
              .padding({ left: 7, right: 7, top: 4, bottom: 4 })
              .backgroundColor(this.themePalette().card)
              .borderRadius(8)
          }
        }.width('100%').alignItems(VerticalAlign.Center)
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(13)
    .backgroundColor(this.themePalette().surface)
    .borderRadius(18)
    .border({ width: 1, color: this.themePalette().divider, radius: 18 })
  }

  private themePalette(): ThemePalette {
    return getThemePalette(this.themeId, this.isDarkMode)
  }

  private overlayViewportWidth(): number {
    const viewportWidth: number = this.windowWidthVp - getNavigationWidth(this.layoutSize)
    return viewportWidth > 0 ? viewportWidth : this.windowWidthVp
  }

  private detailPanelWidth(): number {
    return getDetailPanelWidth(this.overlayViewportWidth(), this.layoutSize)
  }

  private detailPanelHeight(): number {
    if (this.windowHeightVp <= 0) {
      return 600
    }
    if (this.layoutSize === 'compact') {
      return this.windowHeightVp * 0.75
    }
    if (this.layoutSize === 'medium') {
      const preferredHeight: number = this.windowHeightVp * 0.82
      const availableHeight: number = this.windowHeightVp > 48 ? this.windowHeightVp - 48 : this.windowHeightVp
      return preferredHeight < availableHeight ? preferredHeight : availableHeight
    }
    const preferredHeight: number = this.windowHeightVp * 0.9
    const availableHeight: number = this.windowHeightVp > 64 ? this.windowHeightVp - 64 : this.windowHeightVp
    return preferredHeight < availableHeight ? preferredHeight : availableHeight
  }

  private serviceTypeLabel(type: ServiceCheckType): string {
    if (type === 'HTTP_GET') return 'HTTP GET'
    if (type === 'ICMP_PING') return 'ICMP Ping'
    return 'TCPing'
  }

  private stateLabel(): string {
    if (!this.service.latest) return '未探测'
    return this.service.latest.success ? '正常' : '异常'
  }

  private stateColor(): ResourceColor {
    if (!this.service.latest) return this.themePalette().muted
    return this.service.latest.success ? this.themePalette().success : this.themePalette().danger
  }

  private latencyLabel(result: ServiceCheckResult | null): string {
    if (!result) return '--'
    return `${Math.max(0, Math.round(result.latencyMs))} ms`
  }

  private statusCodeLabel(): string {
    if (!this.service.latest || this.service.latest.statusCode === null) return '--'
    return `${this.service.latest.statusCode}`
  }

  private successCount(): number {
    let count = 0
    for (const result of this.history) {
      if (result.success) count += 1
    }
    return count
  }

  private failureCount(): number {
    return Math.max(0, this.history.length - this.successCount())
  }

  private availabilityPercent(): number {
    if (this.history.length === 0) return 0
    return Math.round(this.successCount() * 1000 / this.history.length) / 10
  }

  private availabilityLabel(): string {
    return `${this.availabilityPercent()}%`
  }

  private availabilityWidth(): string {
    return `${this.availabilityPercent()}%`
  }

  private availabilityColor(): ResourceColor {
    const percent = this.availabilityPercent()
    if (percent >= 99) return this.themePalette().success
    if (percent >= 95) return this.themePalette().warning
    return this.themePalette().danger
  }

  private averageLatencyLabel(): string {
    let total = 0
    let count = 0
    for (const result of this.history) {
      if (!result.success) continue
      total += Math.max(0, result.latencyMs)
      count += 1
    }
    if (count === 0) return '--'
    return `${Math.round(total / count)} ms`
  }

  private historyCountLabel(): string {
    const displayCount = this.historyItems().length
    if (displayCount === this.history.length) return `${displayCount} 条`
    return `显示 ${displayCount}/${this.history.length}`
  }

  private resultDetailLabel(result: ServiceCheckResult): string {
    if (result.error) return result.error
    if (result.success) return '目标响应正常，未发现可用性异常'
    return '本次探测未返回可用响应'
  }

  private compactTime(value: string): string {
    return new Date(value).toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })
  }

  private statusStartLabel(): string {
    const items = this.historyStatusItems()
    if (items.length === 0) return '--'
    return this.compactTime(items[0].result.checkedAt)
  }

  private statusEndLabel(): string {
    const items = this.historyStatusItems()
    if (items.length === 0) return '--'
    return this.compactTime(items[items.length - 1].result.checkedAt)
  }

  private time(value: string | null): string {
    if (!value) return '暂无记录'
    return new Date(value).toLocaleString('zh-CN', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' })
  }

  private checkEnabled(): boolean {
    return this.canRunChecks && this.runningServiceId < 0
  }

  private checkButtonLabel(): string {
    if (!this.canRunChecks) return '无探测权限'
    if (this.runningServiceId === this.service.id) return '探测中…'
    if (this.runningServiceId >= 0) return '其他探测中'
    return '立即探测'
  }

  private historyItems(): OverlayHistoryItem[] {
    const sorted: ServiceCheckResult[] = this.history.slice()
    sorted.sort((left: ServiceCheckResult, right: ServiceCheckResult): number => {
      return new Date(right.checkedAt).getTime() - new Date(left.checkedAt).getTime()
    })
    const items: OverlayHistoryItem[] = []
    let index = 0
    for (const result of sorted.slice(0, 48)) {
      items.push({ key: `${result.checkedAt}-${index}`, result: result })
      index += 1
    }
    return items
  }

  private historyStatusItems(): OverlayHistoryItem[] {
    const items = this.historyItems().slice()
    items.sort((left: OverlayHistoryItem, right: OverlayHistoryItem): number => {
      return new Date(left.result.checkedAt).getTime() - new Date(right.result.checkedAt).getTime()
    })
    const start = Math.max(0, items.length - 28)
    return items.slice(start)
  }
}
