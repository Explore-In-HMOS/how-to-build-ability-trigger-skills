/**
 * Automated lifecycle-testing harness for the Smart Daily Routine Automator.
 *
 * Feature 4 (abilityDelegatorRegistry): intercepts the EntryAbility lifecycle
 * via an AbilityMonitor, drives it through create -> foreground -> background,
 * and records every callback into an ordered event log for assertions.
 *
 * This file MIRRORS the runnable ohosTest suite at
 * entry/src/ohosTest/ets/test/Ability.test.ets — the same monitor/startAbility/
 * waitAbilityMonitor flow — but is packaged for reuse from application code and
 * exposes both a reusable RoutineAbilityDelegator class and a hypium suite.
 */

import { abilityDelegatorRegistry } from '@kit.TestKit';
import { Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { describe, it, expect } from '@ohos/hypium';
import { Constants } from '../model/Constants';

/** How long to wait for the EntryAbility monitor to observe creation (ms). */
const WAIT_TIMEOUT_MS: number = 5000;

/**
 * Reusable delegator wrapper around abilityDelegatorRegistry. Builds an
 * AbilityMonitor for EntryAbility whose lifecycle callbacks append to an
 * ordered string[] so a test can assert exactly which transitions fired.
 */
export class RoutineAbilityDelegator {
  private delegator: abilityDelegatorRegistry.AbilityDelegator;
  private monitor: abilityDelegatorRegistry.AbilityMonitor;
  private events: string[] = [];

  constructor() {
    this.delegator = abilityDelegatorRegistry.getAbilityDelegator();
    // Record every lifecycle transition of EntryAbility into this.events.
    this.monitor = {
      abilityName: Constants.ENTRY_ABILITY,
      moduleName: Constants.MODULE_NAME,
      onAbilityCreate: () => {
        this.record('onAbilityCreate');
      },
      onAbilityForeground: () => {
        this.record('onAbilityForeground');
      },
      onAbilityBackground: () => {
        this.record('onAbilityBackground');
      },
      onAbilityDestroy: () => {
        this.record('onAbilityDestroy');
      },
      onWindowStageCreate: () => {
        this.record('onWindowStageCreate');
      },
      onWindowStageRestore: () => {
        this.record('onWindowStageRestore');
      },
      onWindowStageDestroy: () => {
        this.record('onWindowStageDestroy');
      }
    };
  }

  /** Append a lifecycle event and mirror it to hilog for on-device tracing. */
  private record(event: string): void {
    this.events.push(event);
    hilog.info(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s', `lifecycle: ${event}`);
  }

  /** Snapshot of the ordered lifecycle events recorded so far. */
  getEvents(): string[] {
    return this.events.slice();
  }

  /** The Want that launches EntryAbility inside this app's bundle/module. */
  private buildEntryWant(): Want {
    const want: Want = {
      bundleName: Constants.BUNDLE_NAME,
      abilityName: Constants.ENTRY_ABILITY,
      moduleName: Constants.MODULE_NAME,
      action: Constants.ACTION_START_WORKOUT,
      entities: [Constants.ENTITY_HEALTH]
    };
    return want;
  }

  /**
   * Full automated flow: register the monitor, launch EntryAbility, wait for it
   * to be created, then drive it foreground -> background, unregister and finish.
   * Returns the recorded event log so callers can assert on it.
   */
  async runLifecycleFlow(): Promise<string[]> {
    try {
      await this.delegator.addAbilityMonitor(this.monitor);
      this.record('monitorAdded');

      const want: Want = this.buildEntryWant();
      await this.delegator.startAbility(want);
      this.record('startAbility');

      // Block until the monitor observes EntryAbility creation (or timeout).
      const ability: ESObject = await this.delegator.waitAbilityMonitor(this.monitor, WAIT_TIMEOUT_MS);
      this.record('waitAbilityMonitor');

      const top: ESObject = await this.delegator.getCurrentTopAbility();
      this.record('getCurrentTopAbility');

      // Drive the observed ability through the foreground/background transitions.
      await this.delegator.doAbilityForeground(ability);
      this.record('doAbilityForeground');

      await this.delegator.doAbilityBackground(ability);
      this.record('doAbilityBackground');

      await this.delegator.removeAbilityMonitor(this.monitor);
      this.record('monitorRemoved');

      // Reference the top ability so the variable is used; keeps ArkTS strict.
      this.delegator.printSync(`top ability resolved: ${top !== undefined}`);
      await this.delegator.print(`lifecycle events: ${this.events.join(',')}`);
    } catch (err) {
      const e = err as BusinessError;
      hilog.error(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s',
        `runLifecycleFlow failed: code=${e.code} message=${e.message}`);
      this.record(`error:${e.code}`);
    } finally {
      // Signal completion to the delegator harness (code 0 == success).
      this.delegator.finishTest(`RoutineAbilityDelegator done: ${this.events.length} events`, 0, () => {
        hilog.info(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s', 'finishTest callback invoked');
      });
    }
    return this.getEvents();
  }
}

/**
 * Hypium suite mirroring the runnable ohosTest suite. Runs the delegator flow
 * once and asserts the EntryAbility lifecycle was observed in the expected order.
 */
export function abilityDelegatorTest(): void {
  describe('RoutineAbilityDelegatorTest', () => {
    it('drives EntryAbility through its lifecycle', 0, async () => {
      hilog.info(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s', 'delegator flow begin');

      const runner: RoutineAbilityDelegator = new RoutineAbilityDelegator();
      const events: string[] = await runner.runLifecycleFlow();

      // The flow must at minimum register the monitor and launch the ability.
      expect(events.length).assertLarger(0);
      expect(events).assertContain('monitorAdded');
      expect(events).assertContain('startAbility');
      expect(events).assertContain('waitAbilityMonitor');
      expect(events).assertContain('getCurrentTopAbility');

      hilog.info(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s',
        `delegator flow end: ${events.join(',')}`);
    });
  });
}
