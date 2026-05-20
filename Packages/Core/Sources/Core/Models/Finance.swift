import Foundation
import SwiftData

/// Finance entities live alongside reminders in the SwiftData container so
/// the user's local-only money log persists across launches and can later
/// sync to Supabase using the same last-write-wins pattern.
///
/// Money is stored as `Int64` minor units (cents) to avoid floating-point
/// drift when totalling. Each row carries an ISO-4217 currency string so
/// future multi-currency support won't require a migration.

public enum FinanceAccountKind: String, Codable, CaseIterable, Sendable {
    case cash, bank, card, savings, custom

    public var defaultIcon: String {
        switch self {
        case .cash: "banknote"
        case .bank: "building.columns.fill"
        case .card: "creditcard.fill"
        case .savings: "lock.shield.fill"
        case .custom: "wallet.pass.fill"
        }
    }

    public var label: String {
        switch self {
        case .cash: "Cash"
        case .bank: "Bank"
        case .card: "Credit card"
        case .savings: "Savings"
        case .custom: "Custom"
        }
    }
}

public enum FinanceDirection: String, Codable, CaseIterable, Sendable {
    case income, expense

    public var label: String {
        switch self {
        case .income: "Income"
        case .expense: "Expense"
        }
    }

    public var glyph: String {
        switch self {
        case .income: "arrow.down.circle.fill"
        case .expense: "arrow.up.circle.fill"
        }
    }
}

@Model
public final class FinanceAccountEntity {
    @Attribute(.unique) public var id: UUID
    public var ownerID: UUID
    public var name: String
    public var kindRaw: String
    public var iconSymbol: String
    public var colorHex: String
    public var currency: String
    public var openingBalanceMinor: Int64
    public var sortIndex: Int
    public var archived: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var pendingSync: Bool

    public init(
        id: UUID = UUID(),
        ownerID: UUID,
        name: String,
        kind: FinanceAccountKind = .cash,
        iconSymbol: String? = nil,
        colorHex: String = "#7C5CFF",
        currency: String = "USD",
        openingBalanceMinor: Int64 = 0,
        sortIndex: Int = 0,
        archived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        pendingSync: Bool = true
    ) {
        self.id = id
        self.ownerID = ownerID
        self.name = name
        self.kindRaw = kind.rawValue
        self.iconSymbol = iconSymbol ?? kind.defaultIcon
        self.colorHex = colorHex
        self.currency = currency
        self.openingBalanceMinor = openingBalanceMinor
        self.sortIndex = sortIndex
        self.archived = archived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.pendingSync = pendingSync
    }

    public var kind: FinanceAccountKind {
        get { FinanceAccountKind(rawValue: kindRaw) ?? .custom }
        set { kindRaw = newValue.rawValue }
    }
}

@Model
public final class FinanceCategoryEntity {
    @Attribute(.unique) public var id: UUID
    public var ownerID: UUID
    public var name: String
    public var iconSymbol: String
    public var colorHex: String
    public var directionRaw: String
    public var sortIndex: Int
    public var archived: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var pendingSync: Bool

    public init(
        id: UUID = UUID(),
        ownerID: UUID,
        name: String,
        iconSymbol: String,
        colorHex: String,
        direction: FinanceDirection = .expense,
        sortIndex: Int = 0,
        archived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        pendingSync: Bool = true
    ) {
        self.id = id
        self.ownerID = ownerID
        self.name = name
        self.iconSymbol = iconSymbol
        self.colorHex = colorHex
        self.directionRaw = direction.rawValue
        self.sortIndex = sortIndex
        self.archived = archived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.pendingSync = pendingSync
    }

    public var direction: FinanceDirection {
        get { FinanceDirection(rawValue: directionRaw) ?? .expense }
        set { directionRaw = newValue.rawValue }
    }
}

@Model
public final class FinanceTransactionEntity {
    @Attribute(.unique) public var id: UUID
    public var ownerID: UUID
    public var accountID: UUID
    public var categoryID: UUID?
    public var occurredAt: Date
    /// Amount in minor units (cents). Always positive; pair with
    /// `directionRaw` to know if it's income or expense. Storing it
    /// non-negative keeps math reliable across currencies and avoids
    /// double-negative bugs when reading older data.
    public var amountMinor: Int64
    public var currency: String
    public var directionRaw: String
    public var note: String?
    public var receiptPath: String?
    /// When non-nil, this expense was deposited into the named savings
    /// account. The amount is still an expense (income shrinks) but it
    /// also accumulates against the savings account's balance so the
    /// user can see how much sits in each savings bucket.
    public var savingsAccountID: UUID?
    public var createdAt: Date
    public var updatedAt: Date
    public var pendingSync: Bool

    public init(
        id: UUID = UUID(),
        ownerID: UUID,
        accountID: UUID,
        categoryID: UUID? = nil,
        occurredAt: Date = .now,
        amountMinor: Int64,
        currency: String = "USD",
        direction: FinanceDirection = .expense,
        note: String? = nil,
        receiptPath: String? = nil,
        savingsAccountID: UUID? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        pendingSync: Bool = true
    ) {
        self.id = id
        self.ownerID = ownerID
        self.accountID = accountID
        self.categoryID = categoryID
        self.occurredAt = occurredAt
        self.amountMinor = abs(amountMinor)
        self.currency = currency
        self.directionRaw = direction.rawValue
        self.note = note
        self.receiptPath = receiptPath
        self.savingsAccountID = savingsAccountID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.pendingSync = pendingSync
    }

    public var direction: FinanceDirection {
        get { FinanceDirection(rawValue: directionRaw) ?? .expense }
        set { directionRaw = newValue.rawValue }
    }

    /// Signed amount. Negative for expense, positive for income. Useful
    /// for chart sums.
    public var signedAmountMinor: Int64 {
        direction == .income ? amountMinor : -amountMinor
    }
}
