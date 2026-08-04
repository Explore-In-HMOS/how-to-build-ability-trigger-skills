import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { Constants } from '../model/Constants';

const DOMAIN = 0x0000;

/**
 * Secondary UIAbility for the Smart Daily Routine Automator.
 *
 * Feature 3 (deferred action agents): PillTrackerAbility is the target launched
 * by the medication WantAgent. When the deferred agent fires it starts this
 * ability with Want.action === Constants.ACTION_OPEN_PILL_TRACKER. onCreate
 * stashes that action in AppStorage under Constants.STORAGE_LAUNCH_ACTION so the
 * shared Index page can react once the UI is up, then loads the same page.
 */
export default class PillTrackerAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'PillTrackerAbility onCreate');
    this.handleLaunchWant(want, 'onCreate');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'PillTrackerAbility onNewWant');
    this.handleLaunchWant(want, 'onNewWant');
  }

  /**
   * Publish the deferred-action launch Want to AppStorage so the page can consume
   * it. Falls back to the canonical open action so the page always knows the
   * ability was reached via the medication reminder (Feature 3).
   */
  private handleLaunchWant(want: Want, source: string): void {
    const action: string = (want && want.action) ? want.action : Constants.ACTION_OPEN_PILL_TRACKER;
    AppStorage.setOrCreate(Constants.STORAGE_LAUNCH_ACTION, action);
    hilog.info(
      Constants.LOG_DOMAIN,
      Constants.LOG_TAG,
      'PillTracker launched with action %{public}s via %{public}s',
      action,
      source
    );
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'PillTrackerAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability.
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'PillTrackerAbility onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', '%{public}s', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources.
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'PillTrackerAbility onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground.
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'PillTrackerAbility onForeground');
  }

  onBackground(): void {
    // Ability has back to background.
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'PillTrackerAbility onBackground');
  }
}
