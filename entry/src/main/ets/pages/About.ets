import { common } from '@kit.AbilityKit'
import { commentManager } from '@kit.AppGalleryKit'
import { curves } from '@kit.ArkUI'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { systemShare } from '@kit.ShareKit'
import { hdsMaterial, HdsNavigation, HdsNavigationTitleBarOptions, HdsNavigationTitleBarStyle, HdsNavigationTitleMode, ScrollEffectOptions, ScrollEffectType, TitleBarContentOptions, TitleBarStyleOptions } from '@kit.UIDesignKit'
import { AGREEMENT_DOCUMENT_TITLE_KEY, AGREEMENT_DOCUMENT_URL_KEY, PRIVACY_POLICY_URL, USER_AGREEMENT_URL } from '../model/AgreementModels'
import { getPageHorizontalPadding, LayoutSize } from '../model/ResponsiveLayout'
import { getThemePalette, ThemeId, ThemePalette } from '../model/ThemeModels'
import { AppInfo } from '../utils/AppInfo'
import { AppLifecycle } from '../utils/AppLifecycle'
import { appUpdate, AppUpdateOutcome } from '../utils/AppUpdate'

const APP_GALLERY_LINK: string = 'https://appgallery.huawei.com/app/detail?id=cn.xciy.xcyx'

@Entry
@Component
struct About {
  @StorageLink('themeId') themeId: ThemeId = 'gold'
  @StorageLink('isDarkMode') isDarkMode: boolean = false
  @StorageProp('windowWidthVp') windowWidthVp: number = 0
  @StorageProp('windowHeightVp') windowHeightVp: number = 0
  @StorageProp('layoutSize') layoutSize: LayoutSize = 'compact'
  @StorageProp('topRectHeight') topRectHeight: number = 0
  @StorageLink('bottomRectHeight') bottomRectHeight: number = 0
  @State versionName: string = '加载中'
  @State introMounted: boolean = true
  @State introStageVisible: boolean = false
  @State introBackdropVisible: boolean = false
  @State introPoemPrimaryVisible: boolean = false
  @State introPoemSecondaryVisible: boolean = false
  @State introPoemTertiaryVisible: boolean = false
  @State introWordmarkVisible: boolean = false
  @State introSloganVisible: boolean = false
  @State pageStageVisible: boolean = false
  @State brandStageVisible: boolean = false
  @State policyStageVisible: boolean = false
  @State supportStageVisible: boolean = false
  @State isCheckingUpdate: boolean = false
  @State isOpeningReview: boolean = false
  @State isSharing: boolean = false

  private scroller: Scroller = new Scroller()
  private introLaunchTimer: number = -1
  private poemPrimaryRevealTimer: number = -1
  private poemSecondaryRevealTimer: number = -1
  private poemTertiaryRevealTimer: number = -1
  private wordmarkRevealTimer: number = -1
  private sloganRevealTimer: number = -1
  private introFadeTimer: number = -1
  private pageRevealTimer: number = -1
  private policyRevealTimer: number = -1
  private supportRevealTimer: number = -1
  private introUnmountTimer: number = -1

  aboutToAppear(): void {
    this.loadVersionName()
    this.startEntrance()
  }

  aboutToDisappear(): void {
    this.clearEntranceTimers()
  }

  private async loadVersionName(): Promise<void> {
    this.versionName = await AppInfo.getVersionName()
  }

