import Foundation

/// The Kroger API credentials, read from the app's Info.plist.
///
/// The keys are `KROGER_CLIENT_ID` and `KROGER_CLIENT_SECRET`. `config/Info.plist`
/// passes them through from `config/Secrets.xcconfig`, which is kept out of
/// version control (listed in `.gitignore`), never typed into a committed file.
struct AppConfiguration: Equatable {
    let clientID: String
    let clientSecret: String

    enum LoadError: Error, Equatable, LocalizedError {
        case missing([String])

        var errorDescription: String? {
            switch self {
            case .missing(let keys):
                "Missing Kroger credentials (\(keys.joined(separator: ", "))). Copy config/Secrets.example.xcconfig to config/Secrets.xcconfig, fill it in, and rebuild."
            }
        }
    }

    static let clientIDKey = "KROGER_CLIENT_ID"
    static let clientSecretKey = "KROGER_CLIENT_SECRET"

    /// Reads the credentials from an Info.plist-style dictionary. A value that
    /// is empty, or still an unexpanded build setting like `$(KROGER_CLIENT_ID)`,
    /// counts as missing.
    init(info: [String: Any]) throws {
        func value(_ key: String) -> String? {
            guard let raw = (info[key] as? String)?.trimmingCharacters(in: .whitespaces),
                  !raw.isEmpty, !raw.hasPrefix("$(") else { return nil }
            return raw
        }
        let id = value(Self.clientIDKey)
        let secret = value(Self.clientSecretKey)
        let missing = [id == nil ? Self.clientIDKey : nil, secret == nil ? Self.clientSecretKey : nil].compactMap { $0 }
        guard missing.isEmpty, let id, let secret else { throw LoadError.missing(missing) }
        clientID = id
        clientSecret = secret
    }

    static func fromBundle(_ bundle: Bundle = .main) throws -> AppConfiguration {
        try AppConfiguration(info: bundle.infoDictionary ?? [:])
    }
}
