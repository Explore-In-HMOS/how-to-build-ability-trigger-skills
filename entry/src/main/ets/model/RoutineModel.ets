import { Constants } from './Constants';

/**
 * Domain model for the Smart Daily Routine Automator.
 * Plain data module (no UI). @Observed classes drive per-item reactivity when
 * rendered through @ObjectLink children; interfaces describe read-only snapshots.
 */

// -------- Enums --------
export enum RoutineType {
  HYDRATION,
  SEDENTARY,
  MEDICATION,
  WORKOUT
}

export enum RoutineStatus {
  IDLE,
  SCHEDULED,
  TRIGGERED,
  COMPLETED
}

// -------- Observed classes (deep, per-item reactivity) --------
@Observed
export class RoutineTask {
  id: string;
  type: RoutineType;
  title: string;
  subtitle: string;
  enabled: boolean;
  intervalMs: number;
  status: RoutineStatus;
  nextFireLabel: string;
  accentColor: string;
  /** Emoji / glyph string so no binary media is required. */
  icon: string;

  constructor(
    id: string,
    type: RoutineType,
    title: string,
    subtitle: string,
    enabled: boolean,
    intervalMs: number,
    status: RoutineStatus,
    nextFireLabel: string,
    accentColor: string,
    icon: string
  ) {
    this.id = id;
    this.type = type;
    this.title = title;
    this.subtitle = subtitle;
    this.enabled = enabled;
    this.intervalMs = intervalMs;
    this.status = status;
    this.nextFireLabel = nextFireLabel;
    this.accentColor = accentColor;
    this.icon = icon;
  }
}

@Observed
export class DeferredReminder {
  code: number;
  label: string;
  targetAbility: string;
  action: string;
  triggerHour: number;
  triggerMinute: number;
  scheduled: boolean;

  constructor(
    code: number,
    label: string,
    targetAbility: string,
    action: string,
    triggerHour: number,
    triggerMinute: number,
    scheduled: boolean
  ) {
    this.code = code;
    this.label = label;
    this.targetAbility = targetAbility;
    this.action = action;
    this.triggerHour = triggerHour;
    this.triggerMinute = triggerMinute;
    this.scheduled = scheduled;
  }
}

// -------- Interfaces (read-only snapshots) --------
export interface SkillIntent {
  action: string;
  entities: string[];
  label: string;
  abilityName: string;
  discovered: boolean;
}

export interface WearScreen {
  widthPx: number;
  heightPx: number;
  diameterVp: number;
  radiusVp: number;
  safeInsetVp: number;
  centerXVp: number;
  centerYVp: number;
  isRound: boolean;
}

export interface PermissionState {
  permission: string;
  label: string;
  granted: boolean;
  userGrant: boolean;
}

// -------- Factory (single home for all default seed data) --------
export class RoutineFactory {
  /** Two scheduled-trigger tasks + workout + medication seeds. */
  static makeDefaults(): RoutineTask[] {
    return [
      new RoutineTask(
        'task_hydration',
        RoutineType.HYDRATION,
        'Hydration',
        'Sip water every hour',
        false,
        Constants.HYDRATION_INTERVAL_MS,
        RoutineStatus.IDLE,
        '',
        '#0A84FF',
        '💧'
      ),
      new RoutineTask(
        'task_sedentary',
        RoutineType.SEDENTARY,
        'Move Alert',
        'Stand up every 45 min',
        false,
        Constants.SEDENTARY_INTERVAL_MS,
        RoutineStatus.IDLE,
        '',
        '#FF9F0A',
        '🚶'
      ),
      new RoutineTask(
        'task_workout',
        RoutineType.WORKOUT,
        'Workout',
        'Triggered by START_WORKOUT',
        false,
        0,
        RoutineStatus.IDLE,
        '',
        '#30D158',
        '🏃'
      )
    ];
  }

  /** Declared skills mirrored from module.json5. */
  static defaultSkills(): SkillIntent[] {
    return [
      {
        action: Constants.ACTION_START_WORKOUT,
        entities: [Constants.ENTITY_HEALTH],
        label: 'Start Workout',
        abilityName: Constants.ENTRY_ABILITY,
        discovered: false
      },
      {
        action: Constants.ACTION_OPEN_PILL_TRACKER,
        entities: [Constants.ENTITY_HEALTH],
        label: 'Open Pill Tracker',
        abilityName: Constants.PILL_TRACKER_ABILITY,
        discovered: false
      }
    ];
  }

  /** Single medication deferred reminder. */
  static defaultReminder(): DeferredReminder {
    return new DeferredReminder(
      Constants.REQ_MEDICATION,
      'Medication',
      Constants.PILL_TRACKER_ABILITY,
      Constants.ACTION_OPEN_PILL_TRACKER,
      Constants.DEFAULT_MED_HOUR,
      Constants.DEFAULT_MED_MINUTE,
      false
    );
  }

  /** Permission rows for the security panel; userGrant flags what may be requested. */
  static defaultPermissions(): PermissionState[] {
    return [
      { permission: Constants.PERM_ACTIVITY_MOTION, label: 'Activity Motion', granted: false, userGrant: true },
      { permission: Constants.PERM_VIBRATE, label: 'Vibrate', granted: false, userGrant: false },
      { permission: Constants.PERM_PUBLISH_REMINDER, label: 'Publish Reminder', granted: false, userGrant: false },
      { permission: Constants.PERM_KEEP_BACKGROUND, label: 'Keep Background', granted: false, userGrant: false }
    ];
  }
}
