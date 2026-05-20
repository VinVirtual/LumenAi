import Foundation

/// A type-erased Codable container so we can round-trip arbitrary JSON in
/// `metadata` columns without bespoke models per shape.
public struct AnyCodable: Codable, Hashable, @unchecked Sendable {
    public let value: AnyHashable

    public init(_ value: some Hashable & Codable & Sendable) {
        self.value = AnyHashable(value)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            value = AnyHashable("__null__")
            return
        }
        if let v = try? c.decode(Bool.self) { value = AnyHashable(v); return }
        if let v = try? c.decode(Int.self) { value = AnyHashable(v); return }
        if let v = try? c.decode(Double.self) { value = AnyHashable(v); return }
        if let v = try? c.decode(String.self) { value = AnyHashable(v); return }
        if let v = try? c.decode([AnyCodable].self) { value = AnyHashable(v); return }
        if let v = try? c.decode([String: AnyCodable].self) { value = AnyHashable(v); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON value")
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value.base {
        case let v as Bool: try c.encode(v)
        case let v as Int: try c.encode(v)
        case let v as Double: try c.encode(v)
        case let v as String:
            if v == "__null__" { try c.encodeNil() } else { try c.encode(v) }
        case let v as [AnyCodable]: try c.encode(v)
        case let v as [String: AnyCodable]: try c.encode(v)
        default: try c.encodeNil()
        }
    }
}
