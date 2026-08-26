import { hdsMaterial, HdsNavDestination, HdsNavigation, HdsNavigationAttribute, HdsNavigationIconOptions, HdsNavigationMenuContentOptions, HdsNavigationMenuItemOptions, HdsNavigationTitleBarOptions, HdsNavigationTitleBarStyle, HdsNavigationTitleMode, HdsTabs, HdsTabsAttribute, HdsTabsController, ScrollEffectOptions, ScrollEffectType, TitleBarContentOptions, TitleBarStyleOptions } from '@kit.UIDesignKit'
import { curves, SymbolGlyphModifier } from '@kit.ArkUI'
import { abilityAccessCtrl, common, ConfigurationConstant } from '@kit.AbilityKit'
import { pasteboard } from '@kit.BasicServicesKit'
import { AlertEvent, Dashboard, Device, DeviceStatus, Metric, MonitorConnection, NetworkService, ServiceMetric } from '../model/MonitorModels'
import { MonitorApi, MonitorApiError } from '../utils/MonitorApi'
import { MonitorSettings, MonitorStorage } from '../utils/MonitorStorage'
import { chooseBindingQr, normalizeBindingBaseUrl, normalizeBindingToken, parseBindingPayload } from '../utils/QrCodeReader'
import { normalizePercentSeries, ReferenceDashboardCard, ReferenceHeaderActionButton, ReferenceIcon, ReferenceMetricTrendChart, ReferenceMonitorCard, ReferenceSettingCard, ReferenceSettingSwitchCard } from '../view/ReferenceComponents'
import { ServiceAvailabilityView } from '../view/ServiceAvailabilityView'
import { ColorModePreference, getThemePalette, THEME_OPTIONS, ThemeId, ThemeOption, ThemePalette } from '../model/ThemeModels'
import { AGREEMENT_DOCUMENT_TITLE_KEY, AGREEMENT_DOCUMENT_URL_KEY, AGREEMENT_VERSION, AgreementGateState, PRIVACY_POLICY_URL, USER_AGREEMENT_URL } from '../model/AgreementModels'
import { AppLifecycle } from '../utils/AppLifecycle'
import { getContentMaxWidth, getNavigationWidth, getPageHorizontalPadding, getSheetWidth, getTrendChartHeight, LayoutSize } from '../model/ResponsiveLayout'

type AppPage = 'overview' | 'devices' | 'services' | 'alerts' | 'settings'
const DEVICE_DETAIL_ROUTE_PREFIX: string = 'device-detail:'

let COLORS: ThemePalette = getThemePalette('gold', false)

@Entry
@Component
struct Index {
  @State page: AppPage = 'overview'
  @State connection: MonitorConnection | null = null
  @State baseUrlInput: string = ''
  @State tokenInput: string = ''
  @State dashboard: Dashboard | null = null
  @State deviceList: Device[] = []
  @State alerts: AlertEvent[] = []
  @State services: NetworkService[] = []
  @State isLoading: boolean = false
  @State servicesLoading: boolean = false
  @State isScanning: boolean = false
  @State errorMessage: string = ''
  @State servicesErrorMessage: string = ''
  @State lastUpdated: string = ''
  @State bindingNotice: string = ''
  @State showBindingSheet: boolean = false
  @State showAppearanceSheet: boolean = false
  @State showToken: boolean = false
  @State refreshAngle: number = 0
  @State alertRevision: number = 0
  @State deviceRevision: number = 0
  @State serviceRevision: number = 0
  @State runningServiceId: number = -1
  @State serviceDetailVisible: boolean = false
  @State serviceDetailBackRequest: number = 0
  @State contentVisible: boolean = false
  @State introVisible: boolean = false
  @State summaryVisible: boolean = false
  @State listsVisible: boolean = false
  @State overviewPageVisible: boolean = false
  @State devicesPageVisible: boolean = false
  @State servicesPageVisible: boolean = false
  @State alertsPageVisible: boolean = false
  @State settingsPageVisible: boolean = false
  @State currentIndex: number = 0
  @StorageLink('themeId') @Watch('onThemeStateChanged') themeId: ThemeId = 'gold'
  @StorageLink('colorModePreference') colorModePreference: ColorModePreference = 'SYSTEM'
  @StorageLink('isDarkMode') @Watch('onThemeStateChanged') isDarkMode: boolean = false
  @StorageLink('systemColorMode') systemColorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
  @StorageLink('topRectHeight') topRectHeight: number = 0
  @StorageLink('bottomRectHeight') bottomRectHeight: number = 0
  @StorageProp('layoutSize') layoutSize: LayoutSize = 'compact'
  @StorageProp('windowWidthVp') windowWidthVp: number = 0
  @StorageProp('windowHeightVp') windowHeightVp: number = 0
  @State autoRefreshEnabled: boolean = true
  @State refreshIntervalSeconds: number = 30
  @State showSensitiveValues: boolean = false
  @State overviewCpuText: string = '--'
  @State overviewMemoryText: string = '--'
  @State overviewDiskText: string = '--'
  @State overviewNetworkText: string = '--'
  @State agreementGateState: AgreementGateState = 'checking'
  @State agreementSaving: boolean = false
  @State agreementExiting: boolean = false
  @State agreementErrorMessage: string = ''

  private context: common.Context | null = null
  private storage: MonitorStorage = MonitorStorage.getInstance()
  private refreshTimer: number = -1
  private pageEntranceTimer: number = -1
  private dataRequesting: boolean = false
  private pageEntranceToken: number = 0
  private tabsController: HdsTabsController = new HdsTabsController()
  private overviewScroller: Scroller = new Scroller()
  private devicesScroller: Scroller = new Scroller()
  private servicesScroller: Scroller = new Scroller()
  private alertsScroller: Scroller = new Scroller()
  private settingsScroller: Scroller = new Scroller()
  @Provide('pageStack') pageStack: NavPathStack = new NavPathStack()

