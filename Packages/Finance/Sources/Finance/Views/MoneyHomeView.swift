import Charts
import Core
import DesignSystem
import SwiftData
import SwiftUI

/// The Money sub-tab. Local-only for the public/offline edition: no
/// cloud sync, no remote storage, just SwiftData under the App Group.
public struct MoneyHomeView: View {
    @StateObject private var service = FinanceService.shared
    @Environment(\.modelContext) private var context
    @Query(sort: \FinanceTransactionEntity.occurredAt, order: .reverse)
    private var transactions: [FinanceTransactionEntity]
    @Query(sort: \FinanceAccountEntity.sortIndex) private var accounts: [FinanceAccountEntity]
    @Query(sort: \FinanceCategoryEntity.sortIndex) private var categories: [FinanceCategoryEntity]

    @State private var selectedMonth: Date = Calendar.current.startOfMonth(for: Date())
    @State private var showAdd = false
    @State private var showAccounts = false
    @State private var showCategories = false

    private let ownerID: UUID

    public init(ownerID: UUID) {
        self.ownerID = ownerID
    }

    public var body: some View {
        // The trailing-bottom FAB used to live here. The central `+` on the
        // floating tab bar now drives this; it dispatches `.lumenOpenAddExpense`
        // which we listen for below.
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Tokens.Spacing.l) {
                monthHeader
                MonthSummaryCard(
                    summary: service.summary(for: selectedMonth, transactions: transactions),
                    currency: currentCurrency
                )
                if !savingsAccountsList.isEmpty {
                    SavingsCard(
                        accounts: savingsAccountsList,
                        transactions: transactions,
                        month: selectedMonth,
                        currency: currentCurrency
                    )
                }
                if !breakdown.isEmpty {
                    CategoryDonutCard(items: breakdown, currency: currentCurrency)
                }
                transactionList
            }
            .padding(Tokens.Spacing.l)
            .padding(.bottom, 160)
        }
        .scrollIndicators(.hidden)
        .onReceive(NotificationCenter.default.publisher(for: .lumenOpenAddExpense)) { _ in
            showAdd = true
        }
        .task {
            service.seedIfNeeded(ownerID: ownerID)
            service.cleanupSeedPendingIfNeeded()
            service.backfillSavingsCategoryIfNeeded(ownerID: ownerID)
            service.migrateSeedAccountsCurrencyIfClean(ownerID: ownerID, to: service.defaultCurrency)
        }
        .onChange(of: service.defaultCurrency) { _, newValue in
            // Same migration path when the user switches currency from
            // the AccountsSheet picker — re-tag clean seed accounts so
            // the SavingsCard updates immediately.
            service.migrateSeedAccountsCurrencyIfClean(ownerID: ownerID, to: newValue)
        }
        .sheet(isPresented: $showAdd) {
            AddTransactionSheet(
                ownerID: ownerID,
                accounts: accounts.filter { !$0.archived },
                categories: categories.filter { !$0.archived }
            )
            .presentationDetents([.fraction(0.7), .large])
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showAccounts) {
            AccountsSheet(ownerID: ownerID)
                .presentationDetents([.medium, .large])
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showCategories) {
            CategoriesSheet(ownerID: ownerID)
                .presentationDetents([.medium, .large])
                .presentationBackground(.ultraThinMaterial)
        }
    }

    private var currentCurrency: String { service.defaultCurrency }

    /// Active savings-kind accounts for the SavingsCard. Filtered out
    /// of the home until the user creates at least one.
    private var savingsAccountsList: [FinanceAccountEntity] {
        accounts.filter { $0.kind == .savings && !$0.archived }
    }

    private var breakdown: [FinanceService.CategoryTotal] {
        service.expenseBreakdown(for: selectedMonth, transactions: transactions, categories: categories)
    }

    private var monthHeader: some View {
        HStack(spacing: 8) {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedMonth.formatted(.dateTime.month(.wide).year()))
                    .font(Tokens.Typography.title)
                Text("\(monthlyTransactions.count) transactions")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.headline.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .disabled(isInFuture(after: selectedMonth))
            Menu {
                Button { showAccounts = true } label: { Label("Accounts", systemImage: "wallet.pass") }
                Button { showCategories = true } label: { Label("Categories", systemImage: "tag.fill") }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
            }
            .accessibilityLabel("Money settings")
        }
        .padding(.bottom, 4)
    }

    private var monthlyTransactions: [FinanceTransactionEntity] {
        let cal = Calendar.current
        return transactions.filter { cal.isDate($0.occurredAt, equalTo: selectedMonth, toGranularity: .month) }
    }

    private var transactionList: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            Text("Transactions")
                .font(Tokens.Typography.titleSmall)
            if monthlyTransactions.isEmpty {
                emptyState
            } else {
                ForEach(groupedByDay, id: \.0) { (day, items) in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        VStack(spacing: 6) {
                            ForEach(items) { transaction in
                                TransactionRow(
                                    transaction: transaction,
                                    account: accounts.first(where: { $0.id == transaction.accountID }),
                                    category: categories.first(where: { $0.id == transaction.categoryID })
                                )
                                .contextMenu {
                                    Button(role: .destructive) {
                                        service.delete(transaction)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("No transactions yet")
                    .font(Tokens.Typography.bodyMedium)
                Text("Tap the + button to log your first one. Everything stays on this device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var groupedByDay: [(Date, [FinanceTransactionEntity])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: monthlyTransactions) { cal.startOfDay(for: $0.occurredAt) }
        return grouped.sorted { $0.key > $1.key }
    }

    private func shiftMonth(_ offset: Int) {
        let cal = Calendar.current
        guard let next = cal.date(byAdding: .month, value: offset, to: selectedMonth) else { return }
        selectedMonth = cal.startOfMonth(for: next)
    }

    private func isInFuture(after month: Date) -> Bool {
        let cal = Calendar.current
        guard let next = cal.date(byAdding: .month, value: 1, to: month) else { return true }
        return next > Date()
    }
}

// MARK: - Cards

struct MonthSummaryCard: View {
    let summary: FinanceService.MonthSummary
    let currency: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 0) {
                    stat(
                        label: "Income",
                        value: Money.format(minor: summary.income, currency: currency),
                        color: .green
                    )
                    Divider().frame(height: 36).padding(.horizontal, 6)
                    stat(
                        label: "Expenses",
                        value: Money.format(minor: summary.expense, currency: currency),
                        color: .pink
                    )
                    Divider().frame(height: 36).padding(.horizontal, 6)
                    stat(
                        label: "Saved",
                        value: Money.format(minor: summary.saved, currency: currency),
                        color: .cyan
                    )
                }

                Divider().opacity(0.3)

                // Net (after expenses) is the spending-account view —
                // matches what's actually left in cash. Total net adds
                // savings back so the user sees the bigger picture: the
                // money tagged "to savings" hasn't really left them.
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NET (AFTER EXPENSES)")
                            .font(.caption2.weight(.semibold))
                            .tracking(0.6)
                            .foregroundStyle(.secondary)
                        Text(Money.formatSigned(
                            minor: summary.net,
                            currency: currency,
                            isIncome: summary.net >= 0
                        ))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(summary.net >= 0 ? .mint : .orange)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("TOTAL NET")
                            .font(.caption2.weight(.semibold))
                            .tracking(0.6)
                            .foregroundStyle(.secondary)
                        Text(Money.formatSigned(
                            minor: summary.totalNet,
                            currency: currency,
                            isIncome: summary.totalNet >= 0
                        ))
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(summary.totalNet >= 0 ? .green : .orange)
                    }
                }
            }
        }
    }

    private func stat(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Renders one row per savings account with this month's deposits and
/// the rolling balance. Only shown when the user has at least one
/// account of `kind == .savings`.
struct SavingsCard: View {
    let accounts: [FinanceAccountEntity]
    let transactions: [FinanceTransactionEntity]
    let month: Date
    let currency: String

    @StateObject private var service = FinanceService.shared

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(.cyan)
                    Text("Savings")
                        .font(Tokens.Typography.titleSmall)
                    Spacer()
                    Text("\(accounts.count) account\(accounts.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                ForEach(accounts) { account in
                    row(for: account)
                    if account.id != accounts.last?.id {
                        Divider().opacity(0.3)
                    }
                }
            }
        }
    }

    private func row(for account: FinanceAccountEntity) -> some View {
        let balance = service.savingsBalance(account: account, transactions: transactions)
        let monthly = service.savingsDepositedThisMonth(account: account, in: month, transactions: transactions)
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: account.colorHex).opacity(0.25))
                    .frame(width: 36, height: 36)
                Image(systemName: account.iconSymbol)
                    .foregroundStyle(Color(hex: account.colorHex))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name).font(.body.weight(.medium))
                Text("Balance \(Money.format(minor: balance, currency: account.currency))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            if monthly > 0 {
                Text("+\(Money.format(minor: monthly, currency: account.currency))")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.cyan)
            }
        }
    }
}

