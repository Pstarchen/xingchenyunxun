import { curves } from '@kit.ArkUI'
import { hdsEffect } from '@kit.UIDesignKit'
import { Metric } from '../model/MonitorModels'
import { getThemePalette, ThemeId, ThemePalette } from '../model/ThemeModels'

interface ReferenceScale {
  x: number
  y: number
}

/**
 * The fixed-size icon treatment follows 记得订阅's SubscriptionIcon. The
 * monitor UI supplies a SymbolGlyph resource, so it must not render a second
 * first-letter layer on top of that glyph.
 */
@Component
export struct ReferenceIcon {
  @Prop name: string = ''
  @Prop icon: Resource = $r('sys.symbol.square_grid_2x2')
  @Prop iconSize: number = 52
  @Prop iconRadius: number = 14
  @Prop tint: ResourceColor | undefined = undefined
  @Prop iconBackground: ResourceColor | undefined = undefined
  @StorageLink('themeId') themeId: ThemeId = 'gold'
  @StorageLink('isDarkMode') isDarkMode: boolean = false

  build() {
    Stack({ alignContent: Alignment.Center }) {
      SymbolGlyph(this.icon)
        .fontSize(this.iconSize * 0.5)
        .fontColor([this.tint ?? this.themePalette().text])
        .opacity(0.9)
    }
    .width(this.iconSize)
    .height(this.iconSize)
    .backgroundColor(this.iconBackground ?? this.themePalette().iconPrimary)
    .borderRadius(this.iconRadius)
    .clip(true)
  }

  private themePalette(): ThemePalette {
    return getThemePalette(this.themeId, this.isDarkMode)
  }
}

interface ReferenceChartPoint {
  x: number
  y: number
}

interface ReferenceSeriesSpec {
  color: string
  values: number[]
}

/**
 * History samples may arrive as 0..1 fractions on some backends. A series is
 * treated as fractional only when every finite value is at most 1, then scaled
 * to percent so the chart keeps a single 0..100 domain.
 */
export function normalizePercentSeries(values: number[]): number[] {
  let hasAboveOne = false
  let hasFraction = false
  for (const value of values) {
    if (value > 1) hasAboveOne = true
    else if (value > 0) hasFraction = true
  }
  if (!hasAboveOne && hasFraction) {
    return values.map((value: number): number => Math.max(0, Math.min(100, value * 100)))
  }
  return values.map((value: number): number => Math.max(0, Math.min(100, value)))
}

/**
 * Three real resource series drawn with the same Canvas treatment as
 * accountDL-main's ExpenseChart. Each series is scaled to its own min/max
 * range, so heavily loaded servers still show visible variation instead of
 * three lines pinned to the top of the chart.
 */
@Component
export struct ReferenceMetricTrendChart {
  @Prop @Watch('onHistoryChanged') history: Metric[] = []
  @Prop @Watch('onChartHeightChanged') chartHeight: number = 190
  @StorageLink('themeId') @Watch('onThemeChanged') themeId: ThemeId = 'gold'
  @StorageLink('isDarkMode') @Watch('onThemeChanged') isDarkMode: boolean = false

  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  private chartWidth: number = 360

  onHistoryChanged(): void {
    this.drawChart()
  }

  onThemeChanged(): void {
    this.drawChart()
  }

  onChartHeightChanged(): void {
    this.drawChart()
  }

  build() {
    Canvas(this.context)
      .width('100%')
      .height(this.chartHeight)
      .onReady(() => { this.drawChart() })
      .onAreaChange((_oldValue: Area, newValue: Area) => {
        const width = Number(newValue.width)
        if (width === width && width > 0) this.chartWidth = width
        this.drawChart()
      })
  }

  private numericValue(value: number | undefined | null): number {
    if (typeof value !== 'number') return 0
    if (value !== value) return 0
    if (value === Infinity || value === -Infinity) return 0
    return value
  }

