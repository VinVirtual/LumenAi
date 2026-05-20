import Core
import Foundation
import SwiftData
import SwiftUI

/// Application logic for the Money sub-tab. Holds the user's preferred
/// default currency, seeds default accounts/categories on first launch,
/// and exposes summary helpers used by the dashboard cards.
///
/// Local-only for now: there's no Supabase round-trip yet. Everything
/// lives in the same SwiftData container as reminders so transactions
/// persist across launches and survive widget extensions reading the
/// shared App Group store.
@MainActor
public final class FinanceService: ObservableObject {
    public static let shared = FinanceService()

    /// Default currency used when seeding accounts and adding new
    /// transactions. Kept in `@AppStorage` so it survives launches and
    /// can be edited from a future settings screen.
    @AppStorage("lumen.finance.defaultCurrency") public var defaultCurrency: String = "USD"

    /// Whether we've already seeded the user's first set of accounts and
    /// categories. Idempotent: every call to `seedIfNeeded` checks this
    /// flag before inserting anything.
    @AppStorage("lumen.finance.didSeed") private var didSeed: Bool = false

    /// Old builds inserted seeded accounts/categories with `pendingSync = true`,
    /// which inflated the pending-sync badge to 18 even on a clean install
    /// with zero transactions. We run a one-time cleanup that flips those
    /// defaults to `pendingSync = false` if the user hasn't logged any
    /// transactions yet (so a real change wouldn't be silently swallowed).
    @AppStorage("lumen.finance.didCleanupSeedPending") private var didCleanupSeedPending: Bool = false

    /// Users who seeded before the "Savings" expense category was added
    /// will be missing it. Run a one-time backfill that inserts it on
    /// their next launch so saving deposits don't keep landing under
    /// "Groceries" by default.
    @AppStorage("lumen.finance.didBackfillSavingsCategory") private var didBackfillSavingsCategory: Bool = false

    private let persistence: PersistenceController

    public init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    // MARK: - Seeding

    /// Insert sensible defaults so the user can start logging the first
    /// time they open the Money tab. No-op after the first run.
    public func seedIfNeeded(ownerID: UUID) {
        guard !didSeed else { return }
        let context = persistence.mainContext

        let accountSeeds: [(String, FinanceAccountKind, String)] = [
            ("Cash", .cash, "#7C5CFF"),
            ("Bank", .bank, "#3DA5FF"),
            ("Credit card", .card, "#FF6F91"),
            ("Savings", .savings, "#1ABC9C"),
            ("Other", .custom, "#94A3B8")
        ]
        for (i, (name, kind, color)) in accountSeeds.enumerated() {
            let acc = FinanceAccountEntity(
                ownerID: ownerID,
                name: name,
                kind: kind,
                colorHex: color,
                currency: defaultCurrency,
                sortIndex: i
            )
            // Defaults are deterministic — don't count them toward the
            // pending-sync badge until the user actually edits one.
            // The setter on `FinanceAccountEntity` flips this back to
            // true on any subsequent mutation.
            acc.pendingSync = false
            context.insert(acc)
        }

        let categorySeeds: [(String, String, String, FinanceDirection)] = [
            // Savings is its own expense category so deposits show up
            // labelled "Savings" in the breakdown and ledger instead of
            // bleeding into whatever category was last selected (the
            // most reported bug was a savings deposit appearing as
            // "Groceries"). The AddTransactionSheet auto-snaps to this
            // category whenever the user flips the "Send to savings"
            // toggle.
            ("Savings", "lock.shield.fill", "#1ABC9C", .expense),
            ("Groceries", "cart.fill", "#34D399", .expense),
            ("Eating out", "fork.knife", "#FF8C42", .expense),
            ("Transport", "car.fill", "#3DA5FF", .expense),
            ("Bills", "bolt.fill", "#FFD60A", .expense),
            ("Rent", "house.fill", "#FF6F91", .expense),
            ("Shopping", "bag.fill", "#A78BFA", .expense),
            ("Health", "heart.fill", "#F472B6", .expense),
            ("Entertainment", "play.rectangle.fill", "#7C5CFF", .expense),
            ("Travel", "airplane", "#22D3EE", .expense),
            ("Other", "ellipsis.circle.fill", "#94A3B8", .expense),
            ("Salary", "dollarsign.circle.fill", "#34D399", .income),
            ("Gift", "gift.fill", "#FBBF24", .income),
            ("Refund", "arrow.uturn.backward.circle.fill", "#60A5FA", .income)
        ]
        for (i, (name, icon, color, dir)) in categorySeeds.enumerated() {
            let cat = FinanceCategoryEntity(
                ownerID: ownerID,
                name: name,
                iconSymbol: icon,
                colorHex: color,
                direction: dir,
                sortIndex: i
            )
            // Same rationale as accounts above: stock seeds shouldn't
            // inflate the pending count.
            cat.pendingSync = false
            context.insert(cat)
        }

        try? context.save()
        didSeed = true
    }

