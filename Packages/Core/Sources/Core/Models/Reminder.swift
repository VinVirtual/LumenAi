import Foundation
import SwiftData

public enum ReminderSource: String, Codable, Sendable {
    case manual, ai, imported
}

public enum ReminderStatus: String, Codable, Sendable {
    case active, done, snoozed, escalated, cancelled
}

/// What flavour of "thing to remember" a row represents. The same table
/// (and the same SwiftData entity) backs all three so the home tab can show
/// them side by side; UI distinguishes by `kind`.
public enum ReminderKind: String, Codable, CaseIterable, Sendable {
    /// Short text the user wants to keep in front of them. Doesn't ring.
    case note
    /// Has a `dueAt` and fires a notification at that time.
    case reminder
    /// To-do item with optional `dueAt`; renders with a checkbox.
    case task
}

/// Optional "do this when the notification fires" action attached to a
/// reminder. iOS sandbox rules prevent automatic message sending, so the
/// pattern is: at fire time the user gets a notification button that deep
/// links into the target app with text prefilled.
public enum ReminderActionKind: String, Codable, CaseIterable, Sendable {
    case whatsapp, sms, email, tel
}

/// Local SwiftData model. Mirrored to the `Reminder` Codable struct for sync.
@Model
public final class ReminderEntity {
    @Attribute(.unique) public var id: UUID
    public var ownerID: UUID
    public var title: String
    public var body: String?
    public var dueAt: Date?
    public var timezone: String?
    public var locationName: String?
    public var latitude: Double?
    public var longitude: Double?
    public var geofenceRadius: Int?
    public var recurrenceJSON: String?
    public var priority: Int
    public var urgency: Int
    public var sourceRaw: String
    public var statusRaw: String
    public var completedAt: Date?
    public var metadataJSON: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var pendingSync: Bool
    public var kindRaw: String = ReminderKind.reminder.rawValue
    public var isPinned: Bool = false
    public var externalID: String?
    /// Raw value of `ReminderActionKind`, or nil if the reminder has no action.
    public var actionKindRaw: String?
    /// JSON-encoded `[String: String]` payload (phone/text/email/etc.).
    public var actionPayloadJSON: String?

    public init(
        id: UUID = UUID(),
        ownerID: UUID,
        title: String,
        body: String? = nil,
        dueAt: Date? = nil,
        timezone: String? = TimeZone.current.identifier,
        locationName: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        geofenceRadius: Int? = nil,
        recurrenceJSON: String? = nil,
        priority: Int = 0,
        urgency: Int = 0,
        source: ReminderSource = .manual,
        status: ReminderStatus = .active,
        completedAt: Date? = nil,
        metadataJSON: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        pendingSync: Bool = true,
        kind: ReminderKind = .reminder,
        isPinned: Bool = false,
        externalID: String? = nil,
        actionKind: ReminderActionKind? = nil,
        actionPayload: [String: String]? = nil
    ) {
        self.id = id
        self.ownerID = ownerID
        self.title = title
        self.body = body
        self.dueAt = dueAt
        self.timezone = timezone
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
        self.geofenceRadius = geofenceRadius
        self.recurrenceJSON = recurrenceJSON
        self.priority = priority
        self.urgency = urgency
        sourceRaw = source.rawValue
        statusRaw = status.rawValue
        self.completedAt = completedAt
        self.metadataJSON = metadataJSON
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.pendingSync = pendingSync
        kindRaw = kind.rawValue
        self.isPinned = isPinned
        self.externalID = externalID
        actionKindRaw = actionKind?.rawValue
        if let payload = actionPayload,
           let data = try? JSONEncoder().encode(payload),
           let json = String(data: data, encoding: .utf8) {
            actionPayloadJSON = json
        } else {
            actionPayloadJSON = nil
        }
    }

    public var actionKind: ReminderActionKind? {
        get { actionKindRaw.flatMap(ReminderActionKind.init(rawValue:)) }
        set { actionKindRaw = newValue?.rawValue }
    }

    public var actionPayload: [String: String]? {
        get {
            guard let json = actionPayloadJSON, let data = json.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode([String: String].self, from: data)
        }
        set {
            if let payload = newValue,
               let data = try? JSONEncoder().encode(payload),
               let json = String(data: data, encoding: .utf8) {
                actionPayloadJSON = json
            } else {
                actionPayloadJSON = nil
            }
        }
    }

    public var kind: ReminderKind {
        get { ReminderKind(rawValue: kindRaw) ?? .reminder }
        set { kindRaw = newValue.rawValue }
    }

