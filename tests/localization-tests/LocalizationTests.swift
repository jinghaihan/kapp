import Foundation
import Testing
import Observation
import os
@testable import KappLocalization

struct LocalizationTests {
    @Test func manualSelectionUpdatesTheInterfaceAndCanReturnToAutomatic() {
        let localization = Localization(preferredLanguages: ["ja-JP"])
        let changed = OSAllocatedUnfairLock(initialState: false)
        withObservationTracking {
            _ = localization.string("Preferences")
        } onChange: {
            changed.withLock { $0 = true }
        }
        localization.selectLanguage("zh-Hant")
        #expect(changed.withLock { $0 })
        #expect(localization.string("Preferences") == "偏好設定")
        localization.selectLanguage("ko")
        #expect(localization.string("Preferences") == "환경설정")
        localization.selectLanguage(nil)
        #expect(localization.string("Preferences") == "環境設定")
        localization.selectLanguage("fr")
        #expect(localization.string("Preferences") == "Preferences")
    }

    @Test func languagePreferencesMatchRegionalVariantsAndFallBackToEnglish() {
        let cases: [([String], String)] = [
            (["zh-CN"], "zh-Hans"), (["zh-SG"], "zh-Hans"), (["zh-Hans-CN"], "zh-Hans"),
            (["zh-TW"], "zh-Hant"), (["zh-HK"], "zh-Hant"), (["zh-MO"], "zh-Hant"),
            (["ja-JP"], "ja"), (["ko-KR"], "ko"), (["en-US"], "en"), (["en-GB"], "en"),
            (["fr-FR", "de-DE"], "en"), (["fr-FR", "ja-JP"], "ja"), ([], "en")
        ]
        for (preferences, expected) in cases {
            #expect(Localization(preferredLanguages: preferences).language == expected, "Preferences: \(preferences)")
        }
    }

    @Test func everyLanguageProvidesTheCompleteCatalogAndMatchingFormatArguments() throws {
        let english = try table("en")
        #expect(english.count > 80)
        #expect(Set(Localization.resources.localizations.map { $0.lowercased() }) == Set(Localization.languages.map { $0.lowercased() }))
        for language in Localization.languages {
            let translated = try table(language)
            #expect(Set(translated.keys) == Set(english.keys), "Language: \(language)")
            for (key, value) in translated {
                #expect(!value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                #expect(value.components(separatedBy: "%@").count == key.components(separatedBy: "%@").count,
                        "Format arguments differ: \(language), \(key)")
            }
            let info = try table(language, name: "InfoPlist")
            #expect(Set(info.keys) == ["NSScreenCaptureUsageDescription", "NSMicrophoneUsageDescription"])
            #expect(info.values.allSatisfy { !$0.isEmpty })
        }
    }

    @Test func translationsAndFormattedErrorsLoadFromTheResourceBundle() {
        let expected = ["en": "Preferences", "zh-Hans": "偏好设置", "zh-Hant": "偏好設定", "ja": "環境設定", "ko": "환경설정"]
        for language in Localization.languages {
            let localization = Localization(preferredLanguages: [language])
            #expect(localization.string("Preferences") == expected[language])
            let error = localization.string("The shortcut %@ is already in use or unavailable. Choose another shortcut.", arguments: ["⇧⌘5"])
            #expect(error.contains("⇧⌘5"))
            #expect(!error.contains("%@"))
        }
    }

    @Test func unsupportedLanguagesAndMissingKeysHaveReadableEnglishFallbacks() {
        let localization = Localization(preferredLanguages: ["fr-FR"])
        #expect(localization.string("Preferences") == "Preferences")
        #expect(localization.string("A future message") == "A future message")
    }

    @Test func everyStaticLocalizationCallHasAnEnglishCatalogEntry() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let files = try #require(FileManager.default.enumerator(at: root.appending(path: "sources"), includingPropertiesForKeys: nil))
        let expression = try NSRegularExpression(pattern: #"tr\("((?:[^"\\]|\\.)*)""#)
        let catalog = try table("en")
        var count = 0
        for case let file as URL in files where file.pathExtension == "swift" {
            let text = try String(contentsOf: file, encoding: .utf8)
            for match in expression.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                let literal = (text as NSString).substring(with: match.range(at: 1))
                let key = try JSONDecoder().decode(String.self, from: Data(("\"" + literal + "\"").utf8))
                #expect(catalog[key] != nil, "Missing key in \(file.lastPathComponent): \(key)")
                count += 1
            }
        }
        #expect(count > 60)
    }

    private func table(_ language: String, name: String = "Localizable") throws -> [String: String] {
        let directory = try #require(Localization.resources.url(forResource: language.lowercased(), withExtension: "lproj"))
        let data = try Data(contentsOf: directory.appending(path: name + ".strings"))
        return try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
    }
}
