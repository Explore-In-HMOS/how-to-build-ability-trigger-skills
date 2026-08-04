import { SkillIntent } from '../model/RoutineModel';

/**
 * SkillIntentHandler — Skill-based intent discovery panel.
 *
 * Lists the intents declared in module.json5 (mirrored via RoutineFactory),
 * offers a Discover action that marks every skill as discovered, and an
 * Invoke button per skill (e.g. Start Workout) that routes back through the
 * viewmodel's handleLaunchIntent. Round-safe: horizontal padding is the
 * caller-supplied corner inset so nothing clips on the curved display.
 */
@Component
export struct SkillIntentHandler {
  @Prop skills: SkillIntent[];
  @Prop lastMatched: string;
  onDiscover: () => void = () => {};
  onInvoke: (skill: SkillIntent) => void = () => {};

  @Builder
  skillCard(skill: SkillIntent) {
    Column() {
      // Title row: label + discovered checkmark
      Row() {
        Text(skill.label)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(skill.discovered ? '✓' : '○')
          .fontSize(14)
          .fontColor(skill.discovered ? $r('app.color.accent') : $r('app.color.text_secondary'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // Invoke button
      Button(`Invoke ${skill.label}`)
        .fontSize(12)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor($r('app.color.accent'))
        .height(30)
        .width('100%')
        .margin({ top: 8 })
        .onClick(() => {
          this.onInvoke(skill);
        })
    }
    .width('100%')
    .padding(10)
    .borderRadius(14)
    .backgroundColor($r('app.color.card'))
    .margin({ top: 8 })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      // Section title
      Text('Skills')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .textAlign(TextAlign.Center)

      // Declared intents
      ForEach(this.skills, (skill: SkillIntent) => {
        this.skillCard(skill);
      }, (skill: SkillIntent) => skill.action)

      // Discover all
      Button('Discover Skills')
        .fontSize(13)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor($r('app.color.workout'))
        .height(32)
        .width('100%')
        .margin({ top: 10 })
        .onClick(() => {
          this.onDiscover();
        })

      // Last matched intent result
      Text(this.lastMatched.length > 0 ? `Matched: ${this.lastMatched}` : 'No intent matched yet')
        .fontSize(11)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 8 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
