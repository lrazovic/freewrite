
import SwiftUI

class HoverStates: ObservableObject {
    @Published var isHoveringTimer = false
    @Published var isHoveringFullscreen = false
    @Published var hoveredFont: String? = nil
    @Published var isHoveringSize = false
    @Published var isHoveringBottomNav = false
    @Published var isHoveringChat = false
    @Published var isHoveringNewEntry = false
    @Published var isHoveringClock = false
    @Published var isHoveringHistory = false
    @Published var isHoveringHistoryText = false
    @Published var isHoveringHistoryPath = false
    @Published var isHoveringHistoryArrow = false
    @Published var isHoveringThemeToggle = false
    @Published var hoveredEntryId: UUID? = nil
    @Published var hoveredTrashId: UUID? = nil
    @Published var hoveredExportId: UUID? = nil
}
