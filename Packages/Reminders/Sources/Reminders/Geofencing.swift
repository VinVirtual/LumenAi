import Combine
import Core
import CoreLocation
import Foundation

/// Manages geofences for location-based reminders. When a reminder has a
/// location and an `Always` location authorization is granted, this service
/// registers a `CLCircularRegion` and posts a notification on entry.
public final class Geofencing: NSObject, CLLocationManagerDelegate, ObservableObject {
    public static let shared = Geofencing()

    private let manager = CLLocationManager()

    override public init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.allowsBackgroundLocationUpdates = false
        manager.pausesLocationUpdatesAutomatically = true
    }

    public func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    public func sync(_ reminders: [Reminder]) {
        let regions = reminders.compactMap(region(for:))
        let known = manager.monitoredRegions
        for region in known where !regions.contains(where: { $0.identifier == region.identifier }) {
            manager.stopMonitoring(for: region)
        }
        for region in regions where !known.contains(where: { $0.identifier == region.identifier }) {
            manager.startMonitoring(for: region)
        }
    }

    private func region(for reminder: Reminder) -> CLCircularRegion? {
        guard
            let lat = reminder.metadata["lat"]?.value as? Double,
            let lon = reminder.metadata["lon"]?.value as? Double
        else { return nil }
        let radius = CLLocationDistance(reminder.geofenceRadius ?? 150)
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            radius: radius,
            identifier: reminder.id.uuidString
        )
        region.notifyOnEntry = true
        region.notifyOnExit = false
        return region
    }

    public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        NotificationCenter.default.post(
            name: .lumenReminderGeofenceEntered,
            object: nil,
            userInfo: ["reminder_id": region.identifier]
        )
    }
}

public extension Notification.Name {
    static let lumenReminderGeofenceEntered = Notification.Name("lumen.reminder.geofence.entered")
}
