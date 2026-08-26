import { common } from '@kit.AbilityKit'

export class AppLifecycle {
  private static abilityContext: common.UIAbilityContext | null = null

  static setAbilityContext(context: common.UIAbilityContext): void {
    AppLifecycle.abilityContext = context
  }

  static clearAbilityContext(): void {
    AppLifecycle.abilityContext = null
  }

  static getAbilityContext(): common.UIAbilityContext | null {
    return AppLifecycle.abilityContext
  }
}