  aboutToAppear(): void {
    this.updateThemePalette()
    this.context = this.getUIContext().getHostContext() as common.Context
    this.tabsController.bindScroller(0, this.overviewScroller)
    this.tabsController.bindScroller(1, this.devicesScroller)
    this.tabsController.bindScroller(2, this.servicesScroller)
    this.tabsController.bindScroller(3, this.alertsScroller)
    this.tabsController.bindScroller(4, this.settingsScroller)
    this.restartPageEntrance(0)
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 420, curve: curves.springMotion(0.45, 0.78) }, () => {
        this.contentVisible = true
        this.introVisible = true
      })
      setTimeout(() => {
        this.getUIContext().animateTo({ duration: 420, curve: curves.springMotion(0.48, 0.76) }, () => {
          this.summaryVisible = true
        })
      }, 70)
      setTimeout(() => {
        this.getUIContext().animateTo({ duration: 460, curve: curves.springMotion(0.52, 0.74) }, () => {
          this.listsVisible = true
        })
      }, 140)
    }, 30)
    this.initialize()
  }

  aboutToDisappear(): void {
    if (this.refreshTimer >= 0) {
      clearInterval(this.refreshTimer)
      this.refreshTimer = -1
    }
    if (this.pageEntranceTimer >= 0) {
      clearTimeout(this.pageEntranceTimer)
      this.pageEntranceTimer = -1
    }
    this.pageEntranceToken += 1
    this.tabsController.unbindScroller(this.overviewScroller)
    this.tabsController.unbindScroller(this.devicesScroller)
    this.tabsController.unbindScroller(this.servicesScroller)
    this.tabsController.unbindScroller(this.alertsScroller)
    this.tabsController.unbindScroller(this.settingsScroller)
  }

  onBackPress(): boolean {
    if (this.showBindingSheet && this.agreementGateState !== 'accepted') return true
    return this.onBackPressed()
  }

  onPageShow(): void {
    if (this.agreementGateState === 'required') this.showBindingSheet = true
  }

  private async initialize(): Promise<void> {
    if (!this.context) return
    try {
      await this.storage.init(this.context)
      const acceptedAgreementVersion = await this.storage.loadAgreementVersion()
      this.agreementGateState = acceptedAgreementVersion === AGREEMENT_VERSION ? 'accepted' : 'required'
      const savedTheme = await this.storage.loadThemeSettings()
      this.themeId = savedTheme.themeId
      this.colorModePreference = savedTheme.colorModePreference
      this.applyColorModePreference()
      const savedSettings = await this.storage.loadSettings()
      this.autoRefreshEnabled = savedSettings.autoRefreshEnabled
      this.refreshIntervalSeconds = savedSettings.refreshIntervalSeconds
      this.showSensitiveValues = savedSettings.showSensitiveValues
      const saved = await this.storage.loadConnection()
      if (saved) {
        this.connection = saved
        this.baseUrlInput = saved.baseUrl
        this.tokenInput = saved.token
      }
      if (this.agreementGateState === 'required') {
        this.presentBindingSheet()
      } else if (saved) {
        await this.loadData(false)
        this.startPolling()
      } else {
        this.presentBindingSheet()
      }
    } catch (_) {
      this.agreementGateState = 'required'
      this.errorMessage = '本地配置读取失败，请重新绑定服务器'
      this.presentBindingSheet()
    }
  }

  private updateThemePalette(): void {
    COLORS = getThemePalette(this.themeId, this.isDarkMode)
  }

  private contentBottomInset(): number {
    return 120 + this.getUIContext().px2vp(this.bottomRectHeight)
  }

  private isCompactLayout(): boolean {
    return this.layoutSize === 'compact'
  }

  private isExpandedLayout(): boolean {
    return this.layoutSize === 'expanded'
  }

  private responsiveWindowWidth(): number {
    return this.windowWidthVp > 0 ? this.windowWidthVp : 360
  }

  private contentViewportWidth(): number {
    const viewportWidth: number = this.responsiveWindowWidth() - getNavigationWidth(this.layoutSize)
    return viewportWidth > 0 ? viewportWidth : this.responsiveWindowWidth()
  }

  private pageContainerWidth(): number {
    const viewportWidth: number = this.contentViewportWidth()
    const maximumWidth: number = getContentMaxWidth(this.layoutSize, viewportWidth)
    return viewportWidth < maximumWidth ? viewportWidth : maximumWidth
  }

  private bindingSheetWidth(): number {
    return getSheetWidth(this.responsiveWindowWidth(), this.layoutSize, 560, 640)
  }

  private appearanceSheetWidth(): number {
    return getSheetWidth(this.responsiveWindowWidth(), this.layoutSize, 600, 720)
  }

  private onThemeStateChanged(): void {
    this.updateThemePalette()
  }

  private themePalette(): ThemePalette {
    return getThemePalette(this.themeId, this.isDarkMode)
  }

  private onBackPressed(): boolean {
    if (this.serviceDetailVisible) {
      this.serviceDetailBackRequest += 1
      return true
    }
    return false
  }

  private applyColorModePreference(): void {
    if (!this.context) return
    let colorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
    if (this.colorModePreference === 'LIGHT') colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
    if (this.colorModePreference === 'DARK') colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK
    if (this.colorModePreference === 'LIGHT') this.isDarkMode = false
    else if (this.colorModePreference === 'DARK') this.isDarkMode = true
    else this.isDarkMode = this.systemColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK
    try {
      this.context.getApplicationContext().setColorMode(colorMode)
    } catch (_) {
    }
    this.updateThemePalette()
  }

  private async saveThemeSettings(): Promise<void> {
    await this.storage.saveThemeSettings({ themeId: this.themeId, colorModePreference: this.colorModePreference })
  }

  private async chooseTheme(theme: ThemeId): Promise<void> {
    this.themeId = theme
    this.updateThemePalette()
    await this.saveThemeSettings()
    this.toast('主题颜色已更新')
  }

  private async chooseColorMode(mode: ColorModePreference): Promise<void> {
    this.colorModePreference = mode
    this.applyColorModePreference()
    await this.saveThemeSettings()
    this.toast(mode === 'SYSTEM' ? '已跟随系统深浅色' : mode === 'DARK' ? '已切换为深色模式' : '已切换为浅色模式')
  }

  private colorModeLabel(): string {
    if (this.colorModePreference === 'DARK') return '深色模式'
    if (this.colorModePreference === 'LIGHT') return '浅色模式'
    return '跟随系统'
  }

  private presentBindingSheet(): void {
    this.showBindingSheet = true
  }

  private openBindingSheet(): void {
    if (this.agreementGateState !== 'accepted') {
      this.presentBindingSheet()
      return
    }
    if (this.connection) {
      this.baseUrlInput = this.connection.baseUrl
      this.tokenInput = this.connection.token
    }
    this.bindingNotice = ''
    this.showToken = false
    this.presentBindingSheet()
  }

  private async openAgreementDocument(title: string, url: string): Promise<void> {
    AppStorage.setOrCreate(AGREEMENT_DOCUMENT_TITLE_KEY, title)
    AppStorage.setOrCreate(AGREEMENT_DOCUMENT_URL_KEY, url)
    try {
      await this.getUIContext().getRouter().pushUrl({ url: 'pages/AgreementWeb' })
    } catch (_) {
      this.agreementErrorMessage = '协议页面暂时无法打开，请稍后重试'
    }
  }

  private async acceptAgreement(): Promise<void> {
    if (this.agreementSaving || this.agreementExiting) return
    this.agreementSaving = true
    this.agreementErrorMessage = ''
    const saved = await this.storage.saveAgreementVersion(AGREEMENT_VERSION)
    if (!saved) {
      this.agreementErrorMessage = '同意状态保存失败，请重试'
      this.agreementSaving = false
      return
    }
    this.agreementGateState = 'accepted'
    this.agreementSaving = false
    if (this.connection) {
      await this.loadData(false)
      this.startPolling()
    }
  }

  private async rejectAgreement(): Promise<void> {
    if (this.agreementSaving || this.agreementExiting) return
    this.agreementExiting = true
    this.agreementErrorMessage = ''
    const abilityContext = AppLifecycle.getAbilityContext()
    if (!abilityContext) {
      this.agreementErrorMessage = '暂时无法退出应用，请稍后重试'
      this.agreementExiting = false
      return
    }
    try {
      await abilityContext.terminateSelf()
    } catch (_) {
      this.agreementErrorMessage = '退出应用失败，请稍后重试'
      this.agreementExiting = false
    }
  }

  private openAppearanceSheet(): void {
    this.showAppearanceSheet = true
  }

  private startPolling(): void {
    if (this.refreshTimer >= 0) clearInterval(this.refreshTimer)
    this.refreshTimer = -1
    if (!this.autoRefreshEnabled || !this.connection) return
    this.refreshTimer = setInterval(() => {
      if (this.autoRefreshEnabled && this.connection && !this.isLoading) this.loadData(true)
    }, this.refreshIntervalSeconds * 1000)
  }

  private async saveSettings(): Promise<void> {
    const settings: MonitorSettings = {
      autoRefreshEnabled: this.autoRefreshEnabled,
      refreshIntervalSeconds: this.refreshIntervalSeconds,
      showSensitiveValues: this.showSensitiveValues
    }
    await this.storage.saveSettings(settings)
  }

  private async copyToken(): Promise<void> {
    const token = this.connection?.token
    if (!token) {
      this.toast('暂无可复制的 Token')
      return
    }
    try {
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, token)
      const systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard()
      await systemPasteboard.setData(data)
      this.toast('Token 已复制到剪贴板')
    } catch (_) {
      this.toast('Token 复制失败，请重试')
    }
  }

  private refreshIntervalLabel(): string {
    if (this.refreshIntervalSeconds < 60) return `${this.refreshIntervalSeconds} 秒`
    return `${this.refreshIntervalSeconds / 60} 分钟`
  }

  private refreshIntervalFromIndex(index: number): number {
    if (index === 0) return 15
    if (index === 1) return 30
    if (index === 2) return 60
    return 300
  }

  private async chooseRefreshInterval(): Promise<void> {
    try {
      const result = await this.getUIContext().getPromptAction().showActionMenu({
        title: '刷新频率',
        buttons: [
          { text: '15 秒', color: COLORS.text },
          { text: '30 秒', color: COLORS.text },
          { text: '1 分钟', color: COLORS.text },
          { text: '5 分钟', color: COLORS.text }
        ]
      })
      this.refreshIntervalSeconds = this.refreshIntervalFromIndex(result.index)
      await this.saveSettings()
      this.startPolling()
      this.toast(`已设置为每 ${this.refreshIntervalLabel()} 自动刷新`)
    } catch (_) {
    }
  }

  private api(): MonitorApi | null {
    return this.connection ? new MonitorApi(this.connection) : null
  }

  private async loadData(background: boolean): Promise<void> {
    const client = this.api()
    if (!client) return
    if (this.dataRequesting) return
    this.dataRequesting = true
    if (!background) this.isLoading = true
    this.servicesLoading = true
    this.errorMessage = ''
    try {
      this.dashboard = await client.dashboard()
      this.deviceList = this.dashboard.devices.slice()
      try {
        this.deviceList = await client.devices()
      } catch (_) {
      }
      this.deviceRevision += 1
      this.overviewCpuText = this.percent(this.overviewCpu())
      this.overviewMemoryText = this.percent(this.overviewMemory())
      this.overviewDiskText = this.percent(this.overviewDisk())
      this.overviewNetworkText = this.rate(this.overviewNetwork())
      try {
        this.alerts = await client.alerts()
      } catch (error) {
        const alertError = error as MonitorApiError
        if (alertError?.status === 403) {
          // Dashboard already includes the recent, server-filtered alerts.
          // Keep those visible when a token intentionally omits alert:read.
          this.alerts = this.dashboard?.recentAlerts ?? []
        } else {
          throw new MonitorApiError(alertError?.message ?? '告警数据加载失败', alertError?.status ?? 0)
        }
      }
      this.alertRevision += 1
      try {
        this.services = await client.services()
        this.serviceRevision += 1
        this.servicesErrorMessage = ''
      } catch (error) {
        const serviceError = error as MonitorApiError
        this.servicesErrorMessage = serviceError?.message ?? '服务可用性加载失败'
      } finally {
        this.servicesLoading = false
      }
      this.lastUpdated = new Date().toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })
     } catch (error) {
      const apiError = error as MonitorApiError
      this.errorMessage = apiError?.message ?? '暂时无法连接监控服务'
      if (apiError?.status === 401 || apiError?.status === 403) this.bindingNotice = 'Token 已失效，请重新绑定'
    } finally {
      this.isLoading = false
      this.servicesLoading = false
      this.dataRequesting = false
    }
  }

  private async bind(scannedScopes: string[] | undefined = undefined): Promise<void> {
    const payload = parseBindingPayload(this.tokenInput)
    if (payload && (!this.baseUrlInput || !normalizeBindingToken(this.tokenInput))) {
      this.baseUrlInput = payload.baseUrl
      this.tokenInput = payload.token
    }
    const baseUrl = normalizeBindingBaseUrl(this.baseUrlInput)
    const token = normalizeBindingToken(this.tokenInput)
    if (!baseUrl) {
      this.bindingNotice = '请输入有效的服务器地址（例如 https://monitor.example.com）'
      return
    }
    if (!token) {
      this.bindingNotice = '请输入有效的 API Token（必须以 nzp_ 开头）'
      return
    }
    this.baseUrlInput = baseUrl
    this.tokenInput = token
    this.isLoading = true
    this.bindingNotice = ''
    const scopeValues: string[] | undefined = scannedScopes ?? payload?.scopes
    const candidate: MonitorConnection = scopeValues?.length ? { baseUrl, token, scopes: scopeValues } : { baseUrl, token }
    try {
      const client = new MonitorApi(candidate)
      await client.checkConnection()
      await this.storage.saveConnection(candidate)
       this.connection = candidate
       this.selectPage('overview')
       await this.loadData(false)
       this.startPolling()
       this.showBindingSheet = false
       this.toast('已连接到星辰云巡')
    } catch (error) {
      const apiError = error as MonitorApiError
      this.bindingNotice = apiError?.message ?? '绑定失败，请检查地址和 Token'
    } finally {
      this.isLoading = false
    }
  }

  private async scan(): Promise<void> {
    if (!this.context) return
    this.isScanning = true
    this.bindingNotice = ''
    try {
      let useCamera = false
      try {
        const manager = abilityAccessCtrl.createAtManager()
        const permission = await manager.requestPermissionsFromUser(this.context, ['ohos.permission.CAMERA'])
        useCamera = permission.authResults.length > 0 && permission.authResults[0] === 0
      } catch (_) {
        // The album picker remains available when the runtime permission dialog cannot open.
      }
      const payload = await chooseBindingQr(this.context, useCamera)
      if (!payload) {
        this.bindingNotice = '没有识别到星辰云巡绑定二维码'
      } else {
        this.baseUrlInput = payload.baseUrl
        this.tokenInput = payload.token
        this.bindingNotice = '二维码已识别，正在验证…'
        await this.bind(payload.scopes)
      }
    } catch (_) {
      if (!this.bindingNotice) this.bindingNotice = '无法读取二维码图片，请重试或手动输入'
    } finally {
      this.isScanning = false
    }
  }

  private async unbind(): Promise<void> {
    if (this.refreshTimer >= 0) {
      clearInterval(this.refreshTimer)
      this.refreshTimer = -1
    }
    await this.storage.clearConnection()
    this.connection = null
    this.dashboard = null
    this.deviceList = []
    this.alerts = []
    this.services = []
    this.servicesErrorMessage = ''
    this.runningServiceId = -1
    this.overviewCpuText = '--'
    this.overviewMemoryText = '--'
    this.overviewDiskText = '--'
    this.overviewNetworkText = '--'
    this.baseUrlInput = ''
    this.tokenInput = ''
    this.showToken = false
    this.errorMessage = ''
    this.bindingNotice = ''
    this.pageStack.clear()
    this.selectPage('overview')
    this.toast('已解除绑定')
  }

  private canAcknowledgeAlerts(): boolean {
    const scopes = this.connection?.scopes
    // Manual tokens do not carry scope metadata; keep the action available and
    // let the server enforce the permission boundary in that case.
    if (!scopes || scopes.length === 0) return true
    return scopes.includes('nezha:*') || scopes.includes('nezha:admin:*') || scopes.includes('nezha:alert:*') || scopes.includes('nezha:alert:write')
  }

  private isKnownReadOnlyToken(): boolean {
    const scopes = this.connection?.scopes
    return !!scopes && scopes.length > 0 && !this.canAcknowledgeAlerts()
  }

  private openDevice(device: Device): void {
    this.pageStack.pushPath({ name: `${DEVICE_DETAIL_ROUTE_PREFIX}${device.id}` })
  }

  private async acknowledge(alert: AlertEvent): Promise<void> {
    const client = this.api()
    if (!client || alert.status !== 'OPEN') return
    try {
      const updated = await client.acknowledgeAlert(alert.id)
      this.alerts = this.alerts.map((item: AlertEvent) => item.id === updated.id ? updated : item)
      if (this.dashboard) {
        this.dashboard.recentAlerts = this.dashboard.recentAlerts.map((item: AlertEvent) => item.id === updated.id ? updated : item)
      }
      this.alertRevision += 1
      this.toast('告警已确认')
    } catch (_) {
      this.toast('当前 Token 没有确认告警权限')
    }
  }

  private showAlertDetails(alert: AlertEvent): void {
    const canConfirm = alert.status === 'OPEN' && this.canAcknowledgeAlerts()
    const severity = alert.severity === 'CRITICAL' ? '严重告警' : alert.severity === 'WARNING' ? '注意告警' : '提示告警'
    const status = alert.status === 'OPEN' ? '待处理' : alert.status === 'RESOLVED' ? '已恢复' : '已确认'
    this.getUIContext().showAlertDialog({
      title: `${alert.deviceName} · ${severity}`,
      subtitle: status,
      message: `规则：${alert.ruleName}\n${alert.message || '暂无详细描述'}\n发生时间：${this.time(alert.startedAt)}\n当前值：${alert.value}`,
      primaryButton: {
        value: canConfirm ? '确认告警' : '知道了',
        action: (): void => {
          if (canConfirm && alert.status === 'OPEN') {
            this.acknowledge(alert)
          } else {
            this.toast('已查看告警详情')
          }
        }
      },
      secondaryButton: {
        value: '取消',
        action: (): void => {}
      }
    })
  }

  private confirmDataAction(title: string, message: string, action: () => void): void {
    this.getUIContext().showAlertDialog({
      title: title,
      message: message,
      primaryButton: {
        value: '确认',
        action: action
      },
      secondaryButton: {
        value: '取消',
        action: (): void => {}
      }
    })
  }

  private async refresh(): Promise<void> {
    if (!this.connection) {
      this.toast('请先绑定服务器')
      return
    }
    if (this.isLoading) {
      this.toast('数据正在刷新')
      return
    }
    this.refreshAngle += 360
    await this.loadData(false)
    this.toast(this.errorMessage ? this.errorMessage : '数据已刷新')
  }

  private selectPage(page: AppPage): void {
    const index = this.pageIndex(page)
    this.syncSelectedPage(index)
    this.tabsController.changeIndex(this.currentIndex)
  }

  private pageIndex(page: AppPage): number {
    if (page === 'devices') return 1
    if (page === 'services') return 2
    if (page === 'alerts') return 3
    if (page === 'settings') return 4
    return 0
  }

  private pageFromIndex(index: number): AppPage {
    if (index === 1) return 'devices'
    if (index === 2) return 'services'
    if (index === 3) return 'alerts'
    if (index === 4) return 'settings'
    return 'overview'
  }

  private currentScroller(): Scroller {
    if (this.currentIndex === 1) return this.devicesScroller
    if (this.currentIndex === 2) return this.servicesScroller
    if (this.currentIndex === 3) return this.alertsScroller
    if (this.currentIndex === 4) return this.settingsScroller
    return this.overviewScroller
  }

  private onTabChanged(index: number): void {
    this.syncSelectedPage(index)
  }

  private syncSelectedPage(index: number): void {
    const nextPage = this.pageFromIndex(index)
    if (this.currentIndex === index && this.page === nextPage) return
    this.currentIndex = index
    this.page = nextPage
    this.restartPageEntrance(index)
  }

  private hidePageEntrances(): void {
    this.overviewPageVisible = false
    this.devicesPageVisible = false
    this.servicesPageVisible = false
    this.alertsPageVisible = false
    this.settingsPageVisible = false
  }

  private showPageEntrance(index: number): void {
    if (index === 0) this.overviewPageVisible = true
    if (index === 1) this.devicesPageVisible = true
    if (index === 2) this.servicesPageVisible = true
    if (index === 3) this.alertsPageVisible = true
    if (index === 4) this.settingsPageVisible = true
  }

  private restartPageEntrance(index: number): void {
    if (this.pageEntranceTimer >= 0) {
      clearTimeout(this.pageEntranceTimer)
      this.pageEntranceTimer = -1
    }
    this.pageEntranceToken += 1
    const token = this.pageEntranceToken
    this.hidePageEntrances()
    this.pageEntranceTimer = setTimeout(() => {
      this.pageEntranceTimer = -1
      if (token !== this.pageEntranceToken) return
      this.getUIContext().animateTo({ duration: 360, curve: curves.springMotion(0.45, 0.78) }, () => {
        if (token === this.pageEntranceToken) this.showPageEntrance(index)
      })
    }, 20)
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message })
    } catch (_) {
      // Toasts are best effort and should never interrupt a data refresh.
    }
  }

  private statusLabel(status: DeviceStatus): string {
    if (status === 'ONLINE') return '在线'
    if (status === 'OFFLINE') return '离线'
    return '待接入'
  }

  private statusColor(status: DeviceStatus): string {
    if (status === 'ONLINE') return COLORS.success
    if (status === 'OFFLINE') return COLORS.danger
    return COLORS.warning
  }

  private severityColor(severity: string): string {
    if (severity === 'CRITICAL') return COLORS.danger
    if (severity === 'WARNING') return COLORS.warning
    return COLORS.primary
  }

  private percent(value: number | undefined | null): string {
    return value === undefined || value === null ? '--' : `${Math.round(value)}%`
  }

  private rate(value: number | undefined | null): string {
    if (value === undefined || value === null) return '--'
    if (value >= 1024 * 1024) return `${(value / 1024 / 1024).toFixed(1)} MB/s`
    if (value >= 1024) return `${(value / 1024).toFixed(1)} KB/s`
    return `${Math.round(value)} B/s`
  }

  private finiteMetric(value: number | string | undefined | null): number | null {
    if (value === undefined || value === null) return null
    const numeric = typeof value === 'string' ? Number(value) : value
    if (typeof numeric !== 'number') return null
    if (numeric !== numeric) return null
    if (numeric === Infinity || numeric === -Infinity) return null
    return numeric
  }

  private mergedDevices(): Device[] {
    const seen = new Set<string>()
    const merged: Device[] = []
    const sources: Device[][] = [this.deviceList, this.dashboard?.topDevices ?? []]
    for (const list of sources) {
      for (const device of list) {
        if (!seen.has(device.id)) {
          seen.add(device.id)
          merged.push(device)
        }
      }
    }
    return merged
  }

  private averageLatestMetric(selector: (metric: Metric) => number | undefined | null): number | null {
    const values: number[] = []
    for (const device of this.mergedDevices()) {
      const value = this.finiteMetric(device.latest ? selector(device.latest) : null)
      if (value !== null) values.push(value)
    }
    if (!values.length) return null
    return values.reduce((total: number, value: number) => total + value, 0) / values.length
  }

  private overviewMetric(serverValue: number | undefined | null, selector: (metric: Metric) => number | undefined | null): number | null {
    return this.finiteMetric(serverValue) ?? this.averageLatestMetric(selector)
  }

  private overviewCpu(): number | null {
    return this.overviewMetric(this.dashboard?.averageCpu, (metric: Metric) => metric.cpuUsage)
  }

  private overviewMemory(): number | null {
    return this.overviewMetric(this.dashboard?.averageMemory, (metric: Metric) => metric.memoryUsage)
  }

  private overviewDisk(): number | null {
    return this.overviewMetric(this.dashboard?.averageDisk, (metric: Metric) => metric.diskUsage)
  }

  private overviewNetwork(): number | null {
    const received = this.finiteMetric(this.dashboard?.networkRecvBps)
    const sent = this.finiteMetric(this.dashboard?.networkSentBps)
    if (received !== null || sent !== null) return (received ?? 0) + (sent ?? 0)

    let total = 0
    let hasMetric = false
    for (const device of this.mergedDevices()) {
      if (!device.latest) continue
      const recv = this.finiteMetric(device.latest.networkRecvBps)
      const send = this.finiteMetric(device.latest.networkSentBps)
      if (recv !== null || send !== null) {
        total += (recv ?? 0) + (send ?? 0)
        hasMetric = true
      }
    }
    return hasMetric ? total : null
  }

  private currentPageTitle(): string {
    if (this.page === 'devices') return '服务器'
    if (this.page === 'services') return '服务可用性'
    if (this.page === 'alerts') return '告警中心'
    if (this.page === 'settings') return '连接设置'
    return '星辰云巡'
  }

  private metricWidth(value: string): string {
    if (!value.endsWith('%')) return '0%'
    const numberValue = Number(value.substring(0, value.length - 1))
    return `${Math.max(0, Math.min(100, numberValue))}%`
  }

  private bottomTabBarStyle(icon: Resource, text: string): BottomTabBarStyle {
    const palette = this.themePalette()
    return new BottomTabBarStyle({
      normal: new SymbolGlyphModifier(icon).fontColor([palette.secondary]).fontSize(24),
      selected: new SymbolGlyphModifier(icon).fontColor([palette.primary]).fontSize(24)
    }, text)
      .layoutMode(LayoutMode.VERTICAL)
      .verticalAlign(VerticalAlign.Center)
      .padding({ top: 4, bottom: 4 })
      .labelStyle({
        unselectedColor: palette.secondary,
        selectedColor: palette.primary,
        font: { size: 11 }
      })
      .iconStyle({
        unselectedColor: palette.secondary,
        selectedColor: palette.primary
      })
  }

  private time(value: string | null): string {
    if (!value) return '暂无上报'
    return new Date(value).toLocaleString('zh-CN', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' })
  }

  private canRunServiceChecks(): boolean {
    const scopes = this.connection?.scopes
    if (!scopes || scopes.length === 0) return true
    return scopes.includes('nezha:*') || scopes.includes('nezha:service:*') || scopes.includes('nezha:service:write')
  }

  private serviceStateSummary(): string {
    let healthy = 0
    let total = this.services.length
    for (const service of this.services) {
      if (service.latest?.success === true) healthy += 1
    }
    for (const device of this.mergedDevices()) total += device.latest?.services.length ?? 0
    return `${healthy}/${this.services.length} 网络正常 · ${total - this.services.length} 个主机服务`
  }

  private async checkService(service: NetworkService): Promise<void> {
    const client = this.api()
    if (!client || this.runningServiceId >= 0) return
    this.runningServiceId = service.id
    try {
      const updated = await client.checkService(service.id)
      this.services = this.services.map((item: NetworkService) => item.id === updated.id ? updated : item)
      this.serviceRevision += 1
      if (updated.latest?.success === false) {
        this.toast(updated.latest.error ?? '服务探测失败')
      } else {
        this.toast('服务探测完成')
      }
    } catch (error) {
      const apiError = error as MonitorApiError
      this.toast(apiError?.message ?? '立即探测失败')
    } finally {
      this.runningServiceId = -1
    }
  }

  private titleBarOptions(title: string, showRefresh: boolean = false): HdsNavigationTitleBarOptions {
    const menuValue: HdsNavigationMenuItemOptions[] = []
    if (showRefresh) {
      const menuIcon: HdsNavigationIconOptions = {
        label: '刷新数据',
        icon: $r('sys.symbol.arrow_clockwise'),
        action: (): void => { this.refresh() }
      }
      menuValue.push({ content: menuIcon })
    }
    const menu: HdsNavigationMenuContentOptions = { value: menuValue }
    const content: TitleBarContentOptions = { title: { mainTitle: title }, menu }
    const scrollEffectOpts: ScrollEffectOptions = {
      scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
    }
    const originalStyle: HdsNavigationTitleBarStyle = {
      contentStyle: {
        titleStyle: { mainTitleColor: $r('sys.color.font_primary') },
        backIconStyle: { iconColor: $r('sys.color.icon_primary') },
        menuStyle: { iconColor: $r('sys.color.icon_primary') }
      }
    }
    const style: TitleBarStyleOptions = {
      scrollEffectOpts,
      originalStyle,
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
      }
    }
    const options: HdsNavigationTitleBarOptions = {
      avoidLayoutSafeArea: true,
      enableHoverMode: true,
      style,
      content
    }
    return options
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.MainPage()
      Column() {
        Blank()
      }
      .width(1)
       .height(1)
       .bindSheet($$this.showBindingSheet, this.BindingSheetHost(), {
         height: this.isCompactLayout() ? '70%' : '78%',
         detents: this.isCompactLayout() ? ['70%', SheetSize.LARGE] : ['78%'],
         width: this.isCompactLayout() ? '100%' : this.bindingSheetWidth(),
         backgroundColor: COLORS.page,
         showClose: this.agreementGateState === 'accepted',
         dragBar: this.isCompactLayout() && this.agreementGateState === 'accepted',
         preferType: this.isCompactLayout() ? SheetType.BOTTOM : SheetType.CENTER,
         mode: SheetMode.EMBEDDED,
         keyboardAvoidMode: SheetKeyboardAvoidMode.TRANSLATE_AND_SCROLL,
         enableOutsideInteractive: false,
         title: {
           title: this.agreementGateState === 'accepted' ? '绑定监控服务器' : '隐私与用户协议',
           subtitle: this.agreementGateState === 'accepted' ? '连接后即可查看实时状态' : '请阅读并确认后继续使用'
         },
         onWillDismiss: (dismissSheetAction: DismissSheetAction) => {
           if (this.agreementGateState === 'accepted') dismissSheetAction.dismiss()
         }
        })
       Column() {
         Blank()
       }
       .width(1)
       .height(1)
       .bindSheet($$this.showAppearanceSheet, this.AppearanceSheet(), {
         height: this.isCompactLayout() ? SheetSize.MEDIUM : '78%',
         detents: this.isCompactLayout() ? [SheetSize.MEDIUM, SheetSize.LARGE] : ['78%'],
         width: this.isCompactLayout() ? '100%' : this.appearanceSheetWidth(),
         backgroundColor: COLORS.page,
         showClose: true,
         dragBar: this.isCompactLayout(),
         preferType: this.isCompactLayout() ? SheetType.BOTTOM : SheetType.CENTER,
         mode: this.isCompactLayout() ? SheetMode.OVERLAY : SheetMode.EMBEDDED,
         keyboardAvoidMode: SheetKeyboardAvoidMode.TRANSLATE_AND_SCROLL,
         title: { title: '外观设置', subtitle: '主题颜色与颜色模式' }
       })
     }
    .width('100%')
    .height('100%')
  }

  @Builder
  private BindingSheetHost() {
    if (this.agreementGateState === 'accepted') {
      this.BindingSheet()
    } else if (this.agreementGateState === 'required') {
      this.AgreementGateSheet()
    } else {
      Column({ space: 14 }) {
        LoadingProgress().width(36).height(36).color(COLORS.primary)
        Text('正在读取本地协议状态…').fontSize(13).fontColor(COLORS.secondary)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
  }

  @Builder
  private AgreementGateSheet() {
    Scroll() {
      Column() {
        ReferenceIcon({
          name: '协议',
          icon: $r('sys.symbol.lock'),
          iconSize: 52,
          iconRadius: 17,
          tint: COLORS.primary,
          iconBackground: COLORS.iconPrimary
        })
        Text('欢迎使用星辰云巡')
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLORS.text)
          .margin({ top: 14 })
        Text('开始使用前，请阅读并同意隐私政策与用户协议。')
          .width('82%')
          .fontSize(13)
          .fontColor(COLORS.secondary)
          .textAlign(TextAlign.Center)
          .lineHeight(21)
          .margin({ top: 9 })
        Row({ space: 10 }) {
          Text('《隐私政策》')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLORS.primary)
            .padding({ left: 16, right: 16, top: 9, bottom: 9 })
            .backgroundColor(COLORS.primarySoft)
            .borderRadius(20)
            .onClick(() => { this.openAgreementDocument('隐私政策', PRIVACY_POLICY_URL) })
          Text('《用户协议》')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLORS.primary)
            .padding({ left: 16, right: 16, top: 9, bottom: 9 })
            .backgroundColor(COLORS.primarySoft)
            .borderRadius(20)
            .onClick(() => { this.openAgreementDocument('用户协议', USER_AGREEMENT_URL) })
        }
        .justifyContent(FlexAlign.Center)
        .margin({ top: 12 })
        if (this.agreementErrorMessage) {
          Text(this.agreementErrorMessage)
            .width('100%')
            .fontSize(12)
            .fontColor(COLORS.danger)
            .textAlign(TextAlign.Center)
            .margin({ top: 8 })
        }
        Button(this.agreementSaving ? '正在保存…' : '同意并进入')
        .width('100%')
        .height(50)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLORS.page)
        .backgroundColor(COLORS.primary)
        .margin({ top: 16 })
        .enabled(!this.agreementSaving && !this.agreementExiting)
        .onClick(() => { this.acceptAgreement() })
        Button(this.agreementExiting ? '正在退出…' : '不同意并退出')
          .width('100%')
          .height(50)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLORS.secondary)
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: COLORS.border, radius: 25 })
          .margin({ top: 12 })
          .enabled(!this.agreementSaving && !this.agreementExiting)
          .onClick(() => { this.rejectAgreement() })
        Text('点击“同意并进入”即代表你已阅读并理解上述协议')
          .fontSize(10)
          .fontColor(COLORS.muted)
          .textAlign(TextAlign.Center)
          .margin({ top: 13 })
      }
      .width('100%')
      .constraintSize({ minHeight: this.isCompactLayout() ? 420 : 460 })
      .justifyContent(FlexAlign.Center)
      .padding({ left: 28, right: 28, top: 20, bottom: 20 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private AppearanceSheet() {
    Scroll() {
      Column({ space: 14 }) {
        Row({ space: 12 }) {
          ReferenceIcon({
            name: '外观',
            icon: $r('sys.symbol.paintbrush'),
            iconSize: 52,
            iconRadius: 17,
            tint: COLORS.primary,
            iconBackground: COLORS.iconPrimary
          })
          Column() {
            Text('定制你的监控空间')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLORS.text)
            Text('主题颜色和颜色模式会立即同步到整个应用')
              .fontSize(12)
              .fontColor(COLORS.secondary)
              .margin({ top: 5 })
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        }.width('100%').padding({ top: 4, left: 2, right: 2 })
        Column({ space: 9 }) {
          Text('主题颜色')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLORS.text)
          ForEach(THEME_OPTIONS, (theme: ThemeOption) => {
            ThemeOptionCard({
              option: theme,
              selected: this.themeId === theme.id,
              onSelect: () => { this.chooseTheme(theme.id) }
            })
          }, (theme: ThemeOption) => theme.id)
        }.width('100%')
        Column({ space: 9 }) {
          Text('颜色模式')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLORS.text)
          Row({ space: 8 }) {
            ColorModeOptionCard({
              mode: 'SYSTEM',
              title: '跟随系统',
              subtitle: '使用系统当前的浅色或深色模式',
              selected: this.colorModePreference === 'SYSTEM',
              onSelect: () => { this.chooseColorMode('SYSTEM') }
            })
            ColorModeOptionCard({
              mode: 'LIGHT',
              title: '浅色模式',
              subtitle: '始终使用明亮配色',
              selected: this.colorModePreference === 'LIGHT',
              onSelect: () => { this.chooseColorMode('LIGHT') }
            })
            ColorModeOptionCard({
              mode: 'DARK',
              title: '深色模式',
              subtitle: '始终使用深色配色',
              selected: this.colorModePreference === 'DARK',
              onSelect: () => { this.chooseColorMode('DARK') }
            })
          }.width('100%')
        }.width('100%')
        Row({ space: 7 }) {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(14)
            .fontColor([COLORS.success])
          Text(`当前使用 ${this.themeName()} · ${this.colorModeLabel()}`)
            .fontSize(11)
            .fontColor(COLORS.secondary)
            .layoutWeight(1)
        }.width('100%')
          .padding({ left: 13, right: 13, top: 10, bottom: 10 })
          .backgroundColor(COLORS.successSoft)
          .borderRadius(13)
      }
      .width('100%')
      .padding({ left: 18, right: 18, bottom: 26 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private BindingSheet() {
    Scroll() {
      Column({ space: 14 }) {
        Row({ space: 12 }) {
          ReferenceIcon({ name: '连接', icon: $r('sys.symbol.lock'), iconSize: 52, iconRadius: 17, tint: COLORS.primary, iconBackground: COLORS.iconPrimary })
          Column() {
            Text('先连接你的监控空间').fontSize(20).fontWeight(FontWeight.Bold).fontColor(COLORS.text)
            Text('绑定后，设备状态和告警会自动同步').fontSize(12).fontColor(COLORS.secondary).margin({ top: 5 })
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        }.width('100%').padding({ top: 4, left: 2, right: 2 })
        Row({ space: 7 }) {
          SymbolGlyph($r('sys.symbol.lock')).fontSize(14).fontColor([COLORS.success])
          Text('推荐使用只读 Token，本机仅保存连接凭据').fontSize(11).fontColor(COLORS.secondary).layoutWeight(1)
        }.width('100%').padding({ left: 13, right: 13, top: 10, bottom: 10 }).backgroundColor(COLORS.successSoft).borderRadius(13)
        Column() {
          Row() {
            Column() {
              Text('服务器地址').fontSize(13).fontWeight(FontWeight.Medium).fontColor(COLORS.text)
              Text('Web 控制台或 API 服务地址').fontSize(11).fontColor(COLORS.muted).margin({ top: 3 })
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Text('必填').fontSize(10).fontColor(COLORS.primary)
          }.width('100%')
          TextInput({ placeholder: '例如 https://monitor.example.com', text: this.baseUrlInput })
            .height(50).fontSize(14).backgroundColor(COLORS.surface).borderRadius(13).padding({ left: 14, right: 14 }).margin({ top: 9 })
            .border({ width: 1, color: COLORS.divider, radius: 13 })
            .onChange((value: string) => { this.baseUrlInput = value })
          Row() {
            Column() {
              Text('API Token').fontSize(13).fontWeight(FontWeight.Medium).fontColor(COLORS.text)
              Text('粘贴 Web 控制台生成的访问 Token').fontSize(11).fontColor(COLORS.muted).margin({ top: 3 })
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Text('安全').fontSize(10).fontColor(COLORS.success)
          }.width('100%').margin({ top: 17 })
          TextInput({ placeholder: '粘贴 API Token', text: this.tokenInput })
            .height(50).fontSize(14).type(this.showToken ? InputType.Normal : InputType.Password).backgroundColor(COLORS.surface).borderRadius(13).padding({ left: 14, right: 14 }).margin({ top: 9 })
            .border({ width: 1, color: COLORS.divider, radius: 13 })
            .onChange((value: string) => { this.tokenInput = value })
          Row() {
            Row({ space: 5 }) {
              SymbolGlyph(this.showToken ? $r('sys.symbol.eye') : $r('sys.symbol.eye_slash')).fontSize(14).fontColor([COLORS.primary])
              Text(this.showToken ? '隐藏 Token' : '显示 Token').fontSize(12).fontColor(COLORS.primary)
            }
            Blank()
            Text('凭据仅保存在本机').fontSize(11).fontColor(COLORS.muted)
          }.width('100%').margin({ top: 8 }).onClick(() => { this.showToken = !this.showToken })
          Row({ space: 12 }) {
            Button() {
              Row({ space: 7 }) {
                SymbolGlyph($r('sys.symbol.square_grid_2x2')).fontSize(17).fontColor([COLORS.primary])
                Text(this.isScanning ? '读取中…' : '扫码绑定').fontSize(14).fontColor(COLORS.primary)
              }
            }.layoutWeight(1).height(48).type(ButtonType.Capsule).backgroundColor(COLORS.primarySoft).border({ width: 1, color: COLORS.primary, radius: 24 }).shadow({ radius: 10, color: COLORS.shadow, offsetY: 4 }).enabled(!this.isScanning && !this.isLoading).onClick(() => { this.scan() })
            Button() {
              Row({ space: 7 }) {
                SymbolGlyph($r('sys.symbol.arrow_clockwise')).fontSize(17).fontColor([COLORS.text])
                Text(this.isLoading ? '验证中…' : '连接服务器').fontSize(14).fontColor(COLORS.text)
              }
            }.layoutWeight(1).height(48).type(ButtonType.Capsule).backgroundColor(COLORS.primary).shadow({ radius: 12, color: COLORS.shadowStrong, offsetY: 5 }).enabled(!this.isLoading && !this.isScanning).onClick(() => { this.bind() })
          }.margin({ top: 20 })
        }.padding({ left: 18, right: 18, top: 18, bottom: 19 }).backgroundColor(COLORS.card).borderRadius(22).border({ width: 1, color: COLORS.border, radius: 22 }).shadow({ radius: 15, color: COLORS.shadow, offsetY: 6 })
        if (this.bindingNotice) Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.questionmark_circle')).fontSize(16).fontColor([COLORS.danger])
          Text(this.bindingNotice).fontSize(12).fontColor(COLORS.danger).layoutWeight(1).maxLines(3)
        }.padding({ left: 13, right: 13, top: 9, bottom: 9 }).backgroundColor(COLORS.dangerSoft).borderRadius(13)
        Text('也可以在 Web 控制台生成绑定二维码，一键完成配置').fontSize(11).fontColor(COLORS.muted).textAlign(TextAlign.Center).width('100%').margin({ bottom: 12 })
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 28, top: 6 })
    }
    .width('100%')
    .height('100%')
    .edgeEffect(EdgeEffect.Spring)
    .scrollBar(BarState.Off)
  }

  @Builder
  private MainPage() {
    HdsNavigation(this.pageStack) {
      HdsTabs({ controller: this.tabsController }) {
        TabContent() { this.OverviewPage() }
          .tabBar(this.bottomTabBarStyle($r('sys.symbol.house'), '概览'))
          .backgroundColor(Color.Transparent)
          .clip(false)
        TabContent() { this.DevicesPage() }
          .tabBar(this.bottomTabBarStyle($r('sys.symbol.square_grid_2x2'), '服务器'))
          .backgroundColor(Color.Transparent)
          .clip(false)
        TabContent() { this.ServicesPage() }
          .tabBar(this.bottomTabBarStyle($r('sys.symbol.share'), '服务'))
          .backgroundColor(Color.Transparent)
          .clip(false)
        TabContent() { this.AlertsPage() }
          .tabBar(this.bottomTabBarStyle($r('sys.symbol.bell'), '告警'))
          .backgroundColor(Color.Transparent)
          .clip(false)
        TabContent() { this.SettingsPage() }
          .tabBar(this.bottomTabBarStyle($r('sys.symbol.person'), '设置'))
          .backgroundColor(Color.Transparent)
          .clip(false)
      }
      .clip(false)
      .barOverlap(true)
      .vertical(false)
      .barPosition(BarPosition.End)
      .barFloatingStyle({
        barBottomMargin: 28,
        gradientMask: { maskColor: COLORS.page, maskHeight: 92 },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      })
      .animationDuration(0)
      .backgroundColor(Color.Transparent)
      .onChange((index: number) => { this.onTabChanged(index) })
      .width('100%')
      .height('100%')
     }
    .mode(NavigationMode.Stack)
    .navDestination(this.DeviceDestination)
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
    .hideTitleBar(false)
    .hideToolBar(true)
    .titleBar(this.titleBarOptions(this.currentPageTitle(), this.page === 'overview'))
    .bindToScrollable([this.currentScroller()])
    .backgroundColor(Color.Transparent)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .width('100%').height('100%').opacity(this.contentVisible ? 1 : 0).translate({ y: this.contentVisible ? 0 : 10 })
      .animation({ duration: 420, curve: curves.springMotion(0.45, 0.78) })
  }

  @Builder
  private DeviceDestination(name: string, _pageInfos: Object) {
    DeviceDetailDestination({
      deviceId: name.startsWith(DEVICE_DETAIL_ROUTE_PREFIX) ? name.substring(DEVICE_DETAIL_ROUTE_PREFIX.length) : '',
      connection: this.connection,
      layoutSize: this.layoutSize,
      windowWidthVp: this.responsiveWindowWidth(),
      windowHeightVp: this.windowHeightVp
    })
  }

  @Builder
  private TopBar() {
    Row() {
      Column() {
        Text(this.page === 'overview' ? '星辰云巡' : this.page === 'devices' ? '服务器' : this.page === 'services' ? '服务可用性' : this.page === 'alerts' ? '告警中心' : '连接设置')
          .fontSize(23).fontWeight(FontWeight.Bold).fontColor(COLORS.text)
        Text(this.page === 'overview' ? `监控空间 · ${this.lastUpdated || '等待同步'}` : '星辰云巡监控空间')
          .fontSize(11).fontColor(COLORS.secondary).margin({ top: 5 })
      }.alignItems(HorizontalAlign.Start)
      Blank()
      ReferenceHeaderActionButton({ icon: $r('sys.symbol.arrow_clockwise'), angle: this.refreshAngle, action: () => { this.refresh() } })
        .width(42).height(42).backgroundColor(COLORS.card).borderRadius(21)
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 20, bottom: 11 })
  }

  @Builder
  private OverviewPage() {
    Scroll(this.overviewScroller) {
      Column() {
        Column({ space: 16 }) {
          Blank().height(56 + this.getUIContext().px2vp(this.topRectHeight))
          if (this.errorMessage) {
            this.ErrorBanner()
          }
          if (!this.connection) {
            this.UnboundCard()
          }
          ReferenceDashboardCard({
            eyebrow: '监控总览',
            value: this.dashboard ? `${this.dashboard.onlineDevices} 台在线` : '--',
            detail: this.dashboard ? `共 ${this.dashboard.totalDevices} 台设备 · ${this.dashboard.activeAlerts} 条待处理告警` : '正在连接数据…',
            footnote: `最近同步 ${this.lastUpdated || '--'}`,
            icon: $r('sys.symbol.square_grid_2x2'),
            onActivate: () => { this.refresh() }
          })
            .opacity(this.introVisible ? 1 : 0)
            .translate({ y: this.introVisible ? 0 : 30 })
          Row() {
            Row() {
              Text('实时状态').fontSize(14).fontWeight(FontWeight.Bold).fontColor(COLORS.text)
            }.padding({ left: 14, right: 14, top: 7, bottom: 7 }).backgroundColor(COLORS.card).borderRadius(15)
            Blank()
            Row({ space: 5 }) {
              Circle({ width: 7, height: 7 }).fill(COLORS.success)
              Text(`自动刷新 · ${this.refreshIntervalLabel()}`).fontSize(11).fontColor(COLORS.secondary)
            }
          }.width('100%').opacity(this.summaryVisible ? 1 : 0).translate({ y: this.summaryVisible ? 0 : 24 })
          this.SectionHeader('资源概览', '最近采样', () => {})
          this.OverviewMetricGrid()
          GridRow({
            columns: 12,
            gutter: { x: 16, y: 16 },
            breakpoints: { value: ['900vp'], reference: BreakpointsReference.ComponentSize }
          }) {
            GridCol({ span: { xs: 12, sm: 8 } }) {
              this.OverviewDeviceSection()
            }
            GridCol({ span: { xs: 12, sm: 4 } }) {
              this.OverviewSecondarySection()
            }
          }.width('100%')
          Blank().height(this.contentBottomInset())
        }
        .width('100%')
        .constraintSize({ maxWidth: this.pageContainerWidth() })
        .padding({ left: getPageHorizontalPadding(this.layoutSize), right: getPageHorizontalPadding(this.layoutSize) })
      }.width('100%').alignItems(HorizontalAlign.Center)
    }.width('100%').height('100%').opacity(this.overviewPageVisible ? 1 : 0).translate({ y: this.overviewPageVisible ? 0 : 16 })
      .animation({ duration: 360, curve: curves.springMotion(0.45, 0.78) })
      .edgeEffect(EdgeEffect.Spring).scrollBar(BarState.Off).clip(false)
  }

  @Builder
  private OverviewMetricGrid() {
    GridRow({
      columns: 12,
      gutter: { x: 10, y: 10 },
      breakpoints: { value: ['560vp', '1040vp'], reference: BreakpointsReference.ComponentSize }
    }) {
      GridCol({ span: { xs: 12, sm: 6, md: 3 } }) {
        ReferenceMonitorCard({
          title: 'CPU 平均', subtitle: '过去 6 小时', value: this.overviewCpuText, status: '当前',
          accent: COLORS.primary, icon: $r('sys.symbol.square_grid_2x2'), iconBackground: COLORS.iconPrimary,
          showChevron: false
        })
      }
      GridCol({ span: { xs: 12, sm: 6, md: 3 } }) {
        ReferenceMonitorCard({
          title: '内存平均', subtitle: '在线设备', value: this.overviewMemoryText, status: '当前',
          accent: COLORS.success, icon: $r('sys.symbol.house'), iconBackground: COLORS.iconSuccess,
          showChevron: false
        })
      }
      GridCol({ span: { xs: 12, sm: 6, md: 3 } }) {
        ReferenceMonitorCard({
          title: '磁盘平均', subtitle: '最高使用率', value: this.overviewDiskText, status: '当前',
          accent: COLORS.warning, icon: $r('sys.symbol.house'), iconBackground: COLORS.iconWarning,
          showChevron: false
        })
      }
      GridCol({ span: { xs: 12, sm: 6, md: 3 } }) {
        ReferenceMonitorCard({
          title: '网络吞吐', subtitle: '接收 + 发送', value: this.overviewNetworkText, status: '当前',
          accent: COLORS.purple, icon: $r('sys.symbol.share'), iconBackground: COLORS.iconPurple,
          showChevron: false
        })
      }
    }
    .width('100%')
    .opacity(this.summaryVisible ? 1 : 0)
    .translate({ y: this.summaryVisible ? 0 : 24 })
  }

  @Builder
  private OverviewDeviceSection() {
    Column({ space: 10 }) {
      this.SectionHeader('设备状态', '查看全部', () => { this.selectPage('devices') })
      if (this.mergedDevices().length) {
        ForEach(this.mergedDevices().slice(0, 4), (device: Device) => {
          this.DeviceRow(device)
        }, (device: Device) => `${device.id}-${this.deviceRevision}`)
      } else {
        this.EmptyState('还没有设备数据', '在 Web 控制台添加 Agent 后，这里会自动出现实时状态。')
      }
    }
    .width('100%')
    .opacity(this.listsVisible ? 1 : 0)
    .translate({ y: this.listsVisible ? 0 : 18 })
  }

  @Builder
  private OverviewSecondarySection() {
    Column({ space: 10 }) {
      this.SectionHeader('服务可用性', '查看详情', () => { this.selectPage('services') })
      ReferenceMonitorCard({
        title: this.services.length ? '服务状态已同步' : '等待服务数据',
        subtitle: this.connection ? this.serviceStateSummary() : '绑定监控服务器后查看网络和主机服务',
        value: this.services.length ? `${this.services.filter((service: NetworkService) => service.latest?.success === true).length}/${this.services.length}` : '--',
        status: '网络服务正常数', icon: $r('sys.symbol.share'),
        accent: this.services.some((service: NetworkService) => service.latest?.success === false) ? COLORS.danger : COLORS.purple,
        iconBackground: COLORS.iconPurple, onActivate: () => { this.selectPage('services') }
      })
      this.SectionHeader('最近告警', '全部告警', () => { this.selectPage('alerts') })
      if (this.alerts.length) {
        ForEach(this.alerts.slice(0, 3), (alert: AlertEvent) => {
          this.AlertRow(alert)
        }, (alert: AlertEvent) => `${alert.id}-${this.alertRevision}`)
      } else {
        this.EmptyState('当前没有告警', '系统会在设备离线或指标越过阈值时提醒你。')
      }
    }
    .width('100%')
    .opacity(this.listsVisible ? 1 : 0)
    .translate({ y: this.listsVisible ? 0 : 18 })
  }

  @Builder
  private UnboundCard() {
    Row({ space: 12 }) {
      ReferenceIcon({ name: '绑定', icon: $r('sys.symbol.lock'), iconSize: 46, iconRadius: 15, tint: COLORS.primary, iconBackground: COLORS.iconPrimary })
      Column() {
        Text('连接监控空间').fontSize(17).fontWeight(FontWeight.Bold).fontColor(COLORS.text)
        Text('绑定服务器后，这里会显示实时状态').fontSize(12).fontColor(COLORS.secondary).margin({ top: 5 })
        Text('立即绑定').fontSize(12).fontColor(COLORS.primary).margin({ top: 10 }).onClick(() => { this.openBindingSheet() })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_right')).fontSize(15).fontColor([COLORS.primary])
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 15, bottom: 15 })
    .backgroundColor(COLORS.card)
    .borderRadius(22)
    .border({ width: 1, color: COLORS.divider, radius: 22 })
    .shadow({ radius: 16, color: COLORS.shadow, offsetY: 6 })
    .onClick(() => { this.openBindingSheet() })
  }

  @Builder
  private SectionHeader(title: string, action: string, onTap: () => void) {
    Row() {
      Text(title).fontSize(17).fontWeight(FontWeight.Bold).fontColor(COLORS.text)
      Blank()
      Text(action).fontSize(12).fontColor(COLORS.primary).onClick(onTap)
    }.width('100%').padding({ left: 4, right: 4 })
  }

  @Builder
  private DeviceRow(device: Device) {
    ReferenceMonitorCard({
      title: device.name,
      subtitle: `${this.statusLabel(device.status)} · ${device.primaryIp || device.hostname || '等待地址'}`,
      value: this.percent(device.latest?.cpuUsage),
      status: 'CPU',
      icon: $r('sys.symbol.square_grid_2x2'),
      accent: this.statusColor(device.status),
      iconBackground: device.status === 'ONLINE' ? COLORS.iconSuccess : device.status === 'OFFLINE' ? COLORS.iconDanger : COLORS.iconWarning,
      onActivate: () => { this.openDevice(device) }
    })
  }

  @Builder
  private DevicesPage() {
    Scroll(this.devicesScroller) {
      Column() {
        Column({ space: 14 }) {
          Blank().height(56 + this.getUIContext().px2vp(this.topRectHeight))
          Row() {
            Column() {
              Text('设备清单').fontSize(17).fontWeight(FontWeight.Bold).fontColor(COLORS.text)
              Text('实时状态与资源使用').fontSize(11).fontColor(COLORS.muted).margin({ top: 4 })
            }.alignItems(HorizontalAlign.Start)
            Blank()
            Row({ space: 6 }) {
              Circle({ width: 7, height: 7 }).fill(COLORS.success)
              Text(`${this.dashboard?.onlineDevices ?? 0} 在线`).fontSize(12).fontColor(COLORS.success)
            }
          }.width('100%').padding({ left: 4, right: 4 }).opacity(this.introVisible ? 1 : 0).translate({ y: this.introVisible ? 0 : 18 })
          if (this.mergedDevices().length) {
            GridRow({
              columns: 12,
              gutter: { x: 10, y: 10 },
              breakpoints: { value: ['620vp', '980vp'], reference: BreakpointsReference.ComponentSize }
            }) {
              ForEach(this.mergedDevices(), (device: Device) => {
                GridCol({ span: { xs: 12, sm: 6, md: 4 } }) {
                  this.DeviceRow(device)
                }
              }, (device: Device) => `${device.id}-${this.deviceRevision}`)
            }.width('100%')
              .opacity(this.listsVisible ? 1 : 0).translate({ y: this.listsVisible ? 0 : 18 })
          } else {
            this.EmptyState('暂无服务器', '请先在 Web 控制台创建设备并安装 Agent。')
          }
          Blank().height(this.contentBottomInset())
        }
        .width('100%')
        .constraintSize({ maxWidth: this.pageContainerWidth() })
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Start)
        .padding({ left: getPageHorizontalPadding(this.layoutSize), right: getPageHorizontalPadding(this.layoutSize) })
      }.width('100%').alignItems(HorizontalAlign.Center)
    }.width('100%').height('100%').opacity(this.devicesPageVisible ? 1 : 0).translate({ y: this.devicesPageVisible ? 0 : 16 })
      .animation({ duration: 360, curve: curves.springMotion(0.45, 0.78) })
      .edgeEffect(EdgeEffect.Spring).scrollBar(BarState.Off).clip(false)
  }

  @Builder
  private ServicesPage() {
    ServiceAvailabilityView({
      services: this.services,
      devices: this.mergedDevices(),
      connection: this.connection,
      isLoading: this.servicesLoading,
      errorMessage: this.servicesErrorMessage,
      runningServiceId: this.runningServiceId,
      canRunChecks: this.canRunServiceChecks(),
      contentVisible: this.servicesPageVisible,
      topInset: 56 + this.getUIContext().px2vp(this.topRectHeight),
      bottomInset: this.contentBottomInset(),
      scroller: this.servicesScroller,
      dataRevision: this.serviceRevision,
      detailBackRequest: this.serviceDetailBackRequest,
      layoutSize: this.layoutSize,
      windowWidthVp: this.responsiveWindowWidth(),
      windowHeightVp: this.windowHeightVp,
      onDetailVisibilityChanged: (visible: boolean): void => { this.serviceDetailVisible = visible },
      onRefresh: () => { this.refresh() },
      onCheck: (service: NetworkService): void => { this.checkService(service) }
    })
  }

  @Builder
  private AlertsPage() {
    Scroll(this.alertsScroller) {
      Column() {
        Column({ space: 14 }) {
          Blank().height(56 + this.getUIContext().px2vp(this.topRectHeight))
          Row() {
            Column() {
              Text('告警动态').fontSize(17).fontWeight(FontWeight.Bold).fontColor(COLORS.text)
              Text('需要关注的服务器事件').fontSize(11).fontColor(COLORS.muted).margin({ top: 4 })
            }.alignItems(HorizontalAlign.Start)
            Blank()
            Text(`${this.alerts.filter((alert: AlertEvent) => alert.status !== 'RESOLVED').length} 条未解决`).fontSize(12).fontColor(COLORS.warning)
          }.width('100%').padding({ left: 4, right: 4 }).opacity(this.introVisible ? 1 : 0).translate({ y: this.introVisible ? 0 : 18 })
          if (this.alerts.length) {
            GridRow({
              columns: 12,
              gutter: { x: 10, y: 10 },
              breakpoints: { value: ['620vp', '980vp'], reference: BreakpointsReference.ComponentSize }
            }) {
              ForEach(this.alerts, (alert: AlertEvent) => {
                GridCol({ span: { xs: 12, sm: 6, md: 4 } }) {
                  this.AlertRow(alert)
                }
              }, (alert: AlertEvent) => `${alert.id}-${this.alertRevision}`)
            }.width('100%')
              .opacity(this.listsVisible ? 1 : 0).translate({ y: this.listsVisible ? 0 : 18 })
          } else {
            this.EmptyState('没有告警记录', '一切正常，新的告警会出现在这里。')
          }
          Blank().height(this.contentBottomInset())
        }
        .width('100%')
        .constraintSize({ maxWidth: this.pageContainerWidth() })
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Start)
        .padding({ left: getPageHorizontalPadding(this.layoutSize), right: getPageHorizontalPadding(this.layoutSize) })
      }.width('100%').alignItems(HorizontalAlign.Center)
    }.width('100%').height('100%').opacity(this.alertsPageVisible ? 1 : 0).translate({ y: this.alertsPageVisible ? 0 : 16 })
      .animation({ duration: 360, curve: curves.springMotion(0.45, 0.78) })
      .edgeEffect(EdgeEffect.Spring).scrollBar(BarState.Off).clip(false)
  }

  @Builder
  private AlertRow(alert: AlertEvent) {
    ReferenceMonitorCard({
      title: alert.deviceName,
      subtitle: `${alert.message || alert.ruleName} · ${this.time(alert.startedAt)}`,
      value: alert.severity === 'CRITICAL' ? '严重' : alert.severity === 'WARNING' ? '注意' : '提示',
       status: alert.status === 'OPEN' ? (this.canAcknowledgeAlerts() ? '点击查看 · 可确认' : this.isKnownReadOnlyToken() ? '点击查看 · 只读' : '点击查看 · 待确认') : alert.status === 'RESOLVED' ? '点击查看 · 已恢复' : '点击查看 · 已确认',
      icon: $r('sys.symbol.bell'),
      accent: this.severityColor(alert.severity),
       iconBackground: alert.severity === 'CRITICAL' ? COLORS.iconDanger : alert.severity === 'WARNING' ? COLORS.iconWarning : COLORS.iconPrimary,
       onActivate: () => { this.showAlertDetails(alert) }
    })
  }

  @Builder
  private SettingsPage() {
    Scroll(this.settingsScroller) {
      Column() {
        Column({ space: 10 }) {
          Blank().height(56 + this.getUIContext().px2vp(this.topRectHeight))
          ReferenceMonitorCard({
            title: this.connection ? '已连接' : '未绑定',
            subtitle: this.connection?.baseUrl ?? '点击下方绑定监控服务器',
            value: this.connection ? '正常' : '待绑定',
            status: this.connection ? (this.lastUpdated ? `同步于 ${this.lastUpdated}` : '等待同步') : '尚未同步',
            icon: $r('sys.symbol.house'),
            accent: this.connection ? COLORS.success : COLORS.warning,
            iconBackground: this.connection ? COLORS.iconSuccess : COLORS.iconWarning,
            showChevron: false
          })
          if (this.isExpandedLayout()) {
            GridRow({ columns: 12, gutter: { x: 18, y: 18 } }) {
              GridCol({ span: 6 }) {
                this.SettingsConnectionGroup()
              }
              GridCol({ span: 6 }) {
                this.SettingsPreferenceGroup()
              }
            }.width('100%')
          } else {
            Column({ space: 10 }) {
              this.SettingsConnectionGroup()
              this.SettingsPreferenceGroup()
            }.width('100%')
          }
          Blank().height(this.contentBottomInset())
        }
        .width('100%')
        .constraintSize({ maxWidth: this.pageContainerWidth() })
        .padding({ left: getPageHorizontalPadding(this.layoutSize), right: getPageHorizontalPadding(this.layoutSize) })
      }.width('100%').alignItems(HorizontalAlign.Center)
    }
    .width('100%').height('100%').opacity(this.settingsPageVisible ? 1 : 0).translate({ y: this.settingsPageVisible ? 0 : 16 })
      .animation({ duration: 360, curve: curves.springMotion(0.45, 0.78) })
      .scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring).clip(false)
  }

  @Builder
  private SettingsConnectionGroup() {
    Column({ space: 10 }) {
      this.SettingHeader('连接空间')
      ReferenceSettingCard({
        title: '访问凭据',
        subtitle: this.showSensitiveValues && this.connection?.token ? this.connection.token : this.connection?.token ? `${this.connection.token.substring(0, Math.min(12, this.connection.token.length))}…` : '--',
        icon: $r('sys.symbol.key'), accent: COLORS.primary, iconBackground: COLORS.iconPrimary,
        showChevron: true, onActivate: () => { this.copyToken() }
      })
      ReferenceSettingCard({
        title: '刷新频率',
        subtitle: this.autoRefreshEnabled ? `${this.refreshIntervalLabel()} · 页面可见时` : `已暂停 · ${this.refreshIntervalLabel()}`,
        icon: $r('sys.symbol.arrow_clockwise'), accent: COLORS.primary, iconBackground: COLORS.iconPrimary,
        showChevron: true, onActivate: () => { this.chooseRefreshInterval() }
      })
      ReferenceSettingCard({
        title: '数据来源', subtitle: 'REST API / PAT', icon: $r('sys.symbol.share'),
        accent: COLORS.primary, iconBackground: COLORS.iconPrimary
      })
    }.width('100%')
  }

  @Builder
  private SettingsPreferenceGroup() {
    Column({ space: 10 }) {
      this.SettingHeader('外观')
      ReferenceSettingCard({
        title: '当前主题', subtitle: `${this.themeName()} · ${this.colorModeLabel()}`,
        icon: $r('sys.symbol.gearshape'), accent: COLORS.primary, iconBackground: COLORS.iconPrimary,
        showChevron: true, onActivate: () => { this.openAppearanceSheet() }
      })
      this.SettingHeader('通用')
      ReferenceSettingSwitchCard({
        title: '自动刷新', subtitle: `每 ${this.refreshIntervalLabel()} 同步监控数据`,
        value: this.autoRefreshEnabled, icon: $r('sys.symbol.arrow_clockwise'), accent: COLORS.primary,
        iconBackground: COLORS.iconPrimary,
        onChange: (value: boolean) => {
          this.autoRefreshEnabled = value
          this.startPolling()
          this.saveSettings()
          this.toast(value ? '已开启自动刷新' : '已暂停自动刷新')
        }
      })
      ReferenceSettingSwitchCard({
        title: '显示完整 Token', subtitle: '仅在设置页显示，不会写入日志', value: this.showSensitiveValues,
        icon: $r('sys.symbol.key'), accent: COLORS.primary, iconBackground: COLORS.iconPrimary,
        onChange: (value: boolean) => {
          this.showSensitiveValues = value
          this.saveSettings()
          this.toast(value ? '已显示完整 Token' : '已隐藏完整 Token')
        }
      })
      this.SettingHeader('数据管理')
      this.SettingsAction($r('sys.symbol.arrow_clockwise'), '立即刷新数据', '重新请求总览、设备、服务和告警', () => {
        this.confirmDataAction('确认刷新数据', '将立即重新请求总览、服务器、服务和告警数据。', () => { this.refresh() })
      })
      this.SettingsAction($r('sys.symbol.square_grid_2x2'), this.connection ? '重新绑定服务器' : '绑定服务器', this.connection ? '替换当前 API Token 或监控地址' : '输入地址和 Token 连接监控空间', () => {
        this.openBindingSheet()
      })
      this.SettingsAction($r('sys.symbol.chevron_left'), '解除绑定', '清除本机保存的访问凭据', () => {
        this.confirmDataAction('确认解除绑定', '将清除本机保存的服务器地址和 Token，其他显示设置不会受影响。', () => { this.unbind() })
      }, true)
      this.SettingHeader('隐私与关于')
      this.SettingItem('安全提示', '建议使用只读 Token', $r('sys.symbol.lock'))
      ReferenceSettingCard({
        title: '关于星辰云巡', subtitle: '品牌、版本、相关政策与支持', icon: $r('sys.symbol.person'),
        accent: COLORS.primary, iconBackground: COLORS.iconPrimary, showChevron: true,
        onActivate: () => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/About' }).catch(() => {
            this.toast('关于页面暂时无法打开')
          })
        }
      })
    }.width('100%')
  }

  @Builder
  private SettingsAction(icon: Resource, title: string, hint: string, action: () => void, destructive: boolean = false) {
    ReferenceSettingCard({
      title: title,
      subtitle: hint,
      icon: icon,
      accent: destructive ? COLORS.danger : COLORS.primary,
      iconBackground: destructive ? COLORS.iconDanger : COLORS.iconPrimary,
      showChevron: true,
      destructive: destructive,
      onActivate: action
    })
  }

  @Builder
  private SettingHeader(title: string) {
    Text(title).fontSize(17).fontWeight(FontWeight.Bold).fontColor(COLORS.text).margin({ left: 4, top: 14, bottom: 2 }).width('100%')
  }

  private themeName(): string {
    for (const option of THEME_OPTIONS) {
      if (option.id === this.themeId) return option.name
    }
    return '星辉金'
  }

  @Builder
  private SettingItem(title: string, value: string, icon: Resource) {
    ReferenceSettingCard({
      title: title,
      subtitle: value,
      icon: icon,
      accent: COLORS.primary,
       iconBackground: COLORS.iconPrimary
    })
  }

  @Builder
  private EmptyState(title: string, description: string) {
    Column() {
      Stack() { Circle({ width: 42, height: 42 }).fill(COLORS.surface); SymbolGlyph($r('sys.symbol.questionmark_circle')).fontSize(22).fontColor([COLORS.muted]) }
      Text(title).fontSize(14).fontWeight(FontWeight.Medium).fontColor(COLORS.text).margin({ top: 10 })
      Text(description).fontSize(11).fontColor(COLORS.muted).margin({ top: 5 }).textAlign(TextAlign.Center).maxLines(3)
    }.width('100%').padding({ top: 28, bottom: 28, left: 18, right: 18 })
  }

  @Builder
  private ErrorBanner() {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.questionmark_circle')).fontSize(17).fontColor([COLORS.danger])
      Text(this.errorMessage).fontSize(12).fontColor(COLORS.danger).layoutWeight(1).maxLines(2)
      Text('重试').fontSize(12).fontColor(COLORS.primary).onClick(() => { this.refresh() })
    }.width('100%').padding(14).backgroundColor(COLORS.dangerSoft).borderRadius(16)
  }
}