  private startEntrance(): void {
    this.clearEntranceTimers()
    this.introMounted = true
    this.introStageVisible = false
    this.introBackdropVisible = false
    this.introPoemPrimaryVisible = false
    this.introPoemSecondaryVisible = false
    this.introPoemTertiaryVisible = false
    this.introWordmarkVisible = false
    this.introSloganVisible = false
    this.pageStageVisible = false
    this.brandStageVisible = false
    this.policyStageVisible = false
    this.supportStageVisible = false
    this.introLaunchTimer = setTimeout(() => {
      this.getUIContext().animateTo({ duration: 560, curve: Curve.EaseOut }, () => {
        this.introStageVisible = true
        this.introBackdropVisible = true
      })
    }, 40)
    this.poemPrimaryRevealTimer = setTimeout(() => {
      this.getUIContext().animateTo({ duration: 720, curve: Curve.Smooth }, () => {
        this.introPoemPrimaryVisible = true
      })
    }, 170)
    this.poemSecondaryRevealTimer = setTimeout(() => {
      this.getUIContext().animateTo({ duration: 720, curve: Curve.Smooth }, () => {
        this.introPoemSecondaryVisible = true
      })
    }, 330)
    this.poemTertiaryRevealTimer = setTimeout(() => {
      this.getUIContext().animateTo({ duration: 720, curve: Curve.Smooth }, () => {
        this.introPoemTertiaryVisible = true
      })
    }, 490)
    this.wordmarkRevealTimer = setTimeout(() => {
      this.getUIContext().animateTo({ duration: 560, curve: Curve.EaseOut }, () => {
        this.introWordmarkVisible = true
      })
    }, 650)
    this.sloganRevealTimer = setTimeout(() => {
      this.getUIContext().animateTo({ duration: 500, curve: Curve.EaseOut }, () => {
        this.introSloganVisible = true
      })
    }, 790)
    this.introFadeTimer = setTimeout(() => {
      this.getUIContext().animateTo({ duration: 520, curve: Curve.EaseInOut }, () => {
        this.introStageVisible = false
        this.introBackdropVisible = false
      })
    }, 1640)
    this.pageRevealTimer = setTimeout(() => {
      this.getUIContext().animateTo({ duration: 560, curve: curves.springMotion(0.48, 0.76) }, () => {
        this.pageStageVisible = true
        this.brandStageVisible = true
      })
    }, 1490)
    this.policyRevealTimer = setTimeout(() => {
      this.getUIContext().animateTo({ duration: 480, curve: curves.springMotion(0.5, 0.74) }, () => {
        this.policyStageVisible = true
      })
    }, 1630)
    this.supportRevealTimer = setTimeout(() => {
      this.getUIContext().animateTo({ duration: 500, curve: curves.springMotion(0.52, 0.72) }, () => {
        this.supportStageVisible = true
      })
    }, 1750)
    this.introUnmountTimer = setTimeout(() => {
      this.introMounted = false
    }, 2200)
  }

  private clearEntranceTimers(): void {
    if (this.introLaunchTimer >= 0) clearTimeout(this.introLaunchTimer)
    if (this.poemPrimaryRevealTimer >= 0) clearTimeout(this.poemPrimaryRevealTimer)
    if (this.poemSecondaryRevealTimer >= 0) clearTimeout(this.poemSecondaryRevealTimer)
    if (this.poemTertiaryRevealTimer >= 0) clearTimeout(this.poemTertiaryRevealTimer)
    if (this.wordmarkRevealTimer >= 0) clearTimeout(this.wordmarkRevealTimer)
    if (this.sloganRevealTimer >= 0) clearTimeout(this.sloganRevealTimer)
    if (this.introFadeTimer >= 0) clearTimeout(this.introFadeTimer)
    if (this.pageRevealTimer >= 0) clearTimeout(this.pageRevealTimer)
    if (this.policyRevealTimer >= 0) clearTimeout(this.policyRevealTimer)
    if (this.supportRevealTimer >= 0) clearTimeout(this.supportRevealTimer)
    if (this.introUnmountTimer >= 0) clearTimeout(this.introUnmountTimer)
    this.introLaunchTimer = -1
    this.poemPrimaryRevealTimer = -1
    this.poemSecondaryRevealTimer = -1
    this.poemTertiaryRevealTimer = -1
    this.wordmarkRevealTimer = -1
    this.sloganRevealTimer = -1
    this.introFadeTimer = -1
    this.pageRevealTimer = -1
    this.policyRevealTimer = -1
    this.supportRevealTimer = -1
    this.introUnmountTimer = -1
  }

  private palette(): ThemePalette {
    return getThemePalette(this.themeId, this.isDarkMode)
  }

