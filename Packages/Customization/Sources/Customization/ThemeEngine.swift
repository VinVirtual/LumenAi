import DesignSystem
import Foundation

/// Imports/exports `Theme`s as JSON, including via `lumen://theme/...` deep
/// links so users can share theme packs.
public struct ThemeEngine: Sendable {
    public init() {}

    public func encode(_ theme: Theme) throws -> String {
        let data = try JSONEncoder().encode(theme)
        return data.base64EncodedString()
    }

    public func decode(_ payload: String) throws -> Theme {
        guard let data = Data(base64Encoded: payload) else { throw Error.invalid }
        return try JSONDecoder().decode(Theme.self, from: data)
    }

    public func shareURL(for theme: Theme) throws -> URL {
        let payload = try encode(theme)
        var components = URLComponents()
        components.scheme = "lumen"
        components.host = "theme"
        components.queryItems = [URLQueryItem(name: "data", value: payload)]
        guard let url = components.url else { throw Error.invalid }
        return url
    }

    public func theme(from url: URL) throws -> Theme {
        guard
            url.scheme == "lumen", url.host == "theme",
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let payload = comps.queryItems?.first(where: { $0.name == "data" })?.value
        else { throw Error.invalid }
        return try decode(payload)
    }

    public enum Error: Swift.Error { case invalid }
}
