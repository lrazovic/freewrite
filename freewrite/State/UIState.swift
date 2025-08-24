import SwiftUI

class UIState: ObservableObject {
    @Published var isFullscreen = false
    @Published var showingSidebar = false
    @Published var showingChatMenu = false
    @Published var chatMenuAnchor: CGPoint = .zero
    @Published var bottomNavOpacity: Double = 1.0
    @Published var didCopyPrompt: Bool = false
    @Published var placeholderText: String = ""
    @Published var scrollOffset: CGFloat = 0
    @Published var viewHeight: CGFloat = 0
}
