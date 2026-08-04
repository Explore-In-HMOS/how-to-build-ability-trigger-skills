import { AbilityConstant, ConfigurationConstant, UIAbility, Want, AtomicServiceOptions, common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { Constants } from '../model/Constants';

const DOMAIN = 0x0000;

/**
 * Primary UIAbility for the Smart Daily Routine Automator.
 *
 * Feature 1 (skill-based intent discovery): onCreate / onNewWant inspect the
 * incoming Want.action. When it matches a declared skill (START_WORKOUT) the
 * action is stashed in AppStorage under Constants.STORAGE_LAUNCH_ACTION so the
 * Index page can react to it once the UI is up.
 *
 * Feature 5 (lightweight config): openCompanionService() demonstrates launching
 * a companion atomic service via AtomicServiceOptions. It is not auto-invoked.
 */
export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      const bErr = err as BusinessError;
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(bErr));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    this.handleLaunchWant(want, 'onCreate');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onNewWant');
    this.handleLaunchWant(want, 'onNewWant');
  }

  /**
   * Match the launch Want against declared skills and, on a hit, publish the
   * action to AppStorage so the page can consume it (Feature 1).
   */
  private handleLaunchWant(want: Want, source: string): void {
    const action: string | undefined = want ? want.action : undefined;
    if (!action) {
      return;
    }
    if (this.isDeclaredSkillAction(action)) {
      AppStorage.setOrCreate(Constants.STORAGE_LAUNCH_ACTION, action);
      hilog.info(
        Constants.LOG_DOMAIN,
        Constants.LOG_TAG,
        'Matched skill action %{public}s via %{public}s',
        action,
        source
      );
    } else {
      hilog.info(
        Constants.LOG_DOMAIN,
        Constants.LOG_TAG,
        'Unmatched launch action %{public}s via %{public}s',
        action,
        source
      );
    }
  }

  /** True when the action corresponds to a skill EntryAbility declares/handles. */
  private isDeclaredSkillAction(action: string): boolean {
    return action === Constants.ACTION_START_WORKOUT ||
      action === Constants.ACTION_HYDRATION ||
      action === Constants.ACTION_SEDENTARY;
  }

  /**
   * Feature 5 demonstration: launch a lightweight companion atomic service using
   * AtomicServiceOptions. Not auto-called; wired for manual invocation/testing.
   */
  async openCompanionService(): Promise<void> {
    const options: AtomicServiceOptions = {
      parameters: {
        'source': Constants.ENTRY_ABILITY,
        'action': Constants.ACTION_OPEN_PILL_TRACKER
      }
    };
    try {
      const ctx = this.context as common.UIAbilityContext;
      await ctx.openAtomicService(Constants.ATOMIC_SERVICE_APP_ID, options);
      hilog.info(
        Constants.LOG_DOMAIN,
        Constants.LOG_TAG,
        'Opened companion atomic service %{public}s',
        Constants.ATOMIC_SERVICE_APP_ID
      );
    } catch (err) {
      const bErr = err as BusinessError;
      hilog.error(
        Constants.LOG_DOMAIN,
        Constants.LOG_TAG,
        'openAtomicService failed. code=%{public}d msg=%{public}s',
        bErr.code,
        bErr.message
      );
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
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
