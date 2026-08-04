import { Constants } from '../model/Constants';
import {
  RoutineTask,
  DeferredReminder,
  SkillIntent,
  WearScreen,
  PermissionState,
  RoutineType,
  RoutineStatus,
  RoutineFactory
} from '../model/RoutineModel';
import { wantAgent, Want, WantAgent, AtomicServiceOptions, common, abilityAccessCtrl, bundleManager, Permissions }
  from '@kit.AbilityKit';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { display } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';

@Observed
export class RoutineViewModel {
  // -------- Observable state --------
  tasks: RoutineTask[] = [];
  skills: SkillIntent[] = [];
  reminder: DeferredReminder = RoutineFactory.defaultReminder();
  screen: WearScreen = RoutineViewModel.fallbackScreen();
  permissions: PermissionState[] = [];
  statusMessage: string = 'Ready';
  lastMatchedIntent: string = '';
  notificationsEnabled: boolean = false;

  // -------- Live reminder registry (real reminderAgentManager ids) --------
  /** Keyed by RoutineTask.id -> the published reminder id, so it can be cancelled. */
  private taskReminderIds: Map<string, number> = new Map<string, number>();
  /** The published medication alarm id (-1 when none is scheduled). */
  private medicationReminderId: number = -1;

  /**
   * Compute round-screen geometry from the real display, converting px->vp and
   * deriving the corner-safe inset for the inscribed square. Falls back to the
   * 466px default if the query throws.
   */
  initScreen(): WearScreen {
    try {
      const d: display.Display = display.getDefaultDisplaySync();
      const widthPx: number = d.width;
      const heightPx: number = d.height;
      // Convert physical px -> logical vp using the display's own density.
      // (The global px2vp is deprecated and only valid inside a UI context.)
      const density: number = d.densityPixels > 0 ? d.densityPixels : Constants.FALLBACK_DENSITY_PIXELS;
      const diameterVp: number = Math.min(widthPx, heightPx) / density;
      const radiusVp: number = diameterVp / 2;
      const safeInsetVp: number = radiusVp * (1 - Math.SQRT1_2);
      const wear: WearScreen = {
        widthPx: widthPx,
        heightPx: heightPx,
        diameterVp: diameterVp,
        radiusVp: radiusVp,
        safeInsetVp: safeInsetVp,
        centerXVp: radiusVp,
        centerYVp: radiusVp,
        isRound: true
      };
      this.screen = wear;
      hilog.info(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s',
        `initScreen ok ${widthPx}x${heightPx}px -> ${diameterVp.toFixed(1)}vp`);
      return wear;
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      hilog.error(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s',
        `initScreen failed code=${e.code} msg=${e.message}; using fallback`);
      const wear: WearScreen = RoutineViewModel.fallbackScreen();
      this.screen = wear;
      return wear;
    }
  }

  /** Fallback geometry built from Constants.FALLBACK_DIAMETER_PX. */
  private static fallbackScreen(): WearScreen {
    const diameterVp: number = Constants.FALLBACK_DIAMETER_PX / Constants.FALLBACK_DENSITY_PIXELS;
    const radiusVp: number = diameterVp / 2;
    const safeInsetVp: number = radiusVp * (1 - Math.SQRT1_2);
    return {
      widthPx: Constants.FALLBACK_DIAMETER_PX,
      heightPx: Constants.FALLBACK_DIAMETER_PX,
      diameterVp: diameterVp,
      radiusVp: radiusVp,
      safeInsetVp: safeInsetVp,
      centerXVp: radiusVp,
      centerYVp: radiusVp,
      isRound: true
    };
  }

  /** Seed all state from the model factory (single home for defaults). */
  loadDefaults(): void {
    this.tasks = RoutineFactory.makeDefaults();
    this.skills = RoutineFactory.defaultSkills();
    this.reminder = RoutineFactory.defaultReminder();
    this.permissions = RoutineFactory.defaultPermissions();
    this.statusMessage = 'Defaults loaded';
    hilog.info(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s',
      `loadDefaults: ${this.tasks.length} tasks, ${this.skills.length} skills`);
  }

