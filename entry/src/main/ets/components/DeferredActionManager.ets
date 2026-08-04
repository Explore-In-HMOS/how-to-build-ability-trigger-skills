import { DeferredReminder } from '../model/RoutineModel';

/**
 * DeferredActionManager
 * Medication deferred-action card. Renders the single @Observed DeferredReminder,
 * its target ability (Pill Tracker), the ACTION_OPEN_PILL_TRACKER intent, and an
 * HH:MM time built from reminder.triggerHour/triggerMinute with +/- steppers.
 * A Schedule button hands off to onSchedule(); reactivity flows via @ObjectLink so
 * mutating reminder.triggerHour/triggerMinute/scheduled in the parent re-renders here.
 * Round-safe: horizontal padding is screen.safeInsetVp so nothing clips at the arc.
 */
@Component
export struct DeferredActionManager {
  @ObjectLink reminder: DeferredReminder;
  onSchedule: () => void = () => {};
  onAdjust: (deltaMinutes: number) => void = () => {};

  /** Zero-pad a clock component to two digits. */
  private pad(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  /** HH:MM label from the observed reminder time. */
  private timeLabel(): string {
    return `${this.pad(this.reminder.triggerHour)}:${this.pad(this.reminder.triggerMinute)}`;
  }

  @Builder
  stepButton(glyph: string, deltaMinutes: number) {
    Button(glyph)
      .type(ButtonType.Circle)
      .width(34)
      .height(34)
      .fontSize(18)
      .fontColor($r('app.color.text_primary'))
      .backgroundColor($r('app.color.medication'))
      .onClick(() => {
        this.onAdjust(deltaMinutes);
      })
  }

  build() {
    Column({ space: 8 }) {
      // Card header: title + target ability
      Row({ space: 6 }) {
        Text('💊')
          .fontSize(18)
        Text(this.reminder.label)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')

      Text('Launches Pill Tracker')
        .fontSize(11)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      // Time stepper: -1h  -5m  HH:MM  +5m  +1h
      Row() {
        this.stepButton('−', -60)
        Column() {
          Text(this.timeLabel())
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textAlign(TextAlign.Center)
            .width('100%')
          Text('deferred at')
            .fontSize(9)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
        }
        .layoutWeight(1)
        this.stepButton('+', 60)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)

      // Fine minute steppers
      Row({ space: 12 }) {
        Button('−5m')
          .type(ButtonType.Capsule)
          .height(28)
          .fontSize(12)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.bg_page'))
          .borderWidth(1)
          .borderColor($r('app.color.medication'))
          .layoutWeight(1)
          .onClick(() => {
            this.onAdjust(-5);
          })
        Button('+5m')
          .type(ButtonType.Capsule)
          .height(28)
          .fontSize(12)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.bg_page'))
          .borderWidth(1)
          .borderColor($r('app.color.medication'))
          .layoutWeight(1)
          .onClick(() => {
            this.onAdjust(5);
          })
      }
      .width('100%')

      // Schedule action + status
      Button(this.reminder.scheduled ? 'Reschedule' : 'Schedule')
        .type(ButtonType.Capsule)
        .width('100%')
        .height(36)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor($r('app.color.medication'))
        .onClick(() => {
          this.onSchedule();
        })

      Row({ space: 6 }) {
        Circle({ width: 8, height: 8 })
          .fill(this.reminder.scheduled ? $r('app.color.medication') : $r('app.color.text_secondary'))
        Text(this.reminder.scheduled ? 'Agent scheduled (one-time)' : 'Idle - not scheduled')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({
      left: 14,
      right: 14,
      top: 12,
      bottom: 12
    })
    .borderRadius(18)
    .backgroundColor($r('app.color.card'))
  }
}