  private withAlpha(hex: string, alpha: number): string {
    const red = parseInt(hex.substring(1, 3), 16)
    const green = parseInt(hex.substring(3, 5), 16)
    const blue = parseInt(hex.substring(5, 7), 16)
    return `rgba(${red}, ${green}, ${blue}, ${alpha})`
  }

  private drawSeries(values: number[], color: string, paddingLeft: number, chartWidth: number, chartTop: number, chartHeight: number): void {
    if (!values.length) return
    let min = values[0]
    let max = values[0]
    for (const value of values) {
      if (value < min) min = value
      if (value > max) max = value
    }
    const range = max - min
    const gap = chartWidth / Math.max(values.length - 1, 1)
    const points: ReferenceChartPoint[] = []
    values.forEach((value: number, index: number) => {
      let ratio = 0.5
      if (range > 0.0001) ratio = (value - min) / range
      points.push({
        x: paddingLeft + index * gap,
        y: chartTop + chartHeight * (1 - ratio)
      })
    })

    const ctx = this.context
    const gradient = ctx.createLinearGradient(0, chartTop, 0, chartTop + chartHeight)
    gradient.addColorStop(0, this.withAlpha(color, 0.13))
    gradient.addColorStop(1, this.withAlpha(color, 0.02))
    ctx.beginPath()
    ctx.moveTo(points[0].x, chartTop + chartHeight)
    points.forEach((point: ReferenceChartPoint) => {
      ctx.lineTo(point.x, point.y)
    })
    ctx.lineTo(points[points.length - 1].x, chartTop + chartHeight)
    ctx.closePath()
    ctx.fillStyle = gradient
    ctx.fill()

    ctx.beginPath()
    points.forEach((point: ReferenceChartPoint, index: number) => {
      if (index === 0) ctx.moveTo(point.x, point.y)
      else ctx.lineTo(point.x, point.y)
    })
    ctx.strokeStyle = color
    ctx.lineWidth = 2.5
    ctx.lineJoin = 'round'
    ctx.lineCap = 'round'
    ctx.stroke()

    points.forEach((point: ReferenceChartPoint) => {
      ctx.beginPath()
      ctx.fillStyle = color
      ctx.arc(point.x, point.y, 3.5, 0, Math.PI * 2)
      ctx.fill()
      ctx.beginPath()
       ctx.fillStyle = this.themePalette().chartInner
      ctx.arc(point.x, point.y, 1.6, 0, Math.PI * 2)
      ctx.fill()
    })
  }

  private drawChart(): void {
    const ctx = this.context
    const width = Math.max(this.chartWidth, 240)
    const height = this.chartHeight
    ctx.clearRect(0, 0, width, height)
    const items = this.history.slice(-24)
    if (!items.length) return

    const paddingLeft = 16
    const paddingRight = 16
    const paddingTop = 16
    const paddingBottom = 22
    const chartWidth = width - paddingLeft - paddingRight
    const chartHeight = height - paddingTop - paddingBottom

    ctx.strokeStyle = this.themePalette().chartGrid
    ctx.lineWidth = 1
    for (let index = 0; index <= 4; index++) {
      const y = paddingTop + chartHeight * index / 4
      ctx.beginPath()
      ctx.moveTo(paddingLeft, y)
      ctx.lineTo(width - paddingRight, y)
      ctx.stroke()
    }

    const series: ReferenceSeriesSpec[] = [
      { color: this.themePalette().primary, values: normalizePercentSeries(items.map((item: Metric): number => this.numericValue(item.cpuUsage))) },
      { color: this.themePalette().success, values: normalizePercentSeries(items.map((item: Metric): number => this.numericValue(item.memoryUsage))) },
      { color: this.themePalette().warning, values: normalizePercentSeries(items.map((item: Metric): number => this.numericValue(item.diskUsage))) }
    ]
    for (const spec of series) {
      this.drawSeries(spec.values, spec.color, paddingLeft, chartWidth, paddingTop, chartHeight)
    }
  }

  private themePalette(): ThemePalette {
    return getThemePalette(this.themeId, this.isDarkMode)
  }
}