  /**
   * Ask the system to allow this app to post notifications. Reminders published
   * by reminderAgentManager surface as notifications, so this is required for the
   * user to actually see hydration / sedentary / medication reminders fire.
   */
  async ensureNotificationsEnabled(context: common.UIAbilityContext): Promise<void> {
    try {
      await notificationManager.requestEnableNotification(context);
      this.notificationsEnabled = true;
      hilog.info(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s', 'notifications enabled');
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      // Code 1600004 == user declined; treat as "not enabled" rather than fatal.
      this.notificationsEnabled = false;
      hilog.warn(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s',
        `requestEnableNotification not granted code=${e.code} msg=${e.message}`);
    }
  }

  /**
   * Flip a task on/off. Enabling publishes a real countdown reminder; disabling
   * cancels it. Mutates the task properties in place so @ObjectLink children
   * re-render. Awaitable so the caller can refresh page state afterwards.
   */
  async toggleTask(task: RoutineTask): Promise<void> {
    task.enabled = !task.enabled;
    if (task.enabled) {
      this.statusMessage = `${task.title} enabled`;
      await this.scheduleTrigger(task);
    } else {
      await this.cancelTrigger(task);
      this.statusMessage = `${task.title} disabled`;
    }
  }

  /**
   * Publish a REAL countdown reminder (reminderAgentManager timer) that fires
   * after the task interval, shows a notification and reopens the app when
   * tapped. The published id is stored so the trigger can be cancelled.
   */
  async scheduleTrigger(task: RoutineTask): Promise<void> {
    const action: string = this.actionForTask(task);
    const notificationId: number = this.requestCodeForTask(task);
    const triggerSeconds: number = Math.max(1, Math.floor(task.intervalMs / 1000));
    const request: reminderAgentManager.ReminderRequestTimer = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_TIMER,
      triggerTimeInSeconds: triggerSeconds,
      actionButton: [
        { title: 'Done', type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE }
      ],
      wantAgent: {
        pkgName: Constants.BUNDLE_NAME,
        abilityName: Constants.ENTRY_ABILITY,
        parameters: { 'action': action, 'taskId': task.id }
      },
      title: task.title,
      content: task.subtitle,
      expiredContent: `${task.title} reminder expired`,
      notificationId: notificationId,
      slotType: notificationManager.SlotType.SOCIAL_COMMUNICATION
    };
    try {
      // Replace any previous reminder for this task before re-publishing.
      await this.cancelStoredTaskReminder(task);
      const id: number = await reminderAgentManager.publishReminder(request);
      this.taskReminderIds.set(task.id, id);
      task.status = RoutineStatus.SCHEDULED;
      task.nextFireLabel = this.nextFireLabel(task.intervalMs);
      this.statusMessage = `${task.title} scheduled (id ${id})`;
      hilog.info(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s',
        `scheduleTrigger ok ${task.id} reminderId=${id} in ${triggerSeconds}s`);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      task.status = RoutineStatus.IDLE;
      task.enabled = false;
      this.statusMessage = `Schedule failed: ${task.title}`;
      hilog.error(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s',
        `scheduleTrigger failed ${task.id} code=${e.code} msg=${e.message}`);
    }
  }

  /** Cancel a task's published reminder and reset its status to IDLE. */
  async cancelTrigger(task: RoutineTask): Promise<void> {
    task.status = RoutineStatus.IDLE;
    task.nextFireLabel = '';
    await this.cancelStoredTaskReminder(task);
    hilog.info(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s',
      `cancelTrigger ${task.id}`);
  }

  /** Cancel + forget the reminder currently registered for a task (if any). */
  private async cancelStoredTaskReminder(task: RoutineTask): Promise<void> {
    const id: number | undefined = this.taskReminderIds.get(task.id);
    if (id === undefined) {
      return;
    }
    try {
      await reminderAgentManager.cancelReminder(id);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      hilog.error(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s',
        `cancelReminder failed task=${task.id} id=${id} code=${e.code}`);
    }
    this.taskReminderIds.delete(task.id);
  }