  private contentBottomInset(): number {
    return 38 + this.getUIContext().px2vp(this.bottomRectHeight)
  }

  private contentTopInset(): number {
    return 56 + this.getUIContext().px2vp(this.topRectHeight)
  }

  private contentMaximumWidth(): number {
    if (this.layoutSize === 'medium') return 760
    if (this.layoutSize === 'expanded') return 1160
    return this.windowWidthVp > 0 ? this.windowWidthVp : 600
  }

  private introMaximumWidth(): number {
    if (this.layoutSize === 'medium') return 760
    if (this.layoutSize === 'expanded') return 1160
    return this.windowWidthVp > 0 ? this.windowWidthVp : 600
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message })
    } catch (_) {
    }
  }

  private async openAgreementDocument(title: string, url: string): Promise<void> {
    AppStorage.setOrCreate(AGREEMENT_DOCUMENT_TITLE_KEY, title)
    AppStorage.setOrCreate(AGREEMENT_DOCUMENT_URL_KEY, url)
    try {
      await this.getUIContext().getRouter().pushUrl({ url: 'pages/AgreementWeb' })
    } catch (_) {
      this.toast('协议页面暂时无法打开，请稍后重试')
    }
  }

  private async checkUpdate(): Promise<void> {
    if (this.isCheckingUpdate) return
    const context: common.UIAbilityContext | null = AppLifecycle.getAbilityContext()
    if (context === null) {
      this.toast('暂时无法检查更新')
      return
    }
    this.isCheckingUpdate = true
    const outcome: AppUpdateOutcome = await appUpdate.checkAndShow(context)
    this.isCheckingUpdate = false
    if (outcome === AppUpdateOutcome.UP_TO_DATE) this.toast('已是最新版本')
    if (outcome === AppUpdateOutcome.BUSY) this.toast('正在检查更新')
    if (outcome === AppUpdateOutcome.DIALOG_FAILED) this.toast('更新窗口暂时无法打开')
    if (outcome === AppUpdateOutcome.FAILED) this.toast('检查更新失败，请稍后重试')
  }

  private async openReview(): Promise<void> {
    if (this.isOpeningReview) return
    const context: common.UIAbilityContext | null = AppLifecycle.getAbilityContext()
    if (context === null) {
      this.toast('暂时无法打开评论窗口')
      return
    }
    this.isOpeningReview = true
    try {
      await commentManager.showCommentDialog(context)
    } catch (_) {
      this.toast('当前暂时无法评论，请稍后重试')
    } finally {
      this.isOpeningReview = false
    }
  }

  private async shareToFriend(): Promise<void> {
    if (this.isSharing) return
    const context: common.UIAbilityContext | null = AppLifecycle.getAbilityContext()
    if (context === null) {
      this.toast('暂时无法分享')
      return
    }
    this.isSharing = true
    const record: systemShare.SharedRecord = {
      utd: utd.UniformDataType.HYPERLINK,
      content: APP_GALLERY_LINK,
      title: '星辰云巡',
      description: '随时掌握服务器、网络服务与告警状态。'
    }
    const data: systemShare.SharedData = new systemShare.SharedData(record)
    const controller: systemShare.ShareController = new systemShare.ShareController(data)
    const options: systemShare.ShareControllerOptions = {
      previewMode: systemShare.SharePreviewMode.DEFAULT,
      selectionMode: systemShare.SelectionMode.SINGLE
    }
    try {
      await controller.show(context, options)
    } catch (_) {
      this.toast('分享面板暂时无法打开')
    } finally {
      this.isSharing = false
    }
  }

  private titleBarOptions(): HdsNavigationTitleBarOptions {
    const content: TitleBarContentOptions = {
      title: { mainTitle: '关于星辰云巡' }
    }
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
      content,
      style,
      enableHoverMode: true,
      avoidLayoutSafeArea: true
    }
    return options
  }

  build() {
    HdsNavigation() {
      Stack({ alignContent: Alignment.TopStart }) {
        Scroll(this.scroller) {
          Column() {
            Blank().height(this.contentTopInset()).width('100%')
            Column() {
              if (this.layoutSize === 'expanded') {
                Row({ space: 28 }) {
                  Column() {
                    this.BrandCard()
                  }
                  .layoutWeight(5)
                  Column() {
                    this.PolicySection()
                    this.SupportSection()
                  }
                  .layoutWeight(7)
                }
                .width('100%')
                .alignItems(VerticalAlign.Top)
              } else {
                this.BrandCard()
                this.PolicySection()
                this.SupportSection()
              }
            }
            .width('100%')
            .constraintSize({ maxWidth: this.contentMaximumWidth() })
            Column() {
              Text('让每一次连接，都清晰可见')
                .fontSize(12)
                .fontColor(this.palette().muted)
                .opacity(this.supportStageVisible ? 1 : 0)
              Text('Copyright © 2026 星辰云巡')
                .fontSize(11)
                .fontColor(this.palette().muted)
                .margin({ top: 6 })
                .opacity(this.supportStageVisible ? 0.82 : 0)
            }
            .width('100%')
            .constraintSize({ maxWidth: this.contentMaximumWidth() })
            .alignItems(HorizontalAlign.Center)
            .margin({ top: 26, bottom: this.contentBottomInset() })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({
            left: getPageHorizontalPadding(this.layoutSize),
            right: getPageHorizontalPadding(this.layoutSize)
          })
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .opacity(this.pageStageVisible ? 1 : 0)
        .translate({ y: this.pageStageVisible ? 0 : 24 })
        if (this.introMounted) {
          this.IntroScene()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.palette().page)
    }
    .mode(NavigationMode.Stack)
    .titleBar(this.titleBarOptions())
    .bindToScrollable([this.scroller])
    .hideBackButton(false)
    .titleMode(HdsNavigationTitleMode.MINI)
    .backgroundColor(this.palette().page)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }

  @Builder
  private IntroScene() {
    Stack({ alignContent: Alignment.TopStart }) {
      Row() {
        Stack({ alignContent: Alignment.TopStart }) {
          Row() {
            Column()
              .width('64%')
              .height('100%')
              .linearGradient({
                angle: 90,
                colors: [[Color.Transparent, 0.0], [this.palette().primarySoft, 1.0]]
              })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.End)
          .opacity(this.introBackdropVisible ? 0.62 : 0)
          Row({ space: 18 }) {
            Text('云\n海\n自\n此\n有\n回\n声')
              .fontSize(15)
              .fontWeight(FontWeight.Normal)
              .fontColor(this.palette().secondary)
              .lineHeight(29)
              .textAlign(TextAlign.Center)
              .opacity(this.introPoemTertiaryVisible ? 0.46 : 0)
              .translate({ y: this.introPoemTertiaryVisible ? 0 : 18 })
            Text('星\n光\n落\n在\n连\n接\n间')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.palette().text)
              .lineHeight(29)
              .textAlign(TextAlign.Center)
              .opacity(this.introPoemSecondaryVisible ? 0.68 : 0)
              .translate({ y: this.introPoemSecondaryVisible ? 0 : 18 })
            Text('巡\n夜\n不\n问\n归\n程')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.palette().primary)
              .lineHeight(31)
              .textAlign(TextAlign.Center)
              .opacity(this.introPoemPrimaryVisible ? 0.92 : 0)
              .translate({ y: this.introPoemPrimaryVisible ? 0 : 18 })
          }
          .width('100%')
          .justifyContent(FlexAlign.End)
          .alignItems(VerticalAlign.Top)
          .padding({ top: 148, right: 34 })
          Column() {
            Text('星辰云巡')
              .fontSize(27)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.palette().text)
              .letterSpacing(2)
              .opacity(this.introWordmarkVisible ? 1 : 0)
              .translate({ x: this.introWordmarkVisible ? 0 : -12 })
            Text('让每一次连接，都清晰可见')
              .fontSize(12)
              .fontColor(this.palette().secondary)
              .letterSpacing(0.8)
              .margin({ top: 10 })
              .opacity(this.introSloganVisible ? 0.8 : 0)
              .translate({ x: this.introSloganVisible ? 0 : -12 })
          }
          .width('100%')
          .height('100%')
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.End)
          .padding({ left: 30, bottom: 82 })
        }
        .width('100%')
        .height('100%')
        .constraintSize({ maxWidth: this.introMaximumWidth() })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.palette().page)
    .opacity(this.introStageVisible ? 1 : 0)
  }

  @Builder
  private BrandCard() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height(260)
        .borderRadius(32)
        .linearGradient({ angle: 135, colors: [[this.palette().heroStart, 0.0], [this.palette().heroEnd, 1.0]] })
        .shadow({ radius: 28, color: this.palette().heroShadow, offsetY: 12 })
      Circle({ width: 120, height: 120 })
        .fill('#20FFFFFF')
        .position({ x: -30, y: -28 })
      Circle({ width: 78, height: 78 })
        .fill('#16FFFFFF')
        .position({ x: '82%', y: 186 })
      Column() {
        Stack({ alignContent: Alignment.Center }) {
          Column().width(96).height(96).borderRadius(30).backgroundColor('#28FFFFFF')
          Image($r('app.media.xingchen_logo'))
            .width(80)
            .height(80)
            .borderRadius(24)
            .objectFit(ImageFit.Cover)
        }
        .margin({ bottom: 16 })
        Text('星辰云巡')
          .fontSize(27)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.palette().heroText)
        Text(`版本 ${this.versionName}`)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.palette().heroText)
          .opacity(0.72)
          .margin({ top: 7 })
        Text('轻量、清晰、可信赖的服务器监控伙伴')
          .fontSize(12)
          .fontColor(this.palette().heroText)
          .opacity(0.78)
          .margin({ top: 12 })
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height(260)
    .opacity(this.brandStageVisible ? 1 : 0)
    .translate({ y: this.brandStageVisible ? 0 : 28 })
    .scale({ x: this.brandStageVisible ? 1 : 0.94, y: this.brandStageVisible ? 1 : 0.94 })
  }

  @Builder
  private PolicySection() {
    Column() {
      this.SectionTitle('相关政策', '透明、清晰地说明我们如何提供服务')
      Column() {
        AboutActionRow({
          title: '用户协议',
          subtitle: '了解服务规则与双方权利',
          icon: $r('sys.symbol.checkmark'),
          accent: this.palette().success,
          iconBackground: this.palette().iconSuccess,
          showDivider: true,
          onActivate: () => { this.openAgreementDocument('用户协议', USER_AGREEMENT_URL) }
        })
        AboutActionRow({
          title: '隐私政策',
          subtitle: '了解信息处理与隐私保护方式',
          icon: $r('sys.symbol.lock'),
          accent: this.palette().primary,
          iconBackground: this.palette().iconPrimary,
          onActivate: () => { this.openAgreementDocument('隐私政策', PRIVACY_POLICY_URL) }
        })
      }
      .width('100%')
      .clip(true)
      .backgroundColor(this.palette().card)
      .borderRadius(26)
      .border({ width: 1, color: this.palette().border, radius: 26 })
      .shadow({ radius: 18, color: this.palette().shadowStrong, offsetY: 7 })
    }
    .width('100%')
    .margin({ top: this.layoutSize === 'expanded' ? 0 : 28 })
    .opacity(this.policyStageVisible ? 1 : 0)
    .translate({ y: this.policyStageVisible ? 0 : 26 })
  }

  @Builder
  private SupportSection() {
    Column() {
      this.SectionTitle('支持我们', '你的每一次反馈，都让星光更明亮')
      Column() {
        AboutActionRow({
          title: '检查更新',
          subtitle: this.isCheckingUpdate ? '正在连接应用市场…' : '检查是否有可用的新版本',
          icon: $r('sys.symbol.arrow_clockwise'),
          accent: this.palette().primary,
          iconBackground: this.palette().iconPrimary,
          showDivider: true,
          loading: this.isCheckingUpdate,
          onActivate: () => { this.checkUpdate() }
        })
        AboutActionRow({
          title: '好评鼓励',
          subtitle: this.isOpeningReview ? '正在打开评论窗口…' : '在应用市场留下你的认可',
          icon: $r('sys.symbol.checkmark'),
          accent: this.palette().warning,
          iconBackground: this.palette().iconWarning,
          showDivider: true,
          loading: this.isOpeningReview,
          onActivate: () => { this.openReview() }
        })
        AboutActionRow({
          title: '分享给朋友',
          subtitle: this.isSharing ? '正在准备分享内容…' : '把星辰云巡推荐给更多朋友',
          icon: $r('sys.symbol.share'),
          accent: this.palette().purple,
          iconBackground: this.palette().iconPurple,
          loading: this.isSharing,
          onActivate: () => { this.shareToFriend() }
        })
      }
      .width('100%')
      .clip(true)
      .backgroundColor(this.palette().card)
      .borderRadius(26)
      .border({ width: 1, color: this.palette().border, radius: 26 })
      .shadow({ radius: 18, color: this.palette().shadowStrong, offsetY: 7 })
    }
    .width('100%')
    .margin({ top: 28 })
    .opacity(this.supportStageVisible ? 1 : 0)
    .translate({ y: this.supportStageVisible ? 0 : 28 })
  }

  @Builder
  private SectionTitle(title: string, subtitle: string) {
    Column() {
      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.palette().text)
      Text(subtitle)
        .fontSize(11)
        .fontColor(this.palette().secondary)
        .margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .margin({ left: 4, bottom: 12 })
  }
}