/** 记得订阅 SubscriptionCard geometry adapted for monitor rows. */
@Component
export struct ReferenceMonitorCard {
  @Prop title: string = ''
  @Prop subtitle: string = ''
  @Prop value: string = '--'
  @Prop status: string = ''
  @Prop icon: Resource = $r('sys.symbol.square_grid_2x2')
  @Prop accent: ResourceColor | undefined = undefined
  @Prop iconBackground: ResourceColor | undefined = undefined
  @Prop showChevron: boolean = true
  @StorageLink('themeId') themeId: ThemeId = 'gold'
  @StorageLink('isDarkMode') isDarkMode: boolean = false
  onActivate: () => void = () => {}

  @State isPressed: boolean = false
  @State isHovered: boolean = false
  @State hasFocus: boolean = false
  @State lightSource: hdsEffect.PointLightSourceType = hdsEffect.PointLightSourceType.NONE

  build() {
    Stack() {
      Row() {
        ReferenceIcon({ name: this.title, icon: this.icon, iconSize: 52, iconRadius: 14, tint: this.accentColor(), iconBackground: this.iconBackground })
          .margin({ right: 14 })
        Column() {
          Text(this.title)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
             .fontColor(this.themePalette().text)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.subtitle)
            .fontSize(12)
             .fontColor(this.themePalette().secondary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 6 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ right: 8 })
        Column() {
          Text(this.value)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.accentColor())
            .maxLines(1)
          if (this.status) {
            Text(this.status)
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
               .fontColor(this.themePalette().secondary)
              .maxLines(1)
              .margin({ top: 4 })
          }
        }
        .alignItems(HorizontalAlign.End)
        .flexShrink(0)
        if (this.showChevron) {
         SymbolGlyph($r('sys.symbol.chevron_right'))
             .fontSize(14)
              .fontColor([this.isPressed ? this.themePalette().primary : this.themePalette().secondary])
             .opacity(this.isPressed ? 1 : 0.35)
             .margin({ left: 8 })
        }
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    }
    .width('100%')
    .clip(true)
      .backgroundColor(this.isPressed || (this.showChevron && this.isHovered) ? this.themePalette().cardPressed : this.themePalette().card)
    .borderRadius(24)
     .shadow({ radius: 18, color: this.themePalette().shadowStrong, offsetY: 7 })
      .border({
        width: this.hasFocus ? 3 : (this.isPressed || (this.showChevron && this.isHovered) ? 2 : 1),
        color: this.hasFocus || this.isPressed || (this.showChevron && this.isHovered) ? this.themePalette().primary : this.themePalette().border,
        radius: 24
      })
     .scale({ x: this.isPressed ? 0.96 : 1, y: this.isPressed ? 0.96 : 1 })
    .animation({ duration: 180, curve: curves.springMotion(0.6, 0.5) })
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pointLight({
        sourceType: this.lightSource,
        illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER
      })
      .buildEffect())
    .focusable(this.showChevron)
    .focusOnTouch(this.showChevron)
    .onHover((isHover: boolean, _event: HoverEvent) => {
      this.isHovered = this.showChevron && isHover
    })
    .onFocus(() => {
      this.hasFocus = true
    })
    .onBlur(() => {
      this.hasFocus = false
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true
        this.lightSource = hdsEffect.PointLightSourceType.BRIGHT
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false
        this.lightSource = hdsEffect.PointLightSourceType.NONE
      }
    })
    .onClick(() => this.onActivate())
  }

  private themePalette(): ThemePalette {
    return getThemePalette(this.themeId, this.isDarkMode)
  }

  private accentColor(): ResourceColor {
    return this.accent ?? this.themePalette().primary
  }
}