  /**
   * Publish the REAL deferred medication reminder as a daily alarm. When it fires
   * at the chosen hour:minute it shows a notification and — via its wantAgent /
   * maxScreenWantAgent — launches PillTrackerAbility. Re-scheduling cancels the
   * previous alarm first.
   */
  async scheduleDeferredReminder(): Promise<void> {
    const request: reminderAgentManager.ReminderRequestAlarm = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
      hour: this.reminder.triggerHour,
      minute: this.reminder.triggerMinute,
      daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
      actionButton: [
        { title: 'Taken', type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE },
        { title: 'Snooze', type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_SNOOZE }
      ],
      wantAgent: {
        pkgName: Constants.BUNDLE_NAME,
        abilityName: Constants.PILL_TRACKER_ABILITY,
        parameters: { 'action': Constants.ACTION_OPEN_PILL_TRACKER }
      },
      maxScreenWantAgent: {
        pkgName: Constants.BUNDLE_NAME,
        abilityName: Constants.PILL_TRACKER_ABILITY
      },
      title: this.reminder.label,
      content: 'Time to take your medication',
      expiredContent: 'Medication reminder expired',
      snoozeContent: 'Medication reminder snoozed',
      ringDuration: 10,
      snoozeTimes: 2,
      timeInterval: 5 * 60,
      notificationId: this.reminder.code,
      slotType: notificationManager.SlotType.SOCIAL_COMMUNICATION
    };
    try {
      await this.cancelDeferredReminder();
      const id: number = await reminderAgentManager.publishReminder(request);
      this.medicationReminderId = id;
      this.reminder.scheduled = true;
      this.statusMessage =
        `Medication set for ${this.formatClock(this.reminder.triggerHour, this.reminder.triggerMinute)}`;
      hilog.info(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s',
        `scheduleDeferredReminder ok id=${id} -> ${Constants.PILL_TRACKER_ABILITY}`);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      this.reminder.scheduled = false;
      this.statusMessage = 'Reminder scheduling failed';
      hilog.error(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s',
        `scheduleDeferredReminder failed code=${e.code} msg=${e.message}`);
    }
  }

  /** Cancel the medication alarm if one is currently published. */
  async cancelDeferredReminder(): Promise<void> {
    if (this.medicationReminderId < 0) {
      return;
    }
    try {
      await reminderAgentManager.cancelReminder(this.medicationReminderId);
      hilog.info(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s',
        `cancelDeferredReminder id=${this.medicationReminderId}`);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      hilog.error(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s',
        `cancelDeferredReminder failed id=${this.medicationReminderId} code=${e.code}`);
    }
    this.medicationReminderId = -1;
    this.reminder.scheduled = false;
  }

  /** Bump the reminder time by whole minutes, wrapping within a single day. */
  adjustReminderTime(deltaMinutes: number): void {
    let total: number = this.reminder.triggerHour * 60 + this.reminder.triggerMinute + deltaMinutes;
    const dayMinutes: number = 24 * 60;
    total = ((total % dayMinutes) + dayMinutes) % dayMinutes;
    this.reminder.triggerHour = Math.floor(total / 60);
    this.reminder.triggerMinute = total % 60;
    // Editing the time invalidates any live alarm — cancel it so the UI and the
    // system stay consistent; the user re-schedules with the new time.
    if (this.reminder.scheduled) {
      this.cancelDeferredReminder();
    }
    this.statusMessage =
      `Reminder time ${this.formatClock(this.reminder.triggerHour, this.reminder.triggerMinute)}`;
  }

  /** Return the first declared skill whose action + entities match the incoming intent. */
  matchIntent(action: string, entities: string[]): SkillIntent | undefined {
    for (const skill of this.skills) {
      if (skill.action !== action) {
        continue;
      }
      // Every requested entity must be declared by the skill.
      let entitiesOk: boolean = true;
      for (const entity of entities) {
        if (!skill.entities.includes(entity)) {
          entitiesOk = false;
          break;
        }
      }
      if (entitiesOk) {
        return skill;
      }
    }
    return undefined;
  }

  /**
   * Actively invoke a discovered skill by firing a genuine pending intent:
   * build a wantAgent WantAgentInfo (START_ABILITY with the skill's action +
   * entities), materialise it with getWantAgent, then trigger it with a
   * TriggerInfo. This really launches the skill's target ability.
   */
  async invokeSkill(skill: SkillIntent): Promise<void> {
    const code: number = skill.abilityName === Constants.PILL_TRACKER_ABILITY
      ? Constants.REQ_MEDICATION
      : Constants.REQ_WORKOUT;
    const want: Want = {
      bundleName: Constants.BUNDLE_NAME,
      abilityName: skill.abilityName,
      action: skill.action,
      entities: skill.entities,
      parameters: { 'source': 'skillInvoke' }
    };
    const info: wantAgent.WantAgentInfo = {
      wants: [want],
      operationType: wantAgent.OperationType.START_ABILITY,
      requestCode: code,
      wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    try {
      const agent: WantAgent = await wantAgent.getWantAgent(info);
      const triggerInfo: wantAgent.TriggerInfo = { code: code };
      wantAgent.trigger(agent, triggerInfo, (err: BusinessError, data: wantAgent.CompleteData) => {
        if (err && err.code) {
          hilog.error(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s',
            `invokeSkill trigger error ${skill.action} code=${err.code}`);
          return;
        }
        hilog.info(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s',
          `invokeSkill fired ${skill.action} finalCode=${data.finalCode}`);
      });
      // Reflect the invocation in the UI state.
      this.handleLaunchIntent(skill.action);
      this.statusMessage = `Invoked ${skill.label}`;
      hilog.info(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s',
        `invokeSkill ok ${skill.label} -> ${skill.abilityName}`);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      this.statusMessage = `Invoke failed: ${skill.label}`;
      hilog.error(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s',
        `invokeSkill failed ${skill.action} code=${e.code} msg=${e.message}`);
    }
  }

  /**
   * React to a launch intent forwarded from an ability (via AppStorage). A
   * START_WORKOUT match flips the workout task into TRIGGERED and records the
   * matched intent for the UI.
   */
  handleLaunchIntent(action: string | undefined): void {
    if (action === undefined || action.length === 0) {
      return;
    }
    const skill: SkillIntent | undefined = this.matchIntent(action, [Constants.ENTITY_HEALTH]);
    if (skill === undefined) {
      hilog.info(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s',
        `handleLaunchIntent: no skill for ${action}`);
      return;
    }
    this.lastMatchedIntent = skill.label;
    if (action === Constants.ACTION_START_WORKOUT) {
      const workout: RoutineTask | undefined = this.tasks.find(
        (t: RoutineTask) => t.type === RoutineType.WORKOUT);
      if (workout !== undefined) {
        workout.status = RoutineStatus.TRIGGERED;
        workout.nextFireLabel = 'Started';
      }
      this.statusMessage = 'Workout started by intent';
    } else {
      this.statusMessage = `Intent matched: ${skill.label}`;
    }
    hilog.info(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s',
      `handleLaunchIntent matched ${skill.label} (${action})`);
  }

  /** Mark all declared skills as discovered (simulates intent discovery). */
  discoverSkills(): void {
    this.skills = this.skills.map((s: SkillIntent) => {
      const copy: SkillIntent = {
        action: s.action,
        entities: s.entities,
        label: s.label,
        abilityName: s.abilityName,
        discovered: true
      };
      return copy;
    });
    this.statusMessage = `Discovered ${this.skills.length} skills`;
    hilog.info(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s',
      `discoverSkills: ${this.skills.length} marked discovered`);
  }

  /**
   * Check every declared permission via checkAccessTokenSync and refresh the
   * granted flag on each PermissionState row.
   */
  async checkPermissions(): Promise<void> {
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const info: bundleManager.BundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      const tokenId: number = info.appInfo.accessTokenId;
      const refreshed: PermissionState[] = this.permissions.map((row: PermissionState) => {
        let granted: boolean = false;
        try {
          const status: abilityAccessCtrl.GrantStatus =
            atManager.checkAccessTokenSync(tokenId, row.permission as Permissions);
          granted = status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
        } catch (err) {
          const e: BusinessError = err as BusinessError;
          hilog.error(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s',
            `checkAccessTokenSync failed ${row.permission} code=${e.code}`);
        }
        const copy: PermissionState = {
          permission: row.permission,
          label: row.label,
          granted: granted,
          userGrant: row.userGrant
        };
        return copy;
      });
      this.permissions = refreshed;
      const grantedCount: number = refreshed.filter((r: PermissionState) => r.granted).length;
      this.statusMessage = `Permissions ${grantedCount}/${refreshed.length} granted`;
      hilog.info(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s',
        `checkPermissions: ${grantedCount}/${refreshed.length} granted`);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      this.statusMessage = 'Permission check failed';
      hilog.error(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s',
        `checkPermissions failed code=${e.code} msg=${e.message}`);
    }
  }

  /**
   * Request the user_grant permission (ACTIVITY_MOTION) AND enable notifications
   * so reminders can actually surface. System_grant permissions must never be
   * passed to requestPermissionsFromUser. Refreshes states afterwards.
   */
  async requestPermissions(context: common.UIAbilityContext): Promise<void> {
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const result = await atManager.requestPermissionsFromUser(context, Constants.USER_GRANT_PERMISSIONS);
      const authResults: Array<number> = result.authResults;
      let grantedCount: number = 0;
      for (const code of authResults) {
        if (code === 0) {
          grantedCount++;
        }
      }
      // Also make sure notifications are allowed, so reminders are visible.
      await this.ensureNotificationsEnabled(context);
      this.statusMessage =
        `Granted ${grantedCount}/${authResults.length}; notifications ${this.notificationsEnabled ? 'on' : 'off'}`;
      hilog.info(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s',
        `requestPermissions: granted ${grantedCount}/${authResults.length}`);
      // Re-read the full permission table so the UI reflects the new grants.
      await this.checkPermissions();
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      this.statusMessage = 'Permission request failed';
      hilog.error(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s',
        `requestPermissions failed code=${e.code} msg=${e.message}`);
    }
  }

  /** Build the lightweight companion-service config (passes the pending reminder). */
  buildAtomicServiceOptions(): AtomicServiceOptions {
    const options: AtomicServiceOptions = {
      parameters: {
        'source': Constants.ENTRY_ABILITY,
        'action': Constants.ACTION_OPEN_PILL_TRACKER,
        'hour': this.reminder.triggerHour,
        'minute': this.reminder.triggerMinute
      }
    };
    return options;
  }

  /** Launch the Pill Tracker atomic service via the UIAbility context. */
  async openAtomicService(context: common.UIAbilityContext): Promise<void> {
    try {
      const options: AtomicServiceOptions = this.buildAtomicServiceOptions();
      await context.openAtomicService(Constants.ATOMIC_SERVICE_APP_ID, options);
      this.statusMessage = 'Atomic service opened';
      hilog.info(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s',
        `openAtomicService ok appId=${Constants.ATOMIC_SERVICE_APP_ID}`);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      this.statusMessage = 'Atomic service unavailable';
      hilog.error(Constants.LOG_DOMAIN, Constants.LOG_TAG, '%{public}s',
        `openAtomicService failed code=${e.code} msg=${e.message}`);
    }
  }

  // -------- Private helpers --------

  /** Map a task type to its declared action string. */
  private actionForTask(task: RoutineTask): string {
    switch (task.type) {
      case RoutineType.HYDRATION:
        return Constants.ACTION_HYDRATION;
      case RoutineType.SEDENTARY:
        return Constants.ACTION_SEDENTARY;
      case RoutineType.MEDICATION:
        return Constants.ACTION_MEDICATION;
      case RoutineType.WORKOUT:
        return Constants.ACTION_START_WORKOUT;
      default:
        return Constants.ACTION_HYDRATION;
    }
  }

  /** Map a task type to its distinct reminder/notification id. */
  private requestCodeForTask(task: RoutineTask): number {
    switch (task.type) {
      case RoutineType.HYDRATION:
        return Constants.REQ_HYDRATION;
      case RoutineType.SEDENTARY:
        return Constants.REQ_SEDENTARY;
      case RoutineType.MEDICATION:
        return Constants.REQ_MEDICATION;
      case RoutineType.WORKOUT:
        return Constants.REQ_WORKOUT;
      default:
        return Constants.REQ_HYDRATION;
    }
  }

  /** Human-readable "next fire" clock label = now + intervalMs. */
  private nextFireLabel(intervalMs: number): string {
    const target: Date = new Date(Date.now() + intervalMs);
    return this.formatClock(target.getHours(), target.getMinutes());
  }

  /** Zero-padded HH:MM formatter. */
  private formatClock(hour: number, minute: number): string {
    const hh: string = hour < 10 ? `0${hour}` : `${hour}`;
    const mm: string = minute < 10 ? `0${minute}` : `${minute}`;
    return `${hh}:${mm}`;
  }
}
