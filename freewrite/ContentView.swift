import SwiftUI

struct ContentView: View {
    // MARK: - State Objects
    @StateObject private var appearance = AppearanceSettings()
    @StateObject private var timer = TimerState()
    @StateObject private var hoverStates = HoverStates()
    @StateObject private var uiState = UIState()
    @StateObject private var entryManager = EntryManager()

    // MARK: - Constants
    private let systemTimer = Timer.publish(every: 1, on: .main, in: .common)
        .autoconnect()

    var body: some View {
        HStack(spacing: 0) {
            // Main content
            ZStack {
                appearance.backgroundColor
                    .ignoresSafeArea()

                VStack(spacing: 2) {
                    Spacer()
                        .frame(height: abs(lineHeight * 8))

                    EditorView(text: $entryManager.text)

                    // Bottom spacing for nav area
                    Spacer()
                        .frame(height: 64)
                }

                VStack {
                    Spacer()
                    BottomBarView()
                }
            }

            // Right sidebar
            if uiState.showingSidebar {
                Divider()
                SidebarView()
            }
        }
        .frame(minWidth: 1100, minHeight: 600)
        .animation(.easeInOut(duration: 0.16), value: uiState.showingSidebar)
        .preferredColorScheme(appearance.colorScheme)
        .environmentObject(appearance)
        .environmentObject(timer)
        .environmentObject(hoverStates)
        .environmentObject(uiState)
        .environmentObject(entryManager)
        .onAppear {
            uiState.showingSidebar = false  // Hide sidebar by default
            
            // Create new entry if this is a new window (more than 1 window exists)
            if NSApplication.shared.windows.count > 1 {
                entryManager.createNewEntry()
            }
        }
        .onChange(of: entryManager.text) { oldValue, newValue in
            if let currentId = entryManager.selectedEntryId,
                let currentEntry = entryManager.entries.first(where: {
                    $0.id == currentId
                })
            {
                entryManager.debouncedSave(entry: currentEntry)
            }
        }
        .onReceive(systemTimer) { _ in
            if timer.timerIsRunning && timer.timeRemaining > 0 {
                timer.timeRemaining -= 1
            } else if timer.timeRemaining == 0 {
                timer.timerIsRunning = false
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSWindow.willEnterFullScreenNotification
            )
        ) { _ in
            uiState.isFullscreen = true
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSWindow.willExitFullScreenNotification
            )
        ) { _ in
            uiState.isFullscreen = false
        }
    }

    private var lineHeight: CGFloat {
        let font =
            NSFont(name: appearance.selectedFont, size: appearance.fontSize)
            ?? .systemFont(ofSize: appearance.fontSize)
        let defaultLineHeight = font.ascender - font.descender + font.leading
        return (appearance.fontSize * 1.5) - defaultLineHeight
    }
}

#Preview {
    ContentView()
}