/** Compact network-service card with a shared transition target. */
@Component
export struct ReferenceServiceSummaryCard {
  @Prop serviceName: string = ''
  @Prop typeText: string = ''
  @Prop targetText: string = ''
  @Prop stateText: string = ''
  @Prop latencyText: string = '--'
  @Prop stateColor: ResourceColor | undefined = undefined
  @Prop iconBackground: ResourceColor | undefined = undefined
  @Prop serviceEnabled: boolean = true
  @Prop transitionId: string = ''
  @Prop detailVisible: boolean = false
  @StorageLink('themeId') themeId: ThemeId = 'gold'
  @StorageLink('isDarkMode') isDarkMode: boolean = false
  onActivate: () => void = () => {}

  @State isPressed: boolean = false
  @State isHovered: boolean = false
  @State hasFocus: boolean = false
  @State lightSource: hdsEffect.PointLightSourceType = hdsEffect.PointLightSourceType.NONE

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width('100%')
        .constraintSize({ minHeight: 126 })
        .visibility(Visibility.Hidden)
      if (!this.detailVisible) {
        Column({ space: 10 }) {
          Row() {
            ReferenceIcon({
              name: this.serviceName,
              icon: $r('sys.symbol.share'),
              iconSize: 48,
              iconRadius: 15,
              tint: this.resolvedStateColor(),
              iconBackground: this.iconBackground
            }).margin({ right: 12 })
            Column() {
              Text(this.serviceName)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.themePalette().text)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(`${this.typeText} · ${this.serviceEnabled ? '已启用' : '已停用'}`)
                .fontSize(11)
                .fontColor(this.themePalette().secondary)
                .margin({ top: 5 })
                .maxLines(1)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            .margin({ right: 8 })
            Column() {
              Text(this.stateText)
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.resolvedStateColor())
                .maxLines(1)
              Text(this.latencyText)
                .fontSize(11)
                .fontColor(this.themePalette().secondary)
                .margin({ top: 4 })
                .maxLines(1)
            }.alignItems(HorizontalAlign.End)
          }.width('100%')
          Row() {
            Text(this.targetText)
              .fontSize(12)
              .fontColor(this.themePalette().secondary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            Text('查看详情')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.themePalette().primary)
              .margin({ left: 10 })
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(13)
              .fontColor([this.themePalette().primary])
              .opacity(this.isPressed ? 1 : 0.55)
              .margin({ left: 4 })
          }.width('100%')
        }
        .width('100%')
        .constraintSize({ minHeight: 126 })
        .justifyContent(FlexAlign.Center)
        .padding({ left: 15, right: 15, top: 14, bottom: 14 })
        .clip(true)
        .backgroundColor(this.isPressed || this.isHovered ? this.themePalette().cardPressed : this.themePalette().card)
        .borderRadius(24)
        .shadow({ radius: 18, color: this.themePalette().shadowStrong, offsetY: 7 })
        .border({
          width: this.hasFocus ? 3 : (this.isPressed || this.isHovered ? 2 : 1),
          color: this.hasFocus || this.isPressed || this.isHovered ? this.themePalette().primary : this.themePalette().border,
          radius: 24
        })
        .geometryTransition(this.transitionId)
        .transition(TransitionEffect.OPACITY)
        .scale({ x: this.isPressed ? 0.96 : 1, y: this.isPressed ? 0.96 : 1 })
        .animation({ duration: 180, curve: curves.springMotion(0.6, 0.5) })
        .visualEffect(new hdsEffect.HdsEffectBuilder()
          .pointLight({
            sourceType: this.lightSource,
            illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER
          })
          .buildEffect())
        .focusable(true)
        .focusOnTouch(true)
        .onHover((isHover: boolean, _event: HoverEvent) => {
          this.isHovered = isHover
        })
        .onFocus(() => {
          this.hasFocus = true
        })
        .onBlur(() => {
          this.hasFocus = false
        })
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
          this.onActivate()
        })
      }
    }.width('100%').constraintSize({ minHeight: 126 })
  }

  private themePalette(): ThemePalette {
    return getThemePalette(this.themeId, this.isDarkMode)
  }

  private resolvedStateColor(): ResourceColor {
    return this.stateColor ?? this.themePalette().muted
  }
}

