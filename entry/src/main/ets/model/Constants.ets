import { Permissions } from '@kit.AbilityKit';

/**
 * Central, immutable configuration for the Smart Daily Routine Automator.
 * Every action string, ability name, permission and tuning value lives here so
 * that abilities, viewmodel, components and module.json5 stay in lock-step.
 */
export class Constants {
  // -------- Bundle / module / ability identifiers --------
  static readonly BUNDLE_NAME: string = 'com.hmosdemos.wearable.how_to_build_ability_triggers_skills';
  static readonly MODULE_NAME: string = 'entry';
  static readonly ENTRY_ABILITY: string = 'EntryAbility';
  static readonly PILL_TRACKER_ABILITY: string = 'PillTrackerAbility';

  // -------- Custom action strings (namespaced under the bundle) --------
  static readonly ACTION_START_WORKOUT: string =
    'com.hmosdemos.wearable.how_to_build_ability_triggers_skills.action.START_WORKOUT';
  static readonly ACTION_HYDRATION: string =
    'com.hmosdemos.wearable.how_to_build_ability_triggers_skills.action.HYDRATION';
  static readonly ACTION_SEDENTARY: string =
    'com.hmosdemos.wearable.how_to_build_ability_triggers_skills.action.SEDENTARY';
  static readonly ACTION_MEDICATION: string =
    'com.hmosdemos.wearable.how_to_build_ability_triggers_skills.action.MEDICATION';
  static readonly ACTION_OPEN_PILL_TRACKER: string =
    'com.hmosdemos.wearable.how_to_build_ability_triggers_skills.action.OPEN_PILL_TRACKER';

  // -------- Skill entities --------
  static readonly ENTITY_HEALTH: string = 'entity.system.health';
  static readonly ENTITY_HOME: string = 'entity.system.home';

  // -------- Permission strings --------
  static readonly PERM_VIBRATE: Permissions = 'ohos.permission.VIBRATE';
  static readonly PERM_PUBLISH_REMINDER: Permissions = 'ohos.permission.PUBLISH_AGENT_REMINDER';
  static readonly PERM_KEEP_BACKGROUND: Permissions = 'ohos.permission.KEEP_BACKGROUND_RUNNING';
  static readonly PERM_ACTIVITY_MOTION: Permissions = 'ohos.permission.ACTIVITY_MOTION';

  /** Only user_grant permissions may be passed to requestPermissionsFromUser. */
  static readonly USER_GRANT_PERMISSIONS: Permissions[] = [Constants.PERM_ACTIVITY_MOTION];
  /** Every permission the app declares; safe to CHECK, not all safe to REQUEST. */
  static readonly ALL_PERMISSIONS: Permissions[] = [
    Constants.PERM_VIBRATE,
    Constants.PERM_PUBLISH_REMINDER,
    Constants.PERM_KEEP_BACKGROUND,
    Constants.PERM_ACTIVITY_MOTION
  ];

  // -------- WantAgent request codes (must be distinct) --------
  static readonly REQ_HYDRATION: number = 1001;
  static readonly REQ_SEDENTARY: number = 1002;
  static readonly REQ_MEDICATION: number = 1003;
  static readonly REQ_WORKOUT: number = 1004;

  // -------- Timing --------
  static readonly HYDRATION_INTERVAL_MS: number = 60 * 60 * 1000;
  static readonly SEDENTARY_INTERVAL_MS: number = 45 * 60 * 1000;
  static readonly DEFAULT_MED_HOUR: number = 9;
  static readonly DEFAULT_MED_MINUTE: number = 0;

  // -------- Round-screen defaults / fallback --------
  // Used only if display.getDefaultDisplaySync() fails.
  // Round Huawei Watch 5 is ~466x466 px.
  // safeInsetVp = radiusVp * (1 - Math.SQRT1_2)  (~0.293 * radius).
  static readonly FALLBACK_DIAMETER_PX: number = 466;
  // Fallback logical density (px per vp), used only if the display query fails.
  static readonly FALLBACK_DENSITY_PIXELS: number = 2;

  // -------- Atomic service (lightweight companion) --------
  static readonly ATOMIC_SERVICE_APP_ID: string = 'com.hmosdemos.wearable.pilltracker.atomic';

  // -------- Logging --------
  static readonly LOG_DOMAIN: number = 0x0001;
  static readonly LOG_TAG: string = 'RoutineAutomator';

  // -------- Shared resource string KEYS (resources + module.json5) --------
  static readonly REASON_ACTIVITY_MOTION_KEY: string = 'reason_activity_motion';
  static readonly PILL_TRACKER_LABEL_KEY: string = 'PillTrackerAbility_label';
  static readonly PILL_TRACKER_DESC_KEY: string = 'PillTrackerAbility_desc';

  // -------- AppStorage keys --------
  static readonly STORAGE_LAUNCH_ACTION: string = 'launchAction';
}
