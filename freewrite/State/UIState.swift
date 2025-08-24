import SwiftUI

class UIState: ObservableObject {
    @Published var isFullscreen = false
    @Published var showingSidebar = false
    @Published var showingChatMenu = false
    @Published var didCopyPrompt: Bool = false
    @Published var placeholderText: String = ""
}