/** Resource-overview card geometry reused by settings rows. */
@Component
export struct ReferenceSettingCard {
  @Prop title: string = ''
  @Prop subtitle: string = ''
  @Prop icon: Resource = $r('sys.symbol.gearshape')
  @Prop accent: ResourceColor | undefined = undefined
  @Prop iconBackground: ResourceColor | undefined = undefined
  @Prop showChevron: boolean = false
  @Prop destructive: boolean = false
  @StorageLink('themeId') themeId: ThemeId = 'gold'
  @StorageLink('isDarkMode') isDarkMode: boolean = false
  onActivate: () => void = () => {}

  @State isPressed: boolean = false
  @State isHovered: boolean = false
  @State hasFocus: boolean = false
  @State lightSource: hdsEffect.PointLightSourceType = hdsEffect.PointLightSourceType.NONE

  build() {
    Row() {
      ReferenceIcon({ name: this.title, icon: this.icon, iconSize: 52, iconRadius: 14, tint: this.accentColor(), iconBackground: this.iconBackground })
        .margin({ right: 14 })
      Column() {
        Text(this.title)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
           .fontColor(this.destructive ? this.accentColor() : this.themePalette().text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.subtitle)
          .fontSize(12)
           .fontColor(this.themePalette().secondary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 6 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ right: this.showChevron ? 8 : 0 })
      if (this.showChevron) {
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(14)
           .fontColor([this.isPressed ? this.themePalette().primary : this.themePalette().secondary])
          .opacity(this.isPressed ? 1 : 0.35)
      }
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .clip(true)
    .backgroundColor(this.isPressed || (this.showChevron && this.isHovered) ? this.themePalette().cardPressed : this.themePalette().card)
    .borderRadius(24)
    .shadow({ radius: 18, color: this.themePalette().shadowStrong, offsetY: 7 })
    .border({
      width: this.hasFocus ? 3 : (this.isPressed || (this.showChevron && this.isHovered) ? 2 : 1),
      color: this.hasFocus || this.isPressed || (this.showChevron && this.isHovered) ? this.themePalette().primary : this.themePalette().border,
      radius: 24
    })
    .scale({ x: this.isPressed ? 0.96 : 1, y: this.isPressed ? 0.96 : 1 })
    .animation({ duration: 180, curve: curves.springMotion(0.6, 0.5) })
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pointLight({
        sourceType: this.lightSource,
        illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER
      })
      .buildEffect())
    .focusable(this.showChevron)
    .focusOnTouch(this.showChevron)
    .onHover((isHover: boolean, _event: HoverEvent) => {
      this.isHovered = this.showChevron && isHover
    })
    .onFocus(() => {
      this.hasFocus = true
    })
    .onBlur(() => {
      this.hasFocus = false
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true
        this.lightSource = hdsEffect.PointLightSourceType.BRIGHT
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false
        this.lightSource = hdsEffect.PointLightSourceType.NONE
      }
    })
    .onClick(() => this.onActivate())
  }

  private themePalette(): ThemePalette {
    return getThemePalette(this.themeId, this.isDarkMode)
  }

  private accentColor(): ResourceColor {
    return this.accent ?? this.themePalette().primary
  }
}

/** Resource-overview card geometry reused by settings toggles. */
@Component
export struct ReferenceSettingSwitchCard {
  @Prop title: string = ''
  @Prop subtitle: string = ''
  @Prop value: boolean = false
  @Prop icon: Resource = $r('sys.symbol.gearshape')
  @Prop accent: ResourceColor | undefined = undefined
  @Prop iconBackground: ResourceColor | undefined = undefined
  @StorageLink('themeId') themeId: ThemeId = 'gold'
  @StorageLink('isDarkMode') isDarkMode: boolean = false
  onChange: (value: boolean) => void = (_value: boolean) => {}

  @State isPressed: boolean = false
  @State lightSource: hdsEffect.PointLightSourceType = hdsEffect.PointLightSourceType.NONE

