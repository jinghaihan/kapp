import Foundation
import Observation
import os

@Observable
package final class Localization: @unchecked Sendable {
    package static let languages = ["en", "zh-Hans", "zh-Hant", "ja", "ko"]
    package static let languageNames = ["en": "English", "zh-Hans": "简体中文", "zh-Hant": "繁體中文", "ja": "日本語", "ko": "한국어"]
    package static let current = Localization()

    // SwiftPM's generated accessor does not search Contents/Resources in a packaged executable.
    static let resources: Bundle = {
        let installed = Bundle.main.resourceURL?.appending(path: "Kapp_KappLocalization.bundle")
        return installed.flatMap(Bundle.init(url:)) ?? .module
    }()
    private static let bundles: [String: Bundle] = Dictionary(uniqueKeysWithValues: languages.map { language in
        // SwiftPM lowercases localization directory names, including script identifiers.
        let name = resources.localizations.first { $0.caseInsensitiveCompare(language) == .orderedSame } ?? "en"
        let folder = resources.url(forResource: name, withExtension: "lproj")
        return (language, folder.flatMap(Bundle.init(url:)) ?? resources)
    })

    @ObservationIgnored private let automaticLanguage: String
    // Error descriptions can be read off the main actor while the interface changes language.
    @ObservationIgnored private let selection: OSAllocatedUnfairLock<String>

    package var language: String {
        access(keyPath: \.language)
        return selection.withLock { $0 }
    }

    package init(preferredLanguages: [String] = Locale.preferredLanguages) {
        let automatic = Bundle.preferredLocalizations(from: Self.languages, forPreferences: preferredLanguages).first ?? "en"
        automaticLanguage = automatic
        selection = OSAllocatedUnfairLock(initialState: automatic)
    }

    package func selectLanguage(_ value: String?) {
        let selected = value.map { Self.languages.contains($0) ? $0 : "en" } ?? automaticLanguage
        guard selected != language else { return }
        withMutation(keyPath: \.language) { selection.withLock { $0 = selected } }
    }

    package func string(_ key: String, arguments: [CVarArg] = []) -> String {
        let selected = language
        let value = Self.bundles[selected]!.localizedString(forKey: key, value: key, table: "Localizable")
        guard !arguments.isEmpty else { return value }
        return String(format: value, locale: Locale(identifier: selected), arguments: arguments)
    }
}

package func tr(_ key: String, _ arguments: CVarArg...) -> String {
    Localization.current.string(key, arguments: arguments)
}
