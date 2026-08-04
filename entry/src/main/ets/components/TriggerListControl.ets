import { RoutineTask, RoutineStatus, RoutineType } from '../model/RoutineModel';

/**
 * Scheduled-trigger list for the Smart Daily Routine Automator.
 *
 * TriggerListControl renders ONLY the hydration + sedentary tasks (the workout
 * task is driven by skill intent, not this list). Each task is rendered through
 * the private TriggerRow child via @ObjectLink so that per-item mutations
 * (enabled / status / nextFireLabel) re-render reliably.
 *
 * Layout-agnostic: the page (Index) owns the round-safe insets, so each row
 * simply fills the width of its already-inset column.
 */
@Component
export struct TriggerListControl {
  @Link tasks: RoutineTask[];
  onToggle: (task: RoutineTask) => void = () => {};

  /** Only hourly hydration + sedentary reminders belong in the trigger list. */
  private triggerTasks(): RoutineTask[] {
    return this.tasks.filter((t: RoutineTask): boolean =>
      t.type === RoutineType.HYDRATION || t.type === RoutineType.SEDENTARY);
  }

  build() {
    Column() {
      Text('Triggers')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 8 })

      ForEach(this.triggerTasks(), (item: RoutineTask) => {
        TriggerRow({
          task: item,
          onToggle: this.onToggle
        })
      }, (item: RoutineTask) => item.id)
    }
    .width('100%')
  }
}

/**
 * Single trigger row. Receives the task as @ObjectLink so mutations performed
 * by the viewmodel (via onToggle) propagate back into this row. NEVER reassign
 * the @ObjectLink field — only its properties are mutated upstream.
 */
@Component
struct TriggerRow {
  @ObjectLink task: RoutineTask;
  onToggle: (task: RoutineTask) => void = () => {};

  /** Human-readable status text for the current RoutineStatus. */
  private statusLabel(): string {
    switch (this.task.status) {
      case RoutineStatus.SCHEDULED:
        return 'Scheduled';
      case RoutineStatus.TRIGGERED:
        return 'Triggered';
      case RoutineStatus.COMPLETED:
        return 'Completed';
      case RoutineStatus.IDLE:
      default:
        return 'Idle';
    }
  }

  /** Secondary line: prefer the concrete next-fire label when scheduled. */
  private detailLabel(): string {
    if (this.task.enabled && this.task.nextFireLabel.length > 0) {
      return this.task.nextFireLabel;
    }
    return this.task.subtitle;
  }

  build() {
    Row() {
      // Accent glyph
      Text(this.task.icon)
        .fontSize(20)
        .width(30)
        .textAlign(TextAlign.Center)
        .margin({ right: 8 })

      // Title + detail + status
      Column() {
        Text(this.task.title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(this.detailLabel())
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 1 })

        Text(this.statusLabel())
          .fontSize(10)
          .fontColor(this.task.accentColor)
          .width('100%')
          .margin({ top: 1 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // Enable / disable switch -> viewmodel decides schedule vs cancel
      Toggle({ type: ToggleType.Switch, isOn: this.task.enabled })
        .selectedColor(this.task.accentColor)
        .width(40)
        .height(24)
        .margin({ left: 6 })
        .onChange((isOn: boolean) => {
          // The viewmodel flips task.enabled and (re)schedules/cancels.
          this.onToggle(this.task);
        })
    }
    .width('100%')
    .padding({ left: 10, right: 10, top: 8, bottom: 8 })
    .margin({ bottom: 6 })
    .borderRadius(16)
    .backgroundColor($r('app.color.card'))
    .alignItems(VerticalAlign.Center)
  }
}
