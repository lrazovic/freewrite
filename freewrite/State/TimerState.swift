
import Foundation

class TimerState: ObservableObject {
    @Published var timeRemaining: Int = 900  // 15 minutes
    @Published var timerIsRunning = false
    @Published var lastClickTime: Date? = nil
}
