import { webview } from '@kit.ArkWeb'
import { hdsMaterial, HdsNavigation, HdsNavigationTitleBarOptions, HdsNavigationTitleBarStyle, HdsNavigationTitleMode, ScrollEffectOptions, ScrollEffectType, TitleBarContentOptions, TitleBarStyleOptions } from '@kit.UIDesignKit'
import { AGREEMENT_DOCUMENT_TITLE_KEY, AGREEMENT_DOCUMENT_URL_KEY, PRIVACY_POLICY_URL } from '../model/AgreementModels'
import { LayoutSize } from '../model/ResponsiveLayout'

@Entry
@Component
struct AgreementWeb {
  @State documentTitle: string = '隐私政策'
  @State documentUrl: string = PRIVACY_POLICY_URL
  @StorageLink('isDarkMode') isDarkMode: boolean = false
  @StorageProp('windowWidthVp') windowWidthVp: number = 0
  @StorageProp('windowHeightVp') windowHeightVp: number = 0
  @StorageProp('layoutSize') layoutSize: LayoutSize = 'compact'
  @StorageProp('topRectHeight') topRectHeight: number = 0
  @StorageProp('bottomRectHeight') bottomRectHeight: number = 0
  private controller: webview.WebviewController = new webview.WebviewController()

  aboutToAppear(): void {
    this.documentTitle = AppStorage.get<string>(AGREEMENT_DOCUMENT_TITLE_KEY) ?? '隐私政策'
    this.documentUrl = AppStorage.get<string>(AGREEMENT_DOCUMENT_URL_KEY) ?? PRIVACY_POLICY_URL
  }

  onBackPress(): boolean {
    try {
      if (this.controller.accessBackward()) {
        this.controller.backward()
        return true
      }
    } catch (_) {
    }
    return false
  }

  private pageColor(): string {
    return this.isDarkMode ? '#101114' : '#F7F7F9'
  }

  private contentTopInset(): number {
    return 56 + this.getUIContext().px2vp(this.topRectHeight)
  }

  private contentBottomInset(): number {
    return this.getUIContext().px2vp(this.bottomRectHeight)
  }

  private contentMaximumWidth(): number {
    if (this.layoutSize === 'medium') return 840
    if (this.layoutSize === 'expanded') return 1080
    return this.windowWidthVp > 0 ? this.windowWidthVp : 600
  }

  private titleBarOptions(): HdsNavigationTitleBarOptions {
    const content: TitleBarContentOptions = {
      title: { mainTitle: this.documentTitle }
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
      Column() {
        Blank().height(this.contentTopInset()).width('100%')
        Row() {
          Web({ src: this.documentUrl, controller: this.controller })
            .darkMode(WebDarkMode.Auto)
            .backgroundColor(this.pageColor())
            .width('100%')
            .height('100%')
            .constraintSize({ maxWidth: this.contentMaximumWidth() })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        Blank().height(this.contentBottomInset()).width('100%')
      }
      .width('100%')
        .height('100%')
      .backgroundColor(this.pageColor())
    }
    .mode(NavigationMode.Stack)
    .titleBar(this.titleBarOptions())
    .hideBackButton(false)
    .titleMode(HdsNavigationTitleMode.MINI)
    .backgroundColor(this.pageColor())
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}