  build() {
    Row() {
      ReferenceIcon({ name: this.title, icon: this.icon, iconSize: 52, iconRadius: 14, tint: this.accentColor(), iconBackground: this.iconBackground })
        .margin({ right: 14 })
      Column() {
        Text(this.title)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
           .fontColor(this.themePalette().text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.subtitle)
          .fontSize(12)
           .fontColor(this.themePalette().secondary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 6 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ right: 12 })
      Toggle({ type: ToggleType.Switch, isOn: this.value })
        .selectedColor(this.accentColor())
        .onChange(this.onChange)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .clip(true)
    .backgroundColor(this.themePalette().card)
    .borderRadius(24)
    .shadow({ radius: 18, color: this.themePalette().shadowStrong, offsetY: 7 })
    .border({ width: 1, color: this.themePalette().border, radius: 24 })
    .scale({ x: this.isPressed ? 0.98 : 1, y: this.isPressed ? 0.98 : 1 })
    .animation({ duration: 180, curve: curves.springMotion(0.6, 0.5) })
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
  }

  private themePalette(): ThemePalette {
    return getThemePalette(this.themeId, this.isDarkMode)
  }

  private accentColor(): ResourceColor {
    return this.accent ?? this.themePalette().primary
  }
}

/** Same hero-card treatment as 记得订阅's DashboardCard. */
@Component
export struct ReferenceDashboardCard {
  @Prop eyebrow: string = ''
  @Prop value: string = '--'
  @Prop detail: string = ''
  @Prop footnote: string = ''
  @Prop icon: Resource = $r('sys.symbol.square_grid_2x2')
  @StorageLink('themeId') themeId: ThemeId = 'gold'
  @StorageLink('isDarkMode') isDarkMode: boolean = false
  onActivate: () => void = () => {}
  @State isPressed: boolean = false
  @State isHovered: boolean = false
  @State hasFocus: boolean = false
  @State lightSource: hdsEffect.PointLightSourceType = hdsEffect.PointLightSourceType.NONE

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Row() {
          Column() {
             Text(this.eyebrow).fontSize(14).fontColor(this.themePalette().heroText).opacity(0.72)
             Text(this.value).fontSize(40).fontWeight(FontWeight.Bold).fontColor(this.themePalette().heroText).margin({ top: 6 })
             Text(this.detail).fontSize(12).fontColor(this.themePalette().heroText).opacity(0.66).margin({ top: 5 }).maxLines(2)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Stack({ alignContent: Alignment.Center }) {
            Column().width(58).height(58).backgroundColor(this.themePalette().heroText).opacity(0.12).borderRadius(29)
            SymbolGlyph(this.icon).fontSize(29).fontColor([this.themePalette().heroText])
          }
        }
        .width('100%')
         Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.arrow_clockwise')).fontSize(13).fontColor([this.themePalette().heroStart])
            Text(this.footnote).fontSize(11).fontWeight(FontWeight.Medium).fontColor(this.themePalette().heroStart)
         }
         .padding({ left: 9, right: 9, top: 5, bottom: 5 })
          .backgroundColor(this.themePalette().heroText)
          .opacity(0.9)
        .borderRadius(12)
        .margin({ top: 14 })
        .alignSelf(ItemAlign.Start)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(18)
     .linearGradient({ angle: 135, colors: [[this.themePalette().heroStart, 0.0], [this.themePalette().heroEnd, 1.0]] })
     .shadow({ radius: 30, color: this.themePalette().heroShadow, offsetY: 12 })
    .borderRadius(28)
    .clip(true)
    .border({
      width: this.hasFocus ? 3 : (this.isHovered ? 2 : 0),
      color: this.hasFocus ? this.themePalette().primary : this.themePalette().heroText,
      radius: 28
    })
    .scale({
      x: this.isPressed ? 0.98 : (this.isHovered ? 1.01 : 1),
      y: this.isPressed ? 0.98 : (this.isHovered ? 1.01 : 1)
    })
    .animation({ curve: curves.springMotion(0.55, 0.7) })
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pointLight({
        sourceType: this.lightSource,
        illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER
      })
      .buildEffect())
    .focusable(true)
    .focusOnTouch(true)
    .onHover((isHover: boolean, _event: HoverEvent) => {
      this.isHovered = isHover
    })
    .onFocus(() => {
      this.hasFocus = true
    })
    .onBlur(() => {
      this.hasFocus = false
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true
        this.lightSource = hdsEffect.PointLightSourceType.BRIGHT
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false
        this.lightSource = hdsEffect.PointLightSourceType.NONE
      }
    })
    .onClick(() => this.onActivate())
  }

  private themePalette(): ThemePalette {
    return getThemePalette(this.themeId, this.isDarkMode)
  }
}

