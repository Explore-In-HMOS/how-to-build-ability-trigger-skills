/**
 * HeaderComponent — the top-arc header of the round wearable UI.
 * Shows a live HH:MM clock, the app title and a colored status pill.
 * Layout-agnostic: the page (Index) owns the round-safe insets, so this
 * component simply fills the width it is given and centers its content.
 */
@Component
export struct HeaderComponent {
  @Prop title: string;
  @Prop statusText: string;
  /** Local live clock string, refreshed every second. */
  @State private clock: string = '';
  /** setInterval handle so we can clear it on disappear. */
  private timerId: number = -1;

  aboutToAppear(): void {
    this.clock = this.formatNow();
    this.timerId = setInterval(() => {
      this.clock = this.formatNow();
    }, 1000);
  }

  aboutToDisappear(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  /** Current wall-clock time as zero-padded HH:MM. */
  private date: Date = new Date();

  private formatNow(): string {
    this.date.setTime(Date.now());
    const hh: string = this.pad2(this.date.getHours());
    const mm: string = this.pad2(this.date.getMinutes());
    return `${hh}:${mm}`;
  }

  private pad2(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  build() {
    Column({ space: 2 }) {
      // Live clock — the visual anchor of the top arc.
      Text(this.clock)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .textAlign(TextAlign.Center)
        .maxLines(1)

      // App title.
      Text(this.title)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#8E8E93')
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      // Status pill — reflects the latest viewmodel statusMessage.
      Text(this.statusText.length > 0 ? this.statusText : 'Ready')
        .fontSize(11)
        .fontColor('#FFFFFF')
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .backgroundColor('#0A84FF')
        .borderRadius(10)
        .padding({ left: 10, right: 10, top: 3, bottom: 3 })
        .margin({ top: 2 })
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
    .alignItems(HorizontalAlign.Center)
  }
}
