import { abilityDelegatorRegistry } from '@kit.TestKit';
import { Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium';

/**
 * Runnable hypium suite for the Smart Daily Routine Automator.
 * Drives EntryAbility through its lifecycle using abilityDelegatorRegistry:
 * add an AbilityMonitor, startAbility a Want, wait for the monitor to fire,
 * assert the ability surfaced, then clean up.
 *
 * Self-contained on purpose: it does NOT import from the main module's
 * ets/test harness so the runnable ohosTest can execute independently.
 */

const DOMAIN: number = 0x0001;
const TAG: string = 'RoutineAutomator.AbilityTest';
const BUNDLE_NAME: string = 'com.hmosdemos.wearable.how_to_build_ability_triggers_skills';
const ENTRY_ABILITY: string = 'EntryAbility';
const WAIT_TIMEOUT_MS: number = 5000;

export default function abilityTest() {
  describe('ActsAbilityTest', () => {
    let delegator: abilityDelegatorRegistry.AbilityDelegator;
    // Records lifecycle callbacks so cases can assert on the observed order.
    const events: string[] = [];
    const monitor: abilityDelegatorRegistry.AbilityMonitor = {
      abilityName: ENTRY_ABILITY,
      moduleName: 'entry',
      onAbilityCreate: () => {
        events.push('onAbilityCreate');
        hilog.info(DOMAIN, TAG, '%{public}s', 'monitor: onAbilityCreate');
      },
      onAbilityForeground: () => {
        events.push('onAbilityForeground');
        hilog.info(DOMAIN, TAG, '%{public}s', 'monitor: onAbilityForeground');
      },
      onAbilityBackground: () => {
        events.push('onAbilityBackground');
        hilog.info(DOMAIN, TAG, '%{public}s', 'monitor: onAbilityBackground');
      },
      onAbilityDestroy: () => {
        events.push('onAbilityDestroy');
        hilog.info(DOMAIN, TAG, '%{public}s', 'monitor: onAbilityDestroy');
      },
      onWindowStageCreate: () => {
        events.push('onWindowStageCreate');
        hilog.info(DOMAIN, TAG, '%{public}s', 'monitor: onWindowStageCreate');
      },
      onWindowStageRestore: () => {
        events.push('onWindowStageRestore');
      },
      onWindowStageDestroy: () => {
        events.push('onWindowStageDestroy');
      }
    };

    beforeAll(async () => {
      // Acquire the delegator once and register the monitor before any launch.
      delegator = abilityDelegatorRegistry.getAbilityDelegator();
      try {
        await delegator.addAbilityMonitor(monitor);
        hilog.info(DOMAIN, TAG, '%{public}s', 'beforeAll: ability monitor added');
      } catch (err) {
        const e: BusinessError = err as BusinessError;
        hilog.error(DOMAIN, TAG, 'addAbilityMonitor failed code=%{public}d msg=%{public}s',
          e.code, e.message);
      }
    });

    afterAll(async () => {
      // Remove the monitor so it does not leak into other suites.
      try {
        await delegator.removeAbilityMonitor(monitor);
        hilog.info(DOMAIN, TAG, '%{public}s', 'afterAll: ability monitor removed');
      } catch (err) {
        const e: BusinessError = err as BusinessError;
        hilog.error(DOMAIN, TAG, 'removeAbilityMonitor failed code=%{public}d msg=%{public}s',
          e.code, e.message);
      }
    });

    /**
     * Launches EntryAbility and waits for the monitor to hand back the ability
     * instance, proving the create lifecycle ran.
     */
    it('assertEntryAbilityLaunches', 0, async (done: () => void) => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'assertEntryAbilityLaunches begin');
      const want: Want = {
        bundleName: BUNDLE_NAME,
        abilityName: ENTRY_ABILITY
      };
      try {
        await delegator.startAbility(want);
        const ability: Object = await delegator.waitAbilityMonitor(monitor, WAIT_TIMEOUT_MS);
        // The monitor returned an ability => it was created and surfaced.
        expect(ability !== undefined && ability !== null).assertTrue();
        expect(events).assertContain('onAbilityCreate');
      } catch (err) {
        const e: BusinessError = err as BusinessError;
        hilog.error(DOMAIN, TAG, 'startAbility/wait failed code=%{public}d msg=%{public}s',
          e.code, e.message);
        expect(false).assertTrue();
      }
      done();
    });

    /**
     * Confirms the delegator can report a top ability for the launched bundle.
     */
    it('assertTopAbilityIsEntry', 0, async (done: () => void) => {
      hilog.info(DOMAIN, TAG, '%{public}s', 'assertTopAbilityIsEntry begin');
      try {
        const top: string = await delegator.getCurrentTopAbility().then((ability) => {
          return ability.context.abilityInfo.name;
        });
        hilog.info(DOMAIN, TAG, 'top ability = %{public}s', top);
        expect(top).assertEqual(ENTRY_ABILITY);
      } catch (err) {
        const e: BusinessError = err as BusinessError;
        hilog.error(DOMAIN, TAG, 'getCurrentTopAbility failed code=%{public}d msg=%{public}s',
          e.code, e.message);
        expect(false).assertTrue();
      }
      done();
    });
  });
}