    public var source: ReminderSource {
        get { ReminderSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    public var status: ReminderStatus {
        get { ReminderStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }
}

/// Codable mirror of `ReminderEntity` for Supabase round-tripping.
public struct Reminder: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let ownerID: UUID
    public var title: String
    public var body: String?
    public var dueAt: Date?
    public var timezone: String?
    public var locationName: String?
    public var geofenceRadius: Int?
    public var recurrence: Recurrence?
    public var priority: Int
    public var urgency: Int
    public var source: ReminderSource
    public var status: ReminderStatus
    public var completedAt: Date?
    public var metadata: [String: AnyCodable]
    public var createdAt: Date
    public var updatedAt: Date
    public var kind: ReminderKind = .reminder
    public var isPinned: Bool = false
    public var externalID: String?
    public var actionKind: ReminderActionKind?
    public var actionPayload: [String: String]?

    public struct Recurrence: Codable, Hashable, Sendable {
        public var freq: Frequency
        public var interval: Int
        public var byDay: [String]?
        public var until: Date?

        public enum Frequency: String, Codable, Sendable {
            case daily, weekly, monthly, custom
        }

        public init(freq: Frequency, interval: Int = 1, byDay: [String]? = nil, until: Date? = nil) {
            self.freq = freq
            self.interval = interval
            self.byDay = byDay
            self.until = until
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case title, body
        case dueAt = "due_at"
        case timezone
        case locationName = "location_name"
        case geofenceRadius = "geofence_radius_m"
        case recurrence
        case priority, urgency, source, status
        case completedAt = "completed_at"
        case metadata
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case kind
        case isPinned = "is_pinned"
        case externalID = "external_id"
        case actionKind = "action_kind"
        case actionPayload = "action_payload"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        ownerID = try c.decode(UUID.self, forKey: .ownerID)
        title = try c.decode(String.self, forKey: .title)
        body = try c.decodeIfPresent(String.self, forKey: .body)
        dueAt = try c.decodeIfPresent(Date.self, forKey: .dueAt)
        timezone = try c.decodeIfPresent(String.self, forKey: .timezone)
        locationName = try c.decodeIfPresent(String.self, forKey: .locationName)
        geofenceRadius = try c.decodeIfPresent(Int.self, forKey: .geofenceRadius)
        recurrence = try c.decodeIfPresent(Recurrence.self, forKey: .recurrence)
        priority = try c.decode(Int.self, forKey: .priority)
        urgency = try c.decodeIfPresent(Int.self, forKey: .urgency) ?? 0
        source = try c.decode(ReminderSource.self, forKey: .source)
        status = try c.decode(ReminderStatus.self, forKey: .status)
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        metadata = try c.decodeIfPresent([String: AnyCodable].self, forKey: .metadata) ?? [:]
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        kind = try c.decodeIfPresent(ReminderKind.self, forKey: .kind) ?? .reminder
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        externalID = try c.decodeIfPresent(String.self, forKey: .externalID)
        actionKind = try c.decodeIfPresent(ReminderActionKind.self, forKey: .actionKind)
        actionPayload = try c.decodeIfPresent([String: String].self, forKey: .actionPayload)
    }

    public init(
        id: UUID,
        ownerID: UUID,
        title: String,
        body: String? = nil,
        dueAt: Date? = nil,
        timezone: String? = nil,
        locationName: String? = nil,
        geofenceRadius: Int? = nil,
        recurrence: Recurrence? = nil,
        priority: Int = 0,
        urgency: Int = 0,
        source: ReminderSource = .manual,
        status: ReminderStatus = .active,
        completedAt: Date? = nil,
        metadata: [String: AnyCodable] = [:],
        createdAt: Date = .now,
        updatedAt: Date = .now,
        kind: ReminderKind = .reminder,
        isPinned: Bool = false,
        externalID: String? = nil,
        actionKind: ReminderActionKind? = nil,
        actionPayload: [String: String]? = nil
    ) {
        self.id = id
        self.ownerID = ownerID
        self.title = title
        self.body = body
        self.dueAt = dueAt
        self.timezone = timezone
        self.locationName = locationName
        self.geofenceRadius = geofenceRadius
        self.recurrence = recurrence
        self.priority = priority
        self.urgency = urgency
        self.source = source
        self.status = status
        self.completedAt = completedAt
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.kind = kind
        self.isPinned = isPinned
        self.externalID = externalID
        self.actionKind = actionKind
        self.actionPayload = actionPayload
    }
}

public extension ReminderEntity {
    func snapshot() -> Reminder {
        let recurrence: Reminder.Recurrence? = {
            guard let json = recurrenceJSON, let data = json.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(Reminder.Recurrence.self, from: data)
        }()
        let metadata: [String: AnyCodable] = {
            guard let json = metadataJSON, let data = json.data(using: .utf8) else { return [:] }
            return (try? JSONDecoder().decode([String: AnyCodable].self, from: data)) ?? [:]
        }()
        return Reminder(
            id: id,
            ownerID: ownerID,
            title: title,
            body: body,
            dueAt: dueAt,
            timezone: timezone,
            locationName: locationName,
            geofenceRadius: geofenceRadius,
            recurrence: recurrence,
            priority: priority,
            urgency: urgency,
            source: source,
            status: status,
            completedAt: completedAt,
            metadata: metadata,
            createdAt: createdAt,
            updatedAt: updatedAt,
            kind: kind,
            isPinned: isPinned,
            externalID: externalID,
            actionKind: actionKind,
            actionPayload: actionPayload
        )
    }

    func apply(_ remote: Reminder) {
        guard remote.updatedAt > updatedAt else { return }
        title = remote.title
        body = remote.body
        dueAt = remote.dueAt
        timezone = remote.timezone
        locationName = remote.locationName
        geofenceRadius = remote.geofenceRadius
        recurrenceJSON = remote.recurrence.flatMap { (try? JSONEncoder().encode($0))
            .flatMap { String(data: $0, encoding: .utf8) }
        }
        priority = remote.priority
        urgency = remote.urgency
        source = remote.source
        status = remote.status
        completedAt = remote.completedAt
        metadataJSON = (try? JSONEncoder().encode(remote.metadata))
            .flatMap { String(data: $0, encoding: .utf8) }
        updatedAt = remote.updatedAt
        kind = remote.kind
        isPinned = remote.isPinned
        externalID = remote.externalID
        actionKind = remote.actionKind
        actionPayload = remote.actionPayload
        pendingSync = false
    }
}
