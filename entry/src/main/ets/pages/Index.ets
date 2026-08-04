import { RoutineViewModel } from '../viewmodel/RoutineViewModel';
import { RoutineTask, DeferredReminder, SkillIntent, WearScreen } from '../model/RoutineModel';
import { Constants } from '../model/Constants';
import { HeaderComponent } from '../components/HeaderComponent';
import { TriggerListControl } from '../components/TriggerListControl';
import { SkillIntentHandler } from '../components/SkillIntentHandler';
import { DeferredActionManager } from '../components/DeferredActionManager';
import { common } from '@kit.AbilityKit';

/**
 * Smart Daily Routine Automator — round-screen home page.
 *
 * MVVM host: owns the @State sources and forwards them to the feature
 * components. The RoutineViewModel performs all SDK work (real reminderAgent
 * reminders, skill intent invocation, permissions, notifications, atomic
 * service). The page mutates @State after each viewmodel call so the UI stays
 * in sync.
 *
 * Round-screen correctness: the root Stack is sized to the display diameter and
 * clipped to a circle (borderRadius = radius + clip); all content lives inside a
 * Scroll/Column padded by the page so nothing clips at the curved corners.
 */
@Entry
@Component
struct Index {
  private vm: RoutineViewModel = new RoutineViewModel();
  @State screen: WearScreen = this.vm.initScreen();
  @State tasks: RoutineTask[] = [];
  @State skills: SkillIntent[] = [];
  @State reminder: DeferredReminder = this.vm.reminder;
  @State statusMessage: string = '';
  @State lastMatched: string = '';

  aboutToAppear(): void {
    // 1) Resolve round-screen geometry.
    this.screen = this.vm.initScreen();

    // 2) Seed defaults from the factory (single source of seed data).
    this.vm.loadDefaults();
    this.tasks = this.vm.tasks;
    this.skills = this.vm.skills;
    this.reminder = this.vm.reminder;
    this.statusMessage = this.vm.statusMessage;

    // 3) Consume a launch intent passed from an ability via AppStorage.
    const launchAction: string | undefined =
      AppStorage.get<string>(Constants.STORAGE_LAUNCH_ACTION);
    this.vm.handleLaunchIntent(launchAction);
    this.lastMatched = this.vm.lastMatchedIntent;
    this.statusMessage = this.vm.statusMessage;

    // 4) Reflect current permission grants in the security panel.
    this.vm.checkPermissions();

    // 5) Best-effort: allow notifications so reminders can actually surface.
    //    (The Permissions button re-requests this if it is dismissed here.)
    const notifyCtx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.vm.ensureNotificationsEnabled(notifyCtx);
  }

  /** Pull the freshest viewmodel state back into the page after a mutation. */
  private syncFromVm(): void {
    // Reassign arrays to force list re-evaluation; @ObjectLink handles per-item.
    this.tasks = this.vm.tasks.slice();
    this.skills = this.vm.skills.slice();
    this.reminder = this.vm.reminder;
    this.statusMessage = this.vm.statusMessage;
    this.lastMatched = this.vm.lastMatchedIntent;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Scroll() {
        Column({ space: 12 }) {
          HeaderComponent({
            title: 'Routine Automator',
            statusText: this.statusMessage
          })

          TriggerListControl({
            tasks: $tasks,
            onToggle: (task: RoutineTask): void => {
              this.vm.toggleTask(task).then((): void => {
                this.syncFromVm();
              });
            }
          })

          SkillIntentHandler({
            skills: this.skills,
            lastMatched: this.lastMatched,
            onDiscover: (): void => {
              this.vm.discoverSkills();
              this.syncFromVm();
            },
            onInvoke: (skill: SkillIntent): void => {
              this.vm.invokeSkill(skill).then((): void => {
                this.syncFromVm();
              });
            }
          })

          DeferredActionManager({
            reminder: this.reminder,
            onSchedule: (): void => {
              this.vm.scheduleDeferredReminder().then((): void => {
                this.syncFromVm();
              });
            },
            onAdjust: (deltaMinutes: number): void => {
              this.vm.adjustReminderTime(deltaMinutes);
              this.syncFromVm();
            }
          })

          this.FooterRow()
        }
        .width('100%')
        // Single round-safe inset owned by the page: a modest horizontal margin
        // keeps card text readable, while a larger top/bottom inset clears the
        // narrow poles of the circle. Child components add NO horizontal padding.
        .padding({
          left: this.screen.diameterVp * 0.05,
          right: this.screen.diameterVp * 0.05,
          top: this.screen.safeInsetVp,
          bottom: this.screen.safeInsetVp
        })
        .constraintSize({ minHeight: this.screen.diameterVp })
        .justifyContent(FlexAlign.Start)
      }
      .width(this.screen.diameterVp)
      .height(this.screen.diameterVp)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width(this.screen.diameterVp)
    .height(this.screen.diameterVp)
    .backgroundColor($r('app.color.bg_page'))
    // A square sized to the diameter with corner radius = half its side is a
    // perfect circle; clip(true) is the non-deprecated circular clip.
    .borderRadius(this.screen.radiusVp)
    .clip(true)
  }

  /** Footer: security (permissions) + lightweight atomic-service demo. */
  @Builder
  FooterRow() {
    Row({ space: 10 }) {
      Button('Permissions')
        .fontSize(11)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor($r('app.color.accent'))
        .layoutWeight(1)
        .height(38)
        .onClick((): void => {
          const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
          this.vm.requestPermissions(ctx).then((): void => {
            this.syncFromVm();
          });
        })

      Button('Companion')
        .fontSize(11)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor($r('app.color.medication'))
        .layoutWeight(1)
        .height(38)
        .onClick((): void => {
          const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
          this.vm.openAtomicService(ctx).then((): void => {
            this.syncFromVm();
          });
        })
    }
    .width('100%')
    .margin({ top: 4 })
  }
}
