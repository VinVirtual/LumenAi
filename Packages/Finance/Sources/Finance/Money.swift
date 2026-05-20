import Foundation

/// Lightweight money helpers. We intentionally do not adopt a full
/// money type; SwiftData stores amounts as `Int64` minor units +
/// `String` currency code so future schema changes stay simple.
public enum Money {
    /// Convert minor units (cents) to a localized currency string. Uses
    /// the device's locale for grouping/decimal separator but the row's
    /// own currency code so a EUR transaction reads as €12,50 even on a
    /// USD-locale device.
    public static func format(minor: Int64, currency: String) -> String {
        let amount = Decimal(minor) / 100
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber)
            ?? "\(currency) \(amount)"
    }

    /// Convert minor units to a signed string with a leading + or - so
    /// rows can be color-coded without the caller doing extra work.
    public static func formatSigned(minor: Int64, currency: String, isIncome: Bool) -> String {
        let prefix = isIncome ? "+" : "-"
        return prefix + format(minor: abs(minor), currency: currency)
    }

    /// Parse a string like "12.50" or "12,50" to minor units. Returns nil
    /// for empty or unparseable input. Tolerant of trailing/leading
    /// whitespace and of either decimal separator.
    public static func parse(_ raw: String) -> Int64? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        // Normalize to dot decimals so Decimal can parse a single string.
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        guard let decimal = Decimal(string: normalized) else { return nil }
        let scaled = (decimal * 100) as NSDecimalNumber
        return scaled.int64Value
    }
}
