import SwiftUI

struct BottomBarView: View {
    @EnvironmentObject var appearance: AppearanceSettings
    @EnvironmentObject var timer: TimerState
    @EnvironmentObject var hoverStates: HoverStates
    @EnvironmentObject var uiState: UIState
    @EnvironmentObject var entryManager: EntryManager

    private var bottomNavOpacity: Double {
        if hoverStates.isHoveringBottomNav || !timer.timerIsRunning {
            return 1.0
        } else {
            return 0.0
        }
    }

    var body: some View {
        HStack {
            FontSelectionView()
            Spacer()
            UtilityButtonsView()
        }
        .padding(.bottom, 16)
        .padding(.horizontal)
        .background(
            Color(
                appearance.colorScheme == .light ? .white : .black
            )
        )
        .opacity(bottomNavOpacity)
        .onHover { hovering in
            hoverStates.isHoveringBottomNav = hovering
        }
        .animation(.easeIn(duration: 0.2), value: bottomNavOpacity)
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
            HistoryButton()
        }
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
        .padding(8)
        .foregroundColor(timerColor)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
                .scaleEffect(hoverStates.isHoveringTimer ? 1.1 : 1.0)
                .animation(.spring(), value: hoverStates.isHoveringTimer)
        )
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
        .padding(8)
        .foregroundColor(
            hoverStates.isHoveringChat
                ? appearance.primaryActionColor
                : appearance.secondaryTextColor
        )
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
                .scaleEffect(hoverStates.isHoveringChat ? 1.1 : 1.0)
                .animation(.spring(), value: hoverStates.isHoveringChat)
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
        .padding(8)
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
                .scaleEffect(hoverStates.isHoveringClock ? 1.1 : 1.0)
                .animation(.spring(), value: hoverStates.isHoveringClock)
        )
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
