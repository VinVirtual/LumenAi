import Foundation
import os

public enum LumenLog {
    public static let app = Logger(subsystem: subsystem, category: "app")
    public static let auth = Logger(subsystem: subsystem, category: "auth")
    public static let sync = Logger(subsystem: subsystem, category: "sync")
    public static let ai = Logger(subsystem: subsystem, category: "ai")
    public static let widgets = Logger(subsystem: subsystem, category: "widgets")
    public static let notifications = Logger(subsystem: subsystem, category: "notifications")

    private static let subsystem: String = Bundle.main.bundleIdentifier ?? "app.lumen"
}