@Component
export struct ReferenceTabBarItem {
  @Prop index: number = 0
  @Prop currentIndex: number = 0
  @Prop name: string = ''
  @Prop icon: Resource = $r('sys.symbol.house')
  @Prop showRedDot: boolean = false
  @StorageLink('themeId') themeId: ThemeId = 'gold'
  @StorageLink('isDarkMode') isDarkMode: boolean = false
  onSelect: () => void = () => {}
  @Prop indicatorScale: ReferenceScale = { x: 1, y: 1 }
  @State scaleVal: number = 1
  @State isHovered: boolean = false
  @State hasFocus: boolean = false

  build() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        if (this.currentIndex === this.index) {
          Stack() {
            Column().width('100%').height('100%').backgroundColor(this.themePalette().heroText).opacity(0.18).backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN).borderRadius(28)
            Column().width('100%').height('100%').border({ width: 0.5, color: this.themePalette().heroText, radius: 28 }).opacity(0.15)
            Column().width('100%').height('100%').linearGradient({ angle: 135, colors: [[this.themePalette().heroText, 0.5], [this.themePalette().heroText, 0.0], [this.themePalette().heroText, 0.2] ] }).borderRadius(28)
          }
          .width('100%').height('100%').borderRadius(28)
           .shadow({ radius: 12, color: this.themePalette().navIndicator, offsetY: 2 })
          .geometryTransition('reference_tab_indicator')
          .scale({ x: this.indicatorScale.x, y: this.indicatorScale.y })
          .transition(TransitionEffect.OPACITY.animation({ duration: 250 }))
        }
        Column() {
          SymbolGlyph(this.icon)
            .fontSize(22)
            .fontColor([this.currentIndex === this.index ? this.themePalette().primary : this.themePalette().secondary])
            .scale({ x: (this.currentIndex === this.index ? 1.1 : 1) * this.scaleVal, y: (this.currentIndex === this.index ? 1.1 : 1) * this.scaleVal })
            .animation({ duration: 350, curve: curves.springMotion(0.4, 0.8) })
          Text(this.name).fontSize(9).fontColor(this.currentIndex === this.index ? this.themePalette().primary : this.themePalette().secondary).margin({ top: 1 }).opacity(this.currentIndex === this.index ? 1 : 0.6).fontWeight(this.currentIndex === this.index ? FontWeight.Medium : FontWeight.Normal)
        }.justifyContent(FlexAlign.Center)
        if (this.showRedDot) Circle({ width: 6, height: 6 }).fill(Color.Red).position({ right: 6, top: 12 })
      }
      .width('100%').height('100%')
    }
    .width(54).height('100%').justifyContent(FlexAlign.Center)
    .backgroundColor(this.isHovered ? this.themePalette().cardPressed : Color.Transparent)
    .borderRadius(28)
    .border({
      width: this.hasFocus ? 3 : (this.isHovered ? 1 : 0),
      color: this.hasFocus ? this.themePalette().primary : this.themePalette().border,
      radius: 28
    })
    .focusable(true)
    .focusOnTouch(true)
    .onHover((isHover: boolean, _event: HoverEvent) => {
      this.isHovered = isHover
    })
    .onFocus(() => {
      this.hasFocus = true
    })
    .onBlur(() => {
      this.hasFocus = false
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) this.scaleVal = 0.9
      else if (event.type === TouchType.Up || event.type === TouchType.Cancel) this.scaleVal = 1
    })
    .onClick(() => this.onSelect())
  }

  private themePalette(): ThemePalette {
    return getThemePalette(this.themeId, this.isDarkMode)
  }
}