struct CategoryDonutCard: View {
    let items: [FinanceService.CategoryTotal]
    let currency: String

    private var total: Int64 { items.reduce(0) { $0 + $1.amountMinor } }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Where it went")
                    .font(Tokens.Typography.titleSmall)
                HStack(alignment: .top, spacing: 16) {
                    Chart(items) { item in
                        SectorMark(
                            angle: .value("Spent", item.amountMinor),
                            innerRadius: .ratio(0.62),
                            angularInset: 1.5
                        )
                        .foregroundStyle(Color(hex: item.colorHex))
                    }
                    .frame(width: 120, height: 120)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(items.prefix(5)) { item in
                            HStack(spacing: 8) {
                                Circle().fill(Color(hex: item.colorHex)).frame(width: 8, height: 8)
                                Text(item.name).font(.caption)
                                Spacer()
                                Text(Money.format(minor: item.amountMinor, currency: currency))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if items.count > 5 {
                            Text("+\(items.count - 5) more")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("Total \(Money.format(minor: total, currency: currency))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Rows

struct TransactionRow: View {
    let transaction: FinanceTransactionEntity
    let account: FinanceAccountEntity?
    let category: FinanceCategoryEntity?

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: category?.colorHex ?? "#94A3B8").opacity(0.25))
                    .frame(width: 38, height: 38)
                Image(systemName: category?.iconSymbol ?? "questionmark.circle.fill")
                    .foregroundStyle(Color(hex: category?.colorHex ?? "#94A3B8"))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(category?.name ?? "Uncategorized")
                    .font(Tokens.Typography.bodyMedium)
                HStack(spacing: 6) {
                    if let account {
                        Text(account.name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let note = transaction.note, !note.isEmpty {
                        Text("·").foregroundStyle(.secondary)
                        Text(note).font(.caption2).foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            Text(Money.formatSigned(
                minor: transaction.amountMinor,
                currency: transaction.currency,
                isIncome: transaction.direction == .income
            ))
            .font(.callout.weight(.semibold).monospacedDigit())
            .foregroundStyle(transaction.direction == .income ? .green : .primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.m, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Sheets

struct AddTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = FinanceService.shared

    let ownerID: UUID
    let accounts: [FinanceAccountEntity]
    let categories: [FinanceCategoryEntity]

    @State private var direction: FinanceDirection = .expense
    @State private var amountText: String = ""
    @State private var selectedAccountID: UUID?
    @State private var selectedCategoryID: UUID?
    @State private var note: String = ""
    @State private var occurredAt: Date = .now
    @State private var savingsAccountID: UUID?
    @State private var showAddSavings = false
    @FocusState private var amountFocused: Bool

    /// Only "savings"-kind accounts can receive a savings deposit.
    private var savingsAccounts: [FinanceAccountEntity] {
        accounts.filter { $0.kind == .savings && !$0.archived }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("", selection: $direction) {
                        Text("Expense").tag(FinanceDirection.expense)
                        Text("Income").tag(FinanceDirection.income)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }

                Section("Amount") {
                    HStack {
                        Text(currencySymbol).foregroundStyle(.secondary)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.title2.weight(.semibold).monospacedDigit())
                            .focused($amountFocused)
                    }
                }

                Section("Account") {
                    if accounts.isEmpty {
                        Text("Add an account first").foregroundStyle(.secondary)
                    } else {
                        Picker("Account", selection: Binding(
                            get: { selectedAccountID ?? accounts.first?.id ?? UUID() },
                            set: { selectedAccountID = $0 }
                        )) {
                            ForEach(accounts) { acc in
                                Label(acc.name, systemImage: acc.iconSymbol).tag(acc.id)
                            }
                        }
                    }
                }

                Section("Category") {
                    let filtered = categories.filter { $0.direction == direction }
                    if filtered.isEmpty {
                        Text("No \(direction.label.lowercased()) categories yet").foregroundStyle(.secondary)
                    } else {
                        let columns = [GridItem(.adaptive(minimum: 88), spacing: 8)]
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(filtered) { cat in
                                CategoryChip(
                                    category: cat,
                                    selected: selectedCategoryID == cat.id
                                ) {
                                    selectedCategoryID = cat.id
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if direction == .expense {
                    savingsSection
                }

                Section("When") {
                    DatePicker("Date", selection: $occurredAt, displayedComponents: [.date, .hourAndMinute])
                }

                Section("Note") {
                    TextField("Optional", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                }
            }
            .navigationTitle(direction == .income ? "Add income" : "Add expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { commit() }
                        .disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { amountFocused = false }
                }
            }
        }
        .onAppear {
            amountFocused = true
            if selectedAccountID == nil { selectedAccountID = accounts.first?.id }
            if selectedCategoryID == nil {
                selectedCategoryID = categories.first(where: { $0.direction == direction })?.id
            }
        }
        .onChange(of: direction) { _, newValue in
            // Snap to a category that matches the new direction so the
            // user doesn't accidentally save income tagged as Groceries.
            if let current = selectedCategoryID,
               let cat = categories.first(where: { $0.id == current }),
               cat.direction != newValue {
                selectedCategoryID = categories.first(where: { $0.direction == newValue })?.id
            } else if selectedCategoryID == nil {
                selectedCategoryID = categories.first(where: { $0.direction == newValue })?.id
            }
            // Income transactions never have a savings tag — clear any
            // stale selection so the picker doesn't re-appear when the
            // user toggles back to expense.
            if newValue == .income {
                savingsAccountID = nil
            }
        }
        .sheet(isPresented: $showAddSavings) {
            AccountsSheet(ownerID: ownerID, presetKind: .savings)
                .presentationDetents([.medium, .large])
                .presentationBackground(.ultraThinMaterial)
        }
    }

    /// Lets the user mark this expense as a deposit into one of their
    /// savings accounts. Money still leaves the spending account (so the
    /// month's net drops), but the savings card credits the same amount
    /// so the user sees their bucket grow.
    @ViewBuilder
    private var savingsSection: some View {
        Section("Savings") {
            Toggle("Send to savings", isOn: Binding(
                get: { savingsAccountID != nil },
                set: { isOn in
                    if isOn {
                        savingsAccountID = savingsAccounts.first?.id
                        // Snap the category to "Savings" so the deposit
                        // shows up correctly in the breakdown / ledger
                        // instead of inheriting whatever expense
                        // category was left selected (Groceries by
                        // default). Only switch if the user hasn't
                        // explicitly picked a different category for
                        // this entry yet, OR the current selection is
                        // the seeded default.
                        if let savingsCat = service.savingsCategory(ownerID: ownerID) {
                            selectedCategoryID = savingsCat.id
                        }
                    } else {
                        savingsAccountID = nil
                    }
                }
            ))
            if savingsAccountID != nil {
                if savingsAccounts.isEmpty {
                    Button {
                        showAddSavings = true
                        HapticEngine.shared.play(.tap)
                    } label: {
                        Label("Add a savings account", systemImage: "plus.circle.fill")
                    }
                } else {
                    Picker("Savings account", selection: Binding(
                        get: { savingsAccountID ?? savingsAccounts.first?.id ?? UUID() },
                        set: { savingsAccountID = $0 }
                    )) {
                        ForEach(savingsAccounts) { acc in
                            Label(acc.name, systemImage: acc.iconSymbol).tag(acc.id)
                        }
                    }
                }
                Text("Counts as an expense from your income, and adds to this account's savings balance.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var canSave: Bool {
        guard let amount = Money.parse(amountText), amount > 0 else { return false }
        return selectedAccountID != nil
    }

    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = service.defaultCurrency
        return formatter.currencySymbol
    }

    private func commit() {
        guard let amount = Money.parse(amountText),
              amount > 0,
              let accountID = selectedAccountID
        else { return }
        service.addTransaction(
            ownerID: ownerID,
            accountID: accountID,
            categoryID: selectedCategoryID,
            occurredAt: occurredAt,
            amountMinor: amount,
            currency: service.defaultCurrency,
            direction: direction,
            note: note,
            savingsAccountID: direction == .expense ? savingsAccountID : nil
        )
        HapticEngine.shared.play(.success)
        dismiss()
    }
}

private struct CategoryChip: View {
    let category: FinanceCategoryEntity
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color(hex: category.colorHex).opacity(selected ? 0.9 : 0.25))
                        .frame(width: 38, height: 38)
                    Image(systemName: category.iconSymbol)
                        .foregroundStyle(selected ? .white : Color(hex: category.colorHex))
                }
                Text(category.name)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? Color(hex: category.colorHex) : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct AccountsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = FinanceService.shared
    @Query(sort: \FinanceAccountEntity.sortIndex) private var accounts: [FinanceAccountEntity]
    let ownerID: UUID
    /// When the sheet is opened from "Add a savings account" inside the
    /// transaction composer, prefill the kind picker so the user lands
    /// straight on Savings without scrolling to it.
    let presetKind: FinanceAccountKind?

    @State private var newName = ""
    @State private var newKind: FinanceAccountKind = .cash

    init(ownerID: UUID, presetKind: FinanceAccountKind? = nil) {
        self.ownerID = ownerID
        self.presetKind = presetKind
        _newKind = State(initialValue: presetKind ?? .cash)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Your accounts") {
                    ForEach(accounts) { acc in
                        HStack {
                            Image(systemName: acc.iconSymbol)
                                .foregroundStyle(Color(hex: acc.colorHex))
                            Text(acc.name)
                            Spacer()
                            Text(acc.currency)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Add new") {
                    TextField("Name", text: $newName)
                    Picker("Type", selection: $newKind) {
                        ForEach(FinanceAccountKind.allCases, id: \.self) { kind in
                            Label(kind.label, systemImage: kind.defaultIcon).tag(kind)
                        }
                    }
                    Button("Add account") {
                        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        service.addAccount(
                            ownerID: ownerID,
                            name: newName,
                            kind: newKind,
                            colorHex: "#7C5CFF"
                        )
                        newName = ""
                        newKind = .cash
                    }
                }
                Section("Default currency") {
                    Picker("Currency", selection: $service.defaultCurrency) {
                        ForEach(["USD", "EUR", "GBP", "JPY", "AUD", "CAD", "SGD", "INR", "MYR", "CNY"], id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                }
            }
            .navigationTitle("Accounts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct CategoriesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = FinanceService.shared
    @Query(sort: \FinanceCategoryEntity.sortIndex) private var categories: [FinanceCategoryEntity]
    let ownerID: UUID

    @State private var newName = ""
    @State private var newIcon = "tag.fill"
    @State private var newDirection: FinanceDirection = .expense

    private static let iconChoices = [
        "cart.fill", "fork.knife", "car.fill", "bolt.fill", "house.fill",
        "bag.fill", "heart.fill", "play.rectangle.fill", "airplane",
        "ellipsis.circle.fill", "dollarsign.circle.fill", "gift.fill",
        "tag.fill", "creditcard.fill", "fuelpump.fill", "pawprint.fill",
        "graduationcap.fill", "stethoscope", "wrench.and.screwdriver.fill"
    ]
    private static let colorChoices = [
        "#1ABC9C", "#FF8C42", "#3DA5FF", "#FFD60A", "#FF6F91",
        "#A78BFA", "#F472B6", "#7C5CFF", "#22D3EE", "#34D399"
    ]

    @State private var newColor = "#7C5CFF"

    var body: some View {
        NavigationStack {
            List {
                Section("Expenses") {
                    ForEach(categories.filter { $0.direction == .expense }) { cat in
                        row(for: cat)
                    }
                }
                Section("Income") {
                    ForEach(categories.filter { $0.direction == .income }) { cat in
                        row(for: cat)
                    }
                }
                Section("Add new") {
                    TextField("Name", text: $newName)
                    Picker("Type", selection: $newDirection) {
                        Text("Expense").tag(FinanceDirection.expense)
                        Text("Income").tag(FinanceDirection.income)
                    }
                    .pickerStyle(.segmented)
                    iconPicker
                    colorPicker
                    Button("Add category") {
                        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        service.addCategory(
                            ownerID: ownerID,
                            name: newName,
                            iconSymbol: newIcon,
                            colorHex: newColor,
                            direction: newDirection
                        )
                        newName = ""
                    }
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(for cat: FinanceCategoryEntity) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color(hex: cat.colorHex).opacity(0.25)).frame(width: 30, height: 30)
                Image(systemName: cat.iconSymbol).foregroundStyle(Color(hex: cat.colorHex))
            }
            Text(cat.name)
        }
    }

    private var iconPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.iconChoices, id: \.self) { symbol in
                    Button { newIcon = symbol } label: {
                        Image(systemName: symbol)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle().fill(
                                    newIcon == symbol
                                        ? Color(hex: newColor).opacity(0.4)
                                        : Color.gray.opacity(0.15)
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var colorPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.colorChoices, id: \.self) { hex in
                    Button { newColor = hex } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: newColor == hex ? 2 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Calendar helper

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}