@Component
struct AboutActionRow {
  @Prop title: string = ''
  @Prop subtitle: string = ''
  @Prop icon: Resource = $r('sys.symbol.questionmark_circle')
  @Prop accent: ResourceColor = '#000000'
  @Prop iconBackground: ResourceColor = '#00000000'
  @Prop showDivider: boolean = false
  @Prop loading: boolean = false
  @StorageLink('themeId') themeId: ThemeId = 'gold'
  @StorageLink('isDarkMode') isDarkMode: boolean = false
  @State isPressed: boolean = false
  @State isHovered: boolean = false
  @State hasFocus: boolean = false
  onActivate: () => void = () => {}

  private palette(): ThemePalette {
    return getThemePalette(this.themeId, this.isDarkMode)
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width(44)
            .height(44)
            .borderRadius(14)
            .backgroundColor(this.iconBackground)
          SymbolGlyph(this.icon)
            .fontSize(20)
            .fontColor([this.accent])
        }
        .margin({ right: 13 })
        Column() {
          Text(this.title)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.palette().text)
            .maxLines(1)
          Text(this.subtitle)
            .fontSize(11)
            .fontColor(this.palette().secondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 5 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ right: 10 })
        if (this.loading) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color(this.accent)
        } else {
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(14)
            .fontColor([this.isPressed ? this.accent : this.palette().muted])
            .opacity(this.isPressed ? 1 : 0.48)
        }
      }
      .width('100%')
      .padding({ left: 15, right: 15, top: 15, bottom: 15 })
      .backgroundColor(this.isPressed || this.isHovered ? this.palette().cardPressed : Color.Transparent)
      .borderRadius(16)
      .border({
        width: this.hasFocus ? 3 : (this.isHovered ? 1 : 0),
        color: this.hasFocus ? this.accent : this.palette().border,
        radius: 16
      })
      .scale({ x: this.isPressed ? 0.985 : (this.isHovered ? 1.005 : 1), y: this.isPressed ? 0.985 : (this.isHovered ? 1.005 : 1) })
      .animation({ duration: 170, curve: curves.springMotion(0.62, 0.52) })
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
        if (event.type === TouchType.Down) this.isPressed = true
        if (event.type === TouchType.Up || event.type === TouchType.Cancel) this.isPressed = false
      })
      .onClick(() => {
        this.isPressed = false
        this.onActivate()
      })
      if (this.showDivider) {
        Divider()
          .color(this.palette().divider)
          .margin({ left: 72, right: 15 })
      }
    }
    .width('100%')
  }
}