@Component
export struct ReferenceFloatingTabBar {
  @Prop currentIndex: number = 0
  @Prop showAlertDot: boolean = false
  @Prop bottomInset: number = 0
  @StorageLink('themeId') themeId: ThemeId = 'gold'
  @StorageLink('isDarkMode') isDarkMode: boolean = false
  onSelect: (index: number) => void = (_index: number) => {}
  @State indicatorScale: ReferenceScale = { x: 1, y: 1 }

  build() {
    Row() {
      ReferenceTabBarItem({ index: 0, currentIndex: this.currentIndex, name: '概览', icon: $r('sys.symbol.house'), indicatorScale: this.indicatorScale, onSelect: () => this.onSelect(0) })
      ReferenceTabBarItem({ index: 1, currentIndex: this.currentIndex, name: '服务器', icon: $r('sys.symbol.square_grid_2x2'), indicatorScale: this.indicatorScale, onSelect: () => this.onSelect(1) })
      ReferenceTabBarItem({ index: 2, currentIndex: this.currentIndex, name: '告警', icon: $r('sys.symbol.bell'), showRedDot: this.showAlertDot, indicatorScale: this.indicatorScale, onSelect: () => this.onSelect(2) })
      ReferenceTabBarItem({ index: 3, currentIndex: this.currentIndex, name: '设置', icon: $r('sys.symbol.person'), indicatorScale: this.indicatorScale, onSelect: () => this.onSelect(3) })
    }
    .width('calc(100% - 32vp)')
    .height(56)
    .backgroundBlurStyle(BlurStyle.Thin)
    .backgroundColor(this.themePalette().navBackground)
    .borderRadius(28)
    .shadow({ radius: 16, color: this.themePalette().shadow, offsetY: 4 })
    .justifyContent(FlexAlign.SpaceAround)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 4, right: 4 })
    .margin({ bottom: this.bottomInset + 8 })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  private themePalette(): ThemePalette {
    return getThemePalette(this.themeId, this.isDarkMode)
  }
}

@Component
export struct ReferenceHeaderActionButton {
  @Prop icon: Resource = $r('sys.symbol.arrow_clockwise')
  @Prop angle: number = 0
  action: () => void = () => {}
  @StorageLink('themeId') themeId: ThemeId = 'gold'
  @StorageLink('isDarkMode') isDarkMode: boolean = false
  @State isPressed: boolean = false
  @State lightSource: hdsEffect.PointLightSourceType = hdsEffect.PointLightSourceType.NONE

  build() {
    Button() {
      SymbolGlyph(this.icon).fontSize(24).fontColor([this.themePalette().text]).rotate({ angle: this.angle }).animation({ duration: 800, curve: Curve.FastOutSlowIn })
    }
    .width(40).height(40).type(ButtonType.Circle).backgroundColor(Color.Transparent)
    .scale({ x: this.isPressed ? 0.86 : 1, y: this.isPressed ? 0.86 : 1 })
    .opacity(this.isPressed ? 0.7 : 1)
    .animation({ duration: 160, curve: curves.springMotion(0.6, 0.5) })
    .visualEffect(new hdsEffect.HdsEffectBuilder().pointLight({ sourceType: this.lightSource, illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER }).buildEffect())
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.isPressed = true
        this.lightSource = hdsEffect.PointLightSourceType.BRIGHT
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false
        this.lightSource = hdsEffect.PointLightSourceType.NONE
      }
    })
    .onClick(() => this.action())
  }

  private themePalette(): ThemePalette {
    return getThemePalette(this.themeId, this.isDarkMode)
  }
}