@Component
struct ThemeOptionCard {
  @Prop option: ThemeOption = {
    id: 'gold',
    name: '星辉金',
    description: '温暖沉稳的监控主题',
    previewStart: '#FBE7B7',
    previewEnd: '#CFA356'
  }
  @Prop selected: boolean = false
  @StorageLink('themeId') themeId: ThemeId = 'gold'
  @StorageLink('isDarkMode') isDarkMode: boolean = false
  onSelect: () => void = () => {}

  @State isPressed: boolean = false

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column({ space: 12 }) {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width('100%')
            .height(76)
            .linearGradient({ angle: 135, colors: [[this.option.previewStart, 0.0], [this.option.previewEnd, 1.0]] })
            .borderRadius(16)
          Column() {
            Row() {
              Text('星辰云巡')
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor(Color.White)
              Blank()
              Text(this.selected ? '已启用' : '预览')
                .fontSize(9)
                .fontColor(Color.White)
                .backgroundColor('#33FFFFFF')
                .padding({ left: 7, right: 7, top: 3, bottom: 3 })
                .borderRadius(10)
            }.width('100%')
            Row({ space: 4 }) {
              Circle({ width: 6, height: 6 }).fill('#BFFFFFFF')
              Circle({ width: 6, height: 6 }).fill('#80FFFFFF')
              Circle({ width: 6, height: 6 }).fill('#4DFFFFFF')
              Blank()
              Text('监控空间')
                .fontSize(9)
                .fontColor('#DFFFFFFF')
            }.width('100%').margin({ top: 25 })
          }.width('100%').padding({ left: 13, right: 13, top: 12, bottom: 12 })
        }.width('100%').height(76)
        Row() {
          Column() {
            Text(this.option.name)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.selected ? this.themePalette().primary : this.themePalette().text)
            Text(this.option.description)
              .fontSize(11)
              .fontColor(this.themePalette().secondary)
              .margin({ top: 4 })
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          if (this.selected) {
            Text('当前')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.themePalette().primary)
              .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ x: 8, y: 0 })).animation({ duration: 220, curve: curves.springMotion(0.55, 0.72) }))
          }
        }.width('100%')
      }
      .width('100%')
      .padding(14)
      .backgroundColor(this.isPressed ? this.themePalette().cardPressed : this.selected ? this.themePalette().primarySoft : this.themePalette().card)
      .borderRadius(20)
      .border({ width: this.selected ? 2 : 1, color: this.selected ? this.themePalette().primary : this.themePalette().border, radius: 20 })
      .scale({ x: this.isPressed ? 0.98 : 1, y: this.isPressed ? 0.98 : 1 })
      .animation({ duration: 260, curve: curves.springMotion(0.55, 0.72) })
      if (this.selected) {
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor([Color.White])
        }
        .width(28)
        .height(28)
        .borderRadius({ topRight: 18, bottomLeft: 14 })
        .backgroundColor(this.themePalette().primary)
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.7, y: 0.7 })).animation({ duration: 220, curve: curves.springMotion(0.55, 0.72) }))
      }
    }
    .width('100%')
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) this.isPressed = true
      else if (event.type === TouchType.Up || event.type === TouchType.Cancel) this.isPressed = false
    })
    .onClick(() => {
      this.isPressed = false
      this.onSelect()
    })
  }

  private themePalette(): ThemePalette {
    return getThemePalette(this.themeId, this.isDarkMode)
  }
}

