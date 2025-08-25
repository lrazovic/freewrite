import SwiftUI

class UIState: ObservableObject {
    @Published var showingSidebar = false
    @Published var showingChatMenu = false
    @Published var didCopyPrompt: Bool = false
    @Published var placeholderText: String = Constants.placeholderOptions.randomElement() ?? "Begin writing"
}
