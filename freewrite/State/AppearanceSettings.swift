
import SwiftUI

class AppearanceSettings: ObservableObject {
    @Published var selectedFont: String = "Palatino"
    @Published var currentRandomFont: String = ""
    @Published var fontSize: CGFloat = 18
    @Published var colorScheme: ColorScheme = .light

    // Theme colors computed properties (DRY principle)
    var backgroundColor: Color {
        colorScheme == .light ? .white : .black
    }

    var textColor: Color {
        colorScheme == .light
            ? Color(red: 0.20, green: 0.20, blue: 0.20)
            : Color(red: 0.9, green: 0.9, blue: 0.9)
    }

    var placeholderTextColor: Color {
        colorScheme == .light ? .gray.opacity(0.5) : .gray.opacity(0.6)
    }

    var primaryActionColor: Color {
        colorScheme == .light ? .black : .white
    }

    var secondaryTextColor: Color {
        colorScheme == .light ? .gray : .gray.opacity(0.8)
    }

    var popoverBackgroundColor: Color {
        colorScheme == .light
            ? Color(NSColor.controlBackgroundColor) : Color(NSColor.darkGray)
    }

    var popoverTextColor: Color {
        colorScheme == .light ? Color.primary : Color.white
    }

    init() {
        // Load saved color scheme preference
        let savedScheme =
            UserDefaults.standard.string(forKey: "colorScheme") ?? "light"
        colorScheme = savedScheme == "dark" ? .dark : .light
    }
}