    /// Insert the "Savings" expense category for users who seeded before
    /// it existed. Idempotent via `didBackfillSavingsCategory`. Run from
    /// the Money tab's `task` so older installs catch up automatically.
    public func backfillSavingsCategoryIfNeeded(ownerID: UUID) {
        guard !didBackfillSavingsCategory else { return }
        let context = persistence.mainContext
        let descriptor = FetchDescriptor<FinanceCategoryEntity>(
            predicate: #Predicate { $0.ownerID == ownerID && $0.name == "Savings" }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        if existing.isEmpty {
            let cat = FinanceCategoryEntity(
                ownerID: ownerID,
                name: "Savings",
                iconSymbol: "lock.shield.fill",
                colorHex: "#1ABC9C",
                direction: .expense,
                sortIndex: -1
            )
            context.insert(cat)
            try? context.save()
        }
        didBackfillSavingsCategory = true
    }

    /// Look up the user's "Savings" expense category if it exists.
    /// Used by `AddTransactionSheet` to auto-snap to it whenever the
    /// "Send to savings" toggle is flipped on.
    public func savingsCategory(ownerID: UUID) -> FinanceCategoryEntity? {
        let context = persistence.mainContext
        let descriptor = FetchDescriptor<FinanceCategoryEntity>(
            predicate: #Predicate {
                $0.ownerID == ownerID
                    && $0.name == "Savings"
                    && $0.archived == false
            }
        )
        return try? context.fetch(descriptor).first
    }

    /// When the user changes default currency, untouched seeded accounts
    /// (no transactions ever logged against them) get migrated to the
    /// new code so the SavingsCard / TransactionRow stop showing USD
    /// after the user picks MYR. We deliberately skip accounts that
    /// already have transactions to avoid retroactively re-labelling
    /// real history.
    public func migrateSeedAccountsCurrencyIfClean(ownerID: UUID, to currency: String) {
        let context = persistence.mainContext
        let accounts = (try? context.fetch(FetchDescriptor<FinanceAccountEntity>(
            predicate: #Predicate { $0.ownerID == ownerID }
        ))) ?? []
        guard !accounts.isEmpty else { return }
        let txs = (try? context.fetch(FetchDescriptor<FinanceTransactionEntity>(
            predicate: #Predicate { $0.ownerID == ownerID }
        ))) ?? []
        let usedAccountIDs = Set(txs.map(\.accountID))
        var changed = false
        for acc in accounts where acc.currency != currency && !usedAccountIDs.contains(acc.id) {
            acc.currency = currency
            changed = true
        }
        if changed {
            try? context.save()
            objectWillChange.send()
        }
    }

    /// One-time fix-up for installs that were seeded by an older build
    /// where defaults shipped with `pendingSync = true`. Safe to call on
    /// every launch — the AppStorage flag short-circuits after the first
    /// successful run.
    public func cleanupSeedPendingIfNeeded() {
        guard !didCleanupSeedPending else { return }
        let context = persistence.mainContext
        let txCount = (try? context.fetchCount(FetchDescriptor<FinanceTransactionEntity>())) ?? 0
        guard txCount == 0 else {
            // User has actual data — don't touch their pending state.
            didCleanupSeedPending = true
            return
        }
        let accounts = (try? context.fetch(FetchDescriptor<FinanceAccountEntity>())) ?? []
        let categories = (try? context.fetch(FetchDescriptor<FinanceCategoryEntity>())) ?? []
        for acc in accounts where acc.pendingSync { acc.pendingSync = false }
        for cat in categories where cat.pendingSync { cat.pendingSync = false }
        try? context.save()
        didCleanupSeedPending = true
    }

    // MARK: - Mutations

    public func addTransaction(
        ownerID: UUID,
        accountID: UUID,
        categoryID: UUID?,
        occurredAt: Date,
        amountMinor: Int64,
        currency: String,
        direction: FinanceDirection,
        note: String?,
        savingsAccountID: UUID? = nil
    ) {
        let entity = FinanceTransactionEntity(
            ownerID: ownerID,
            accountID: accountID,
            categoryID: categoryID,
            occurredAt: occurredAt,
            amountMinor: amountMinor,
            currency: currency,
            direction: direction,
            note: note?.isEmpty == true ? nil : note,
            savingsAccountID: savingsAccountID
        )
        let context = persistence.mainContext
        context.insert(entity)
        try? context.save()
        objectWillChange.send()
    }

    public func delete(_ transaction: FinanceTransactionEntity) {
        let context = persistence.mainContext
        context.delete(transaction)
        try? context.save()
        objectWillChange.send()
    }

    public func addAccount(ownerID: UUID, name: String, kind: FinanceAccountKind, colorHex: String) {
        let context = persistence.mainContext
        let descriptor = FetchDescriptor<FinanceAccountEntity>(
            sortBy: [SortDescriptor(\.sortIndex, order: .reverse)]
        )
        let nextIndex = ((try? context.fetch(descriptor).first?.sortIndex) ?? -1) + 1
        let acc = FinanceAccountEntity(
            ownerID: ownerID,
            name: name,
            kind: kind,
            colorHex: colorHex,
            currency: defaultCurrency,
            sortIndex: nextIndex
        )
        context.insert(acc)
        try? context.save()
        objectWillChange.send()
    }

    public func addCategory(
        ownerID: UUID,
        name: String,
        iconSymbol: String,
        colorHex: String,
        direction: FinanceDirection
    ) {
        let context = persistence.mainContext
        let descriptor = FetchDescriptor<FinanceCategoryEntity>(
            sortBy: [SortDescriptor(\.sortIndex, order: .reverse)]
        )
        let nextIndex = ((try? context.fetch(descriptor).first?.sortIndex) ?? -1) + 1
        let cat = FinanceCategoryEntity(
            ownerID: ownerID,
            name: name,
            iconSymbol: iconSymbol,
            colorHex: colorHex,
            direction: direction,
            sortIndex: nextIndex
        )
        context.insert(cat)
        try? context.save()
        objectWillChange.send()
    }

    // MARK: - Summaries

    /// Income / expense / net for a given month, in the user's default
    /// currency. Mixes currencies naively — multi-currency conversion
    /// is a follow-up.
    public struct MonthSummary {
        public let income: Int64
        public let expense: Int64
        /// Sum of expenses tagged with a savings account this month —
        /// money the user moved into savings rather than truly spent.
        public let saved: Int64
        /// Income minus all expenses (savings deposits included, since
        /// they DO leave the user's spending account).
        public var net: Int64 { income - expense }
        /// What the user actually has when you give themselves credit
        /// for savings: net + saved. Highlights that money moved to
        /// savings hasn't really left their pocket.
        public var totalNet: Int64 { net + saved }
    }

    public func summary(for month: Date, transactions: [FinanceTransactionEntity]) -> MonthSummary {
        let cal = Calendar.current
        let monthly = transactions.filter {
            cal.isDate($0.occurredAt, equalTo: month, toGranularity: .month)
        }
        let income = monthly
            .filter { $0.direction == .income }
            .reduce(Int64(0)) { $0 + $1.amountMinor }
        let expense = monthly
            .filter { $0.direction == .expense }
            .reduce(Int64(0)) { $0 + $1.amountMinor }
        let saved = monthly
            .filter { $0.direction == .expense && $0.savingsAccountID != nil }
            .reduce(Int64(0)) { $0 + $1.amountMinor }
        return MonthSummary(income: income, expense: expense, saved: saved)
    }

    /// Running balance for a single savings account: opening balance plus
    /// every expense that's been deposited into it. Naive on currency —
    /// assumes the savings account currency matches the deposits.
    public func savingsBalance(
        account: FinanceAccountEntity,
        transactions: [FinanceTransactionEntity]
    ) -> Int64 {
        let id = account.id
        let deposits = transactions
            .filter { $0.savingsAccountID == id && $0.direction == .expense }
            .reduce(Int64(0)) { $0 + $1.amountMinor }
        return account.openingBalanceMinor + deposits
    }

    /// Sum of deposits made into this savings account during a given
    /// month. Powers the "+$X this month" pill on the Savings card.
    public func savingsDepositedThisMonth(
        account: FinanceAccountEntity,
        in month: Date,
        transactions: [FinanceTransactionEntity]
    ) -> Int64 {
        let id = account.id
        let cal = Calendar.current
        return transactions
            .filter {
                $0.savingsAccountID == id
                    && $0.direction == .expense
                    && cal.isDate($0.occurredAt, equalTo: month, toGranularity: .month)
            }
            .reduce(Int64(0)) { $0 + $1.amountMinor }
    }

    public struct CategoryTotal: Identifiable {
        public let id: UUID
        public let categoryID: UUID?
        public let name: String
        public let colorHex: String
        public let iconSymbol: String
        public let amountMinor: Int64
    }

    /// Per-category expense totals for the given month, sorted descending.
    public func expenseBreakdown(
        for month: Date,
        transactions: [FinanceTransactionEntity],
        categories: [FinanceCategoryEntity]
    ) -> [CategoryTotal] {
        let cal = Calendar.current
        let categoriesByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        let monthlyExpenses = transactions.filter {
            cal.isDate($0.occurredAt, equalTo: month, toGranularity: .month) && $0.direction == .expense
        }
        var totals: [UUID?: Int64] = [:]
        for t in monthlyExpenses {
            totals[t.categoryID, default: 0] += t.amountMinor
        }
        return totals
            .map { (catID, amount) in
                let cat = catID.flatMap { categoriesByID[$0] }
                return CategoryTotal(
                    id: catID ?? UUID(),
                    categoryID: catID,
                    name: cat?.name ?? "Uncategorized",
                    colorHex: cat?.colorHex ?? "#94A3B8",
                    iconSymbol: cat?.iconSymbol ?? "questionmark.circle.fill",
                    amountMinor: amount
                )
            }
            .sorted { $0.amountMinor > $1.amountMinor }
    }
}
