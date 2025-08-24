import SwiftUI

struct BottomBarView: View {
    @EnvironmentObject var appearance: AppearanceSettings
    @EnvironmentObject var timer: TimerState
    @EnvironmentObject var hoverStates: HoverStates
    @EnvironmentObject var uiState: UIState
    @EnvironmentObject var entryManager: EntryManager

    var body: some View {
        HStack {
            FontControlsView()
            Spacer()
            UtilityButtonsView()
        }
        .padding()
        .background(
            Color(
                appearance.colorScheme == .light ? .white : .black
            )
        )
        .opacity(uiState.bottomNavOpacity)
        .onHover { hovering in
            hoverStates.isHoveringBottomNav = hovering
            if hovering {
                withAnimation(.easeOut(duration: 0.2)) {
                    uiState.bottomNavOpacity = 1.0
                }
            } else if timer.timerIsRunning {
                withAnimation(.easeIn(duration: 1.0)) {
                    uiState.bottomNavOpacity = 0.0
                }
            }
        }
    }
}

struct FontControlsView: View {
    @EnvironmentObject var appearance: AppearanceSettings
    @EnvironmentObject var hoverStates: HoverStates

    var body: some View {
        HStack(spacing: 8) {
            Button(fontSizeButtonTitle) {
                if let currentIndex = Constants.fontSizes.firstIndex(
                    of: appearance.fontSize
                ) {
                    let nextIndex =
                        (currentIndex + 1) % Constants.fontSizes.count
                    appearance.fontSize = Constants.fontSizes[nextIndex]
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(
                hoverStates.isHoveringSize
                    ? appearance.primaryActionColor
                    : appearance.secondaryTextColor
            )
            .onHover { hovering in
                hoverStates.isHoveringSize = hovering
                hoverStates.isHoveringBottomNav = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }

            Text("•")
                .foregroundColor(.gray)

            Button("Lato") {
                appearance.selectedFont = "Lato-Regular"
                appearance.currentRandomFont = ""
            }
            .buttonStyle(.plain)
            .foregroundColor(
                hoverStates.hoveredFont == "Lato"
                    ? appearance.primaryActionColor
                    : appearance.secondaryTextColor
            )
            .onHover { hovering in
                hoverStates.hoveredFont =
                    hovering ? "Lato" : nil
                hoverStates.isHoveringBottomNav = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }

            Text("•")
                .foregroundColor(.gray)

            Button("Palatino") {
                appearance.selectedFont = "Palatino"
                appearance.currentRandomFont = ""
            }
            .buttonStyle(.plain)
            .foregroundColor(
                hoverStates.hoveredFont == "Palatino"
                    ? appearance.primaryActionColor
                    : appearance.secondaryTextColor
            )
            .onHover { hovering in
                hoverStates.hoveredFont =
                    hovering ? "Palatino" : nil
                hoverStates.isHoveringBottomNav = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }

            Text("•")
                .foregroundColor(.gray)

            Button("System") {
                appearance.selectedFont = ".AppleSystemUIFont"
                appearance.currentRandomFont = ""
            }
            .buttonStyle(.plain)
            .foregroundColor(
                hoverStates.hoveredFont == "System"
                    ? appearance.primaryActionColor
                    : appearance.secondaryTextColor
            )
            .onHover { hovering in
                hoverStates.hoveredFont =
                    hovering ? "System" : nil
                hoverStates.isHoveringBottomNav = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }

            Text("•")
                .foregroundColor(.gray)

            Button("Serif") {
                appearance.selectedFont = "Times New Roman"
                appearance.currentRandomFont = ""
            }
            .buttonStyle(.plain)
            .foregroundColor(
                hoverStates.hoveredFont == "Serif"
                    ? appearance.primaryActionColor
                    : appearance.secondaryTextColor
            )
            .onHover { hovering in
                hoverStates.hoveredFont =
                    hovering ? "Serif" : nil
                hoverStates.isHoveringBottomNav = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }

            Text("•")
                .foregroundColor(.gray)

            Button(randomButtonTitle) {
                if let randomFont =
                    Constants.availableFonts.randomElement()
                {
                    appearance.selectedFont = randomFont
                    appearance.currentRandomFont = randomFont
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(
                hoverStates.hoveredFont == "Random"
                    ? appearance.primaryActionColor
                    : appearance.secondaryTextColor
            )
            .onHover { hovering in
                hoverStates.hoveredFont =
                    hovering ? "Random" : nil
                hoverStates.isHoveringBottomNav = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
        .padding(8)
        .cornerRadius(6)
        .onHover { hovering in
            hoverStates.isHoveringBottomNav = hovering
        }
    }

    private var fontSizeButtonTitle: String {
        return "\(Int(appearance.fontSize))px"
    }

    private var randomButtonTitle: String {
        return appearance.currentRandomFont.isEmpty
            ? "Random" : "Random [\(appearance.currentRandomFont)]"
    }
}

struct UtilityButtonsView: View {
    @EnvironmentObject var appearance: AppearanceSettings
    @EnvironmentObject var timer: TimerState
    @EnvironmentObject var hoverStates: HoverStates
    @EnvironmentObject var uiState: UIState
    @EnvironmentObject var entryManager: EntryManager

    var body: some View {
        HStack(spacing: 8) {
            TimerButton()
            Text("•")
                .foregroundColor(.gray)
            ChatButton()
            Text("•")
                .foregroundColor(.gray)
            FullscreenButton()
            Text("•")
                .foregroundColor(.gray)
            NewEntryButton()
            Text("•")
                .foregroundColor(.gray)
            ThemeToggleButton()
            Text("•")
                .foregroundColor(.gray)
            HistoryButton()
        }
        .padding(8)
        .cornerRadius(6)
        .onHover { hovering in
            hoverStates.isHoveringBottomNav = hovering
        }
    }
}

struct TimerButton: View {
    @EnvironmentObject var timer: TimerState
    @EnvironmentObject var hoverStates: HoverStates
    @EnvironmentObject var appearance: AppearanceSettings

    var body: some View {
        Button(timerButtonTitle) {
            let now = Date()
            if let lastClick = timer.lastClickTime,
                now.timeIntervalSince(lastClick) < 0.3
            {
                timer.timeRemaining = 900
                timer.timerIsRunning = false
                timer.lastClickTime = nil
            } else {
                timer.timerIsRunning.toggle()
                timer.lastClickTime = now
            }
        }
        .buttonStyle(.plain)
        .foregroundColor(timerColor)
        .onHover { hovering in
            hoverStates.isHoveringTimer = hovering
            hoverStates.isHoveringBottomNav = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onAppear {
            NSEvent.addLocalMonitorForEvents(
                matching: .scrollWheel
            ) { event in
                if hoverStates.isHoveringTimer {
                    let scrollBuffer = event.deltaY * 0.25

                    if abs(scrollBuffer) >= 0.1 {
                        let currentMinutes =
                            timer.timeRemaining / 60
                        NSHapticFeedbackManager
                            .defaultPerformer.perform(
                                .generic,
                                performanceTime: .now
                            )
                        let direction =
                            -scrollBuffer > 0 ? 5 : -5
                        let newMinutes =
                            currentMinutes + direction
                        let roundedMinutes =
                            (newMinutes / 5) * 5
                        let newTime = roundedMinutes * 60
                        timer.timeRemaining = min(
                            max(newTime, 0),
                            2700
                        )
                    }
                }
                return event
            }
        }
    }

    private var timerButtonTitle: String {
        if !timer.timerIsRunning && timer.timeRemaining == 900 {
            return "15:00"
        }
        let minutes = timer.timeRemaining / 60
        let seconds = timer.timeRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var timerColor: Color {
        if timer.timerIsRunning {
            return hoverStates.isHoveringTimer
                ? appearance.primaryActionColor : .gray.opacity(0.8)
        } else {
            return hoverStates.isHoveringTimer
                ? appearance.primaryActionColor : appearance.secondaryTextColor
        }
    }
}

struct ChatButton: View {
    @EnvironmentObject var uiState: UIState
    @EnvironmentObject var hoverStates: HoverStates
    @EnvironmentObject var appearance: AppearanceSettings
    @EnvironmentObject var entryManager: EntryManager

    var body: some View {
        Button("Chat") {
            uiState.showingChatMenu = true
            // Ensure didCopyPrompt is reset when opening the menu
            uiState.didCopyPrompt = false
        }
        .buttonStyle(.plain)
        .foregroundColor(
            hoverStates.isHoveringChat
                ? appearance.primaryActionColor
                : appearance.secondaryTextColor
        )
        .onHover { hovering in
            hoverStates.isHoveringChat = hovering
            hoverStates.isHoveringBottomNav = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .popover(
            isPresented: $uiState.showingChatMenu,
            attachmentAnchor: .point(
                UnitPoint(x: 0.5, y: 0)
            ),
            arrowEdge: .top
        ) {
            ChatPopoverView()
        }
    }
}

struct FullscreenButton: View {
    @EnvironmentObject var uiState: UIState
    @EnvironmentObject var hoverStates: HoverStates
    @EnvironmentObject var appearance: AppearanceSettings

    var body: some View {
        Button(
            uiState.isFullscreen ? "Minimize" : "Fullscreen"
        ) {
            if let window = NSApplication.shared.windows
                .first
            {
                window.toggleFullScreen(nil)
            }
        }
        .buttonStyle(.plain)
        .foregroundColor(
            hoverStates.isHoveringFullscreen
                ? appearance.primaryActionColor
                : appearance.secondaryTextColor
        )
        .onHover { hovering in
            hoverStates.isHoveringFullscreen = hovering
            hoverStates.isHoveringBottomNav = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

struct NewEntryButton: View {
    @EnvironmentObject var entryManager: EntryManager
    @EnvironmentObject var hoverStates: HoverStates
    @EnvironmentObject var appearance: AppearanceSettings

    var body: some View {
        Button(action: {
            entryManager.createNewEntry()
        }) {
            Text("New Entry")
                .font(.system(size: 13))
        }
        .buttonStyle(.plain)
        .foregroundColor(
            hoverStates.isHoveringNewEntry
                ? appearance.primaryActionColor
                : appearance.secondaryTextColor
        )
        .onHover { hovering in
            hoverStates.isHoveringNewEntry = hovering
            hoverStates.isHoveringBottomNav = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

struct ThemeToggleButton: View {
    @EnvironmentObject var appearance: AppearanceSettings
    @EnvironmentObject var hoverStates: HoverStates

    var body: some View {
        Button(action: {
            appearance.colorScheme =
                appearance.colorScheme == .light
                ? .dark : .light
            // Save preference
            UserDefaults.standard.set(
                appearance.colorScheme == .light
                    ? "light" : "dark",
                forKey: "colorScheme"
            )
        }) {
            Image(
                systemName: appearance.colorScheme == .light
                    ? "moon.fill" : "sun.max.fill"
            )
            .foregroundColor(
                hoverStates.isHoveringThemeToggle
                    ? appearance.primaryActionColor
                    : appearance.secondaryTextColor
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoverStates.isHoveringThemeToggle = hovering
            hoverStates.isHoveringBottomNav = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

struct HistoryButton: View {
    @EnvironmentObject var uiState: UIState
    @EnvironmentObject var hoverStates: HoverStates
    @EnvironmentObject var appearance: AppearanceSettings

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                uiState.showingSidebar.toggle()
            }
        }) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(
                    hoverStates.isHoveringClock
                        ? appearance.primaryActionColor
                        : appearance.secondaryTextColor
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoverStates.isHoveringClock = hovering
            hoverStates.isHoveringBottomNav = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
