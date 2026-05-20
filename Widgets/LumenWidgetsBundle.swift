import SwiftUI
import WidgetKit

@main
struct LumenWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NextReminderWidget()
        PinnedNoteWidget()
        QuickAddWidget()
        StreakWidget()
        ReminderLiveActivityWidget()
        LumenPinLiveActivity()
        FocusLiveActivity()
    }
}
