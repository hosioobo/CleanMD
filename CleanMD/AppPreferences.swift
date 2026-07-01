import Foundation

enum AppPreferenceKeys {
    static let isDarkMode = "isDarkMode"
    static let editorPreviewPanelMode = "editorPreviewPanelMode"
    static let isScrollSyncLinked = "isScrollSyncLinked"
    static let isAppearanceInspectorVisible = "isAppearanceInspectorVisible"
    static let appearanceInspectorWidth = "appearanceInspectorWidth"
}

enum AppPreferences {
    static func scrollSyncIsLinked(defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: AppPreferenceKeys.isScrollSyncLinked) != nil else {
            return true
        }
        return defaults.bool(forKey: AppPreferenceKeys.isScrollSyncLinked)
    }
}