@Component
struct ColorModeOptionCard {
  @Prop mode: ColorModePreference = 'SYSTEM'
  @Prop title: string = ''
  @Prop subtitle: string = ''
  @Prop selected: boolean = false
  @StorageLink('themeId') themeId: ThemeId = 'gold'
  @StorageLink('isDarkMode') isDarkMode: boolean = false
  onSelect: () => void = () => {}

  @State isPressed: boolean = false

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column({ space: 5 }) {
        Text(this.mode === 'SYSTEM' ? '◐' : this.mode === 'LIGHT' ? '☼' : '☾')
          .fontSize(18)
          .fontColor(this.selected ? this.themePalette().primary : this.themePalette().secondary)
        Text(this.title)
          .fontSize(12)
          .fontWeight(this.selected ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(this.selected ? this.themePalette().primary : this.themePalette().text)
        Text(this.subtitle)
          .fontSize(9)
          .fontColor(this.themePalette().muted)
          .maxLines(2)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .height(88)
      .justifyContent(FlexAlign.Center)
      .padding({ left: 7, right: 7, top: 8, bottom: 8 })
      .backgroundColor(this.isPressed ? this.themePalette().cardPressed : this.selected ? this.themePalette().primarySoft : this.themePalette().card)
      .borderRadius(18)
      .border({ width: this.selected ? 2 : 1, color: this.selected ? this.themePalette().primary : this.themePalette().border, radius: 18 })
      .scale({ x: this.isPressed ? 0.96 : this.selected ? 1.02 : 1, y: this.isPressed ? 0.96 : this.selected ? 1.02 : 1 })
      .animation({ duration: 250, curve: curves.springMotion(0.55, 0.72) })
      if (this.selected) {
        Stack({ alignContent: Alignment.Center }) {
          Text('✓').fontSize(10).fontWeight(FontWeight.Bold).fontColor(Color.White)
        }
        .width(22)
        .height(22)
        .borderRadius({ topRight: 16, bottomLeft: 12 })
        .backgroundColor(this.themePalette().primary)
        .transition(TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.7, y: 0.7 })).animation({ duration: 200, curve: curves.springMotion(0.55, 0.72) }))
      }
    }
    .layoutWeight(1)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) this.isPressed = true
      else if (event.type === TouchType.Up || event.type === TouchType.Cancel) this.isPressed = false
    })
    .onClick(() => {
      this.isPressed = false
      this.onSelect()
    })
  }

  private themePalette(): ThemePalette {
    return getThemePalette(this.themeId, this.isDarkMode)
  }
}

