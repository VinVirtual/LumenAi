import Foundation

public extension Notification.Name {
    /// Posted when a reminder's status changes off-device (widget intent,
    /// etc.) so `RemindersService` can cancel pending local notifications.
    static let lumenReminderResolved = Notification.Name("lumen.reminder.resolved")

    /// Posted by the tab-bar `+` on the Money tab to open the add-expense
    /// sheet in `MoneyHomeView`.
    static let lumenOpenAddExpense = Notification.Name("lumen.money.add")
}
