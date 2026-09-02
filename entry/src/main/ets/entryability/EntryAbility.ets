import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { MonitorStorage } from '../utils/MonitorStorage';
import { ColorModePreference } from '../model/ThemeModels';
import { AppLifecycle } from '../utils/AppLifecycle';
import { getLayoutSize, LayoutSize } from '../model/ResponsiveLayout';
import { ProfileSessionCoordinator } from '../service/ProfileSessionCoordinator';

const DOMAIN = 0x0000;

type WindowSizeChangeCallback = (size: window.Size) => void;
type AvoidAreaChangeCallback = (data: window.AvoidAreaOptions) => void;

export default class EntryAbility extends UIAbility {
  private colorModePreference: ColorModePreference = 'SYSTEM';
  private mainWindow: window.Window | undefined = undefined;
  private windowSizeChangeCallback: WindowSizeChangeCallback = (size: window.Size): void => {
    const currentWindow: window.Window | undefined = this.mainWindow;
    if (currentWindow !== undefined) {
      this.publishWindowMetrics(currentWindow, size.width, size.height);
    }
  };
  private avoidAreaChangeCallback: AvoidAreaChangeCallback = (data: window.AvoidAreaOptions): void => {
    if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
      AppStorage.setOrCreate('topRectHeight', data.area.topRect.height);
    } else if (data.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
      AppStorage.setOrCreate('bottomRectHeight', data.area.bottomRect.height);
    }
  };

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppLifecycle.setAbilityContext(this.context);
    ProfileSessionCoordinator.shared().initialize(this.context).catch((): void => {});
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    AppLifecycle.clearAbilityContext();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    this.initializeResponsiveStorage();

    // Let the page occupy the full window. The page-level expandSafeArea calls
    // then draw the background and floating controls beneath system bars.
    try {
      const mainWindow: window.Window = windowStage.getMainWindowSync();
      this.mainWindow = mainWindow;
      mainWindow.setWindowLayoutFullScreen(true).catch((error: Object) => {
        hilog.error(DOMAIN, 'testTag', 'Failed to enable fullscreen layout: %{public}s', JSON.stringify(error));
      });
      mainWindow.on('windowSizeChange', this.windowSizeChangeCallback);
      mainWindow.on('avoidAreaChange', this.avoidAreaChangeCallback);
      this.syncCurrentWindowMetrics();
      this.syncCurrentAvoidAreas();
    } catch (error) {
      hilog.error(DOMAIN, 'testTag', 'Failed to obtain main window: %{public}s', JSON.stringify(error));
    }

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      this.syncCurrentWindowMetrics();
      this.initializeTheme();
    });
  }

  private initializeResponsiveStorage(): void {
    const initialLayoutSize: LayoutSize = getLayoutSize(0);
    AppStorage.setOrCreate('windowWidthVp', 0);
    AppStorage.setOrCreate('windowHeightVp', 0);
    AppStorage.setOrCreate('layoutSize', initialLayoutSize);
  }

  private publishWindowMetrics(currentWindow: window.Window, widthPx: number, heightPx: number): void {
    try {
      const widthVp: number = currentWindow.getUIContext().px2vp(widthPx);
      const heightVp: number = currentWindow.getUIContext().px2vp(heightPx);
      const layoutSize: LayoutSize = getLayoutSize(widthVp);
      AppStorage.setOrCreate('windowWidthVp', widthVp);
      AppStorage.setOrCreate('windowHeightVp', heightVp);
      AppStorage.setOrCreate('layoutSize', layoutSize);
    } catch (error) {
      hilog.error(DOMAIN, 'testTag', 'Failed to publish window metrics: %{public}s', JSON.stringify(error));
    }
  }

  private syncCurrentWindowMetrics(): void {
    const currentWindow: window.Window | undefined = this.mainWindow;
    if (currentWindow === undefined) {
      return;
    }
    try {
      const properties: window.WindowProperties = currentWindow.getWindowProperties();
      this.publishWindowMetrics(currentWindow, properties.windowRect.width, properties.windowRect.height);
    } catch (error) {
      hilog.error(DOMAIN, 'testTag', 'Failed to synchronize window metrics: %{public}s', JSON.stringify(error));
    }
  }

  private syncCurrentAvoidAreas(): void {
    const currentWindow: window.Window | undefined = this.mainWindow;
    if (currentWindow === undefined) {
      return;
    }
    try {
      const topAvoidArea: window.AvoidArea = currentWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const bottomAvoidArea: window.AvoidArea = currentWindow.getWindowAvoidArea(
        window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      AppStorage.setOrCreate('topRectHeight', topAvoidArea.topRect.height);
      AppStorage.setOrCreate('bottomRectHeight', bottomAvoidArea.bottomRect.height);
    } catch (error) {
      hilog.error(DOMAIN, 'testTag', 'Failed to synchronize system avoid area: %{public}s', JSON.stringify(error));
    }
  }

  private async initializeTheme(): Promise<void> {
    const storage = MonitorStorage.getInstance();
    await storage.init(this.context);
    const settings = await storage.loadThemeSettings();
    this.colorModePreference = settings.colorModePreference;
    AppStorage.setOrCreate('themeId', settings.themeId);
    AppStorage.setOrCreate('colorModePreference', settings.colorModePreference);
    const configuredColorMode: ConfigurationConstant.ColorMode = this.context.config.colorMode ?? ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    AppStorage.setOrCreate('systemColorMode', configuredColorMode);
    this.updateDarkMode(configuredColorMode);
    this.applyColorMode(settings.colorModePreference);
  }

  private applyColorMode(preference: ColorModePreference): void {
    let colorMode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    if (preference === 'LIGHT') colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    if (preference === 'DARK') colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    try {
      this.context.getApplicationContext().setColorMode(colorMode);
    } catch (error) {
      hilog.error(DOMAIN, 'testTag', 'Failed to apply color mode: %{public}s', JSON.stringify(error));
    }
  }

  private updateDarkMode(colorMode: ConfigurationConstant.ColorMode): void {
    AppStorage.setOrCreate('isDarkMode', colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    const configuredColorMode: ConfigurationConstant.ColorMode = newConfig.colorMode ?? ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    AppStorage.setOrCreate('systemColorMode', configuredColorMode);
    const preference = AppStorage.get<ColorModePreference>('colorModePreference') ?? this.colorModePreference;
    this.colorModePreference = preference;
    if (preference === 'SYSTEM') this.updateDarkMode(configuredColorMode);
    this.syncCurrentWindowMetrics();
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
    const currentWindow: window.Window | undefined = this.mainWindow;
    if (currentWindow !== undefined) {
      try {
        currentWindow.off('windowSizeChange', this.windowSizeChangeCallback);
        currentWindow.off('avoidAreaChange', this.avoidAreaChangeCallback);
      } catch (error) {
        hilog.error(DOMAIN, 'testTag', 'Failed to remove window listeners: %{public}s', JSON.stringify(error));
      }
    }
    this.mainWindow = undefined;
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