@Component
struct DeviceDetailDestination {
  deviceId: string = ''
  connection: MonitorConnection | null = null
  @Prop layoutSize: LayoutSize = 'compact'
  @Prop windowWidthVp: number = 0
  @Prop windowHeightVp: number = 0
  @State device: Device | null = null
  @State history: Metric[] = []
  @State isLoading: boolean = true
  @State errorMessage: string = ''

  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.loadDevice()
  }

  private async loadDevice(): Promise<void> {
    if (!this.connection || !this.deviceId) {
      this.isLoading = false
      this.errorMessage = '服务器信息不可用'
      return
    }
    this.isLoading = true
    this.errorMessage = ''
    try {
      const client = new MonitorApi(this.connection)
      const responses = await Promise.all([client.device(this.deviceId), client.history(this.deviceId, 6)])
      this.device = responses[0]
      this.history = responses[1]
    } catch (error) {
      const apiError = error as MonitorApiError
      this.errorMessage = apiError?.message ?? '设备详情加载失败'
    } finally {
      this.isLoading = false
    }
  }

  private statusLabel(status: DeviceStatus): string {
    if (status === 'ONLINE') return '在线'
    if (status === 'OFFLINE') return '离线'
    return '待接入'
  }

  private statusColor(status: DeviceStatus): string {
    if (status === 'ONLINE') return COLORS.success
    if (status === 'OFFLINE') return COLORS.danger
    return COLORS.warning
  }

  private percent(value: number | undefined | null): string {
    return value === undefined || value === null ? '--' : `${Math.round(value)}%`
  }

  private finiteMetric(value: number | undefined | null): number | null {
    if (value === undefined || value === null) return null
    if (value !== value || value === Infinity || value === -Infinity) return null
    return value
  }

  private historySeriesValues(selector: (metric: Metric) => number | undefined | null): number[] {
    const raw: number[] = []
    for (const item of this.history) {
      const value = this.finiteMetric(selector(item))
      if (value !== null) raw.push(value)
    }
    return normalizePercentSeries(raw)
  }

  private metricRangeLabel(name: string, selector: (metric: Metric) => number | undefined | null): string {
    const values = this.historySeriesValues(selector)
    if (!values.length) return `${name} --`
    let min = values[0]
    let max = values[0]
    for (const value of values) {
      if (value < min) min = value
      if (value > max) max = value
    }
    return `${name} ${Math.round(min)}~${Math.round(max)}%`
  }

  private time(value: string | null): string {
    if (!value) return '暂无上报'
    return new Date(value).toLocaleString('zh-CN', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' })
  }

  private deviceServices(): ServiceMetric[] {
    return this.device?.latest?.services ?? []
  }

  private responsiveWindowWidth(): number {
    return this.windowWidthVp > 0 ? this.windowWidthVp : 360
  }

  private contentViewportWidth(): number {
    const viewportWidth: number = this.responsiveWindowWidth() - getNavigationWidth(this.layoutSize)
    return viewportWidth > 0 ? viewportWidth : this.responsiveWindowWidth()
  }

  private detailContainerWidth(): number {
    const viewportWidth: number = this.contentViewportWidth()
    const maximumWidth: number = getContentMaxWidth(this.layoutSize, viewportWidth)
    return viewportWidth < maximumWidth ? viewportWidth : maximumWidth
  }

  private detailBottomSpacing(): number {
    return this.windowHeightVp > 0 && this.windowHeightVp < 600 ? 24 : 36
  }

  private hostServiceLabel(status: string): string {
    const normalized = status.toLowerCase()
    if (normalized === 'running') return '运行中'
    if (normalized === 'stopped') return '已停止'
    if (normalized === 'not_found') return '未找到'
    if (normalized === 'unsupported') return '不支持'
    return '未知'
  }

  private hostServiceColor(status: string): string {
    const normalized = status.toLowerCase()
    if (normalized === 'running') return COLORS.success
    if (normalized === 'stopped') return COLORS.danger
    return COLORS.muted
  }

  private titleBarOptions(): HdsNavigationTitleBarOptions {
    const menuIcon: HdsNavigationIconOptions = {
      label: '刷新详情',
      icon: $r('sys.symbol.arrow_clockwise'),
      action: (): void => { this.loadDevice() }
    }
    const menuValue: HdsNavigationMenuItemOptions[] = [{ content: menuIcon }]
    const menu: HdsNavigationMenuContentOptions = { value: menuValue }
    const content: TitleBarContentOptions = {
      title: {
        mainTitle: this.device?.name ?? '服务器详情',
        subTitle: this.device ? this.statusLabel(this.device.status) : '实时状态与资源使用'
      },
      menu
    }
    const scrollEffectOpts: ScrollEffectOptions = {
      scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
    }
    const originalStyle: HdsNavigationTitleBarStyle = {
      contentStyle: {
        titleStyle: { mainTitleColor: $r('sys.color.font_primary'), subTitleColor: $r('sys.color.font_secondary') },
        backIconStyle: { iconColor: $r('sys.color.icon_primary') },
        menuStyle: { iconColor: $r('sys.color.icon_primary') }
      }
    }
    const style: TitleBarStyleOptions = {
      scrollEffectOpts,
      originalStyle,
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
      }
    }
    const options: HdsNavigationTitleBarOptions = {
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
      enableHoverMode: true,
      style,
      content
    }
    return options
  }

  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column() {
          Column({ space: 16 }) {
            if (this.isLoading && !this.device) {
              Column({ space: 12 }) {
                LoadingProgress().width(34).height(34).color(COLORS.primary)
                Text('正在加载服务器详情…').fontSize(13).fontColor(COLORS.secondary)
              }.width('100%').padding({ top: 80, bottom: 80 })
            } else if (this.errorMessage && !this.device) {
              Column({ space: 12 }) {
                SymbolGlyph($r('sys.symbol.questionmark_circle')).fontSize(30).fontColor([COLORS.danger])
                Text(this.errorMessage).fontSize(14).fontColor(COLORS.text).textAlign(TextAlign.Center)
                Button('重新加载').height(42).backgroundColor(COLORS.primary).onClick(() => { this.loadDevice() })
              }.width('100%').padding({ top: 64, bottom: 64, left: 24, right: 24 })
            } else {
              this.DeviceContent()
            }
            Blank().height(this.detailBottomSpacing())
          }
          .width('100%')
          .constraintSize({ maxWidth: this.detailContainerWidth() })
          .padding({
            left: getPageHorizontalPadding(this.layoutSize),
            right: getPageHorizontalPadding(this.layoutSize),
            top: 16
          })
        }.width('100%').alignItems(HorizontalAlign.Center)
      }.width('100%').height('100%').edgeEffect(EdgeEffect.Spring).scrollBar(BarState.Off).clip(false)
    }
    .titleBar(this.titleBarOptions())
    .hideBackButton(false)
    .hideToolBar(true)
    .bindToScrollable([this.scroller])
    .backgroundColor(COLORS.page)
  }

  @Builder
  private DeviceContent() {
    GridRow({
      columns: 12,
      gutter: { x: 16, y: 16 },
      breakpoints: { value: ['900vp'], reference: BreakpointsReference.ComponentSize }
    }) {
      GridCol({ span: { xs: 12, sm: 4 } }) {
        Column({ space: 16 }) {
          this.DeviceSummaryCard()
          this.DeviceFactsCard()
        }.width('100%')
      }
      GridCol({ span: { xs: 12, sm: 8 } }) {
        this.DeviceTrendCard()
      }
    }.width('100%')
    this.DeviceServicesCard()
    if (this.errorMessage) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.questionmark_circle')).fontSize(17).fontColor([COLORS.danger])
        Text(this.errorMessage).fontSize(12).fontColor(COLORS.danger).layoutWeight(1).maxLines(2)
        Text('重试').fontSize(12).fontColor(COLORS.primary).onClick(() => { this.loadDevice() })
      }.width('100%').padding(14).backgroundColor(COLORS.dangerSoft).borderRadius(16)
    }
  }

  @Builder
  private DeviceSummaryCard() {
    Column() {
      Row() {
        ReferenceIcon({ name: this.device?.name ?? 'S', icon: $r('sys.symbol.square_grid_2x2'), iconSize: 52, iconRadius: 14, tint: COLORS.primary })
        Column() {
          Text(this.device?.name ?? '--').fontSize(20).fontWeight(FontWeight.Bold).fontColor(COLORS.text)
          Text(this.device?.hostname || this.device?.primaryIp || '等待主机信息').fontSize(12).fontColor(COLORS.secondary).margin({ top: 5 })
        }.alignItems(HorizontalAlign.Start).margin({ left: 14 })
        Blank()
        Text(this.statusLabel(this.device?.status ?? 'PENDING')).fontSize(11).fontColor(this.statusColor(this.device?.status ?? 'PENDING'))
      }.width('100%')
      Row({ space: 10 }) {
        this.DetailMetric('CPU', this.percent(this.device?.latest?.cpuUsage), COLORS.primary)
        this.DetailMetric('内存', this.percent(this.device?.latest?.memoryUsage), COLORS.success)
        this.DetailMetric('磁盘', this.percent(this.device?.latest?.diskUsage), COLORS.warning)
      }.width('100%').margin({ top: 20 })
    }.width('100%').padding(20).backgroundColor(COLORS.card).borderRadius(22).border({ width: 1, color: COLORS.border, radius: 22 })
  }

  @Builder
  private DeviceTrendCard() {
    Column({ space: 12 }) {
      Row() {
        Text('资源趋势').fontSize(17).fontWeight(FontWeight.Bold).fontColor(COLORS.text)
        Blank()
        Text('最近 6 小时').fontSize(12).fontColor(COLORS.primary)
      }.width('100%').padding({ left: 4, right: 4 })
      if (this.history.length) {
        ReferenceMetricTrendChart({ history: this.history, chartHeight: getTrendChartHeight(this.layoutSize) })
        Row() {
          Text(this.metricRangeLabel('CPU', (metric: Metric) => metric.cpuUsage)).fontSize(11).fontColor(COLORS.primary)
          Text(this.metricRangeLabel('内存', (metric: Metric) => metric.memoryUsage)).fontSize(11).fontColor(COLORS.success).margin({ left: 10 })
          Text(this.metricRangeLabel('磁盘', (metric: Metric) => metric.diskUsage)).fontSize(11).fontColor(COLORS.warning).margin({ left: 10 })
          Blank()
          Text(`${this.history.length} 个采样点`).fontSize(11).fontColor(COLORS.muted)
        }.width('100%').margin({ top: 12 })
      } else {
        Column() {
          SymbolGlyph($r('sys.symbol.questionmark_circle')).fontSize(26).fontColor([COLORS.muted])
          Text('暂无趋势数据').fontSize(14).fontWeight(FontWeight.Medium).fontColor(COLORS.text).margin({ top: 10 })
          Text('Agent 首次上报后即可查看曲线。').fontSize(11).fontColor(COLORS.muted).margin({ top: 5 })
        }.width('100%').padding({ top: 28, bottom: 28 })
      }
    }.width('100%').padding(18).backgroundColor(COLORS.card).borderRadius(22).border({ width: 1, color: COLORS.border, radius: 22 })
  }

  @Builder
  private DeviceFactsCard() {
    Column() {
      this.DetailLine('操作系统', this.device?.os || '--')
      this.DetailLine('架构', this.device?.architecture || '--')
      this.DetailLine('分组 / 位置', `${this.device?.groupName || '未分组'} · ${this.device?.location || '未设置'}`)
      this.DetailLine('最近上报', this.time(this.device?.lastSeenAt ?? null))
    }.width('100%').padding(18).backgroundColor(COLORS.card).borderRadius(22).border({ width: 1, color: COLORS.border, radius: 22 })
  }

  @Builder
  private DeviceServicesCard() {
    Column({ space: 10 }) {
      Row() {
        Text('系统服务').fontSize(17).fontWeight(FontWeight.Bold).fontColor(COLORS.text)
        Blank()
        Text(this.deviceServices().length ? `${this.deviceServices().length} 项` : '等待上报').fontSize(11).fontColor(COLORS.primary)
      }.width('100%')
      if (this.deviceServices().length) {
        ForEach(this.deviceServices(), (service: ServiceMetric) => {
          Row() {
            Circle({ width: 8, height: 8 }).fill(this.hostServiceColor(service.status))
            Text(service.name).fontSize(13).fontColor(COLORS.text).layoutWeight(1).margin({ left: 9 })
            Text(this.hostServiceLabel(service.status)).fontSize(11).fontColor(this.hostServiceColor(service.status))
          }.width('100%').padding({ top: 8, bottom: 8 }).border({ width: { bottom: 1 }, color: COLORS.divider })
        }, (service: ServiceMetric) => `${service.name}-${service.status}`)
      } else {
        Text(this.device?.latest ? 'Agent 尚未上报系统服务' : '暂无最新指标，等待 Agent 上报').fontSize(11).fontColor(COLORS.muted).padding({ top: 10, bottom: 8 })
      }
    }.width('100%').padding(18).backgroundColor(COLORS.card).borderRadius(22).border({ width: 1, color: COLORS.border, radius: 22 })
  }

  @Builder
  private DetailMetric(label: string, value: string, color: string) {
    Column() {
      Text(value).fontSize(21).fontWeight(FontWeight.Bold).fontColor(color)
      Text(label).fontSize(11).fontColor(COLORS.secondary).margin({ top: 3 })
    }.layoutWeight(1).padding({ top: 12, bottom: 12 }).backgroundColor(COLORS.surface).borderRadius(14)
  }

  @Builder
  private DetailLine(label: string, value: string) {
    Row() {
      Text(label).fontSize(13).fontColor(COLORS.secondary)
      Blank()
      Text(value).fontSize(13).fontColor(COLORS.text).maxLines(1)
    }.width('100%').padding({ top: 10, bottom: 10 }).border({ width: { bottom: 1 }, color: COLORS.divider })
  }
}
