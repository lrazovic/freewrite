// Swift 6.0
//
//  ContentView.swift
//  freewrite
//
//  Created by thorfinn on 2/14/25.
//  Modified by Leonardo Razovic later on.
//

import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - State Management Classes

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

class TimerState: ObservableObject {
    @Published var timeRemaining: Int = 900  // 15 minutes
    @Published var timerIsRunning = false
    @Published var lastClickTime: Date? = nil
}

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

@MainActor
class EntryManager: ObservableObject {
    @Published var entries: [HumanEntry] = []
    @Published var selectedEntryId: UUID? = nil
    @Published var text: String = ""

    private var debounceTimer: Timer?
    private let fileManager = FileManager.default

    func saveEntry(entry: HumanEntry) {
        Task.detached {
            await self.saveEntryAsync(entry: entry)
        }
    }

    func debouncedSave(entry: HumanEntry) {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: false
        ) { _ in
            Task.detached {
                await self.saveEntryAsync(entry: entry)
            }
        }
    }

    func saveEntryAsync(entry: HumanEntry) async {
        let textToSave = await MainActor.run { text }

        do {
            // Perform file I/O on background thread
            try textToSave.write(
                to: entry.fileURL,
                atomically: true,
                encoding: .utf8
            )
            print("Successfully saved entry: \(entry.filename)")

            // Generate preview on background thread
            let preview =
                textToSave
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let truncated =
                preview.isEmpty
                ? ""
                : (preview.count > 30
                    ? String(preview.prefix(30)) + "..." : preview)

            // Update UI on main thread
            await MainActor.run {
                if let index = entries.firstIndex(where: { $0.id == entry.id })
                {
                    entries[index].previewText = truncated
                }
            }
        } catch {
            print("Error saving entry: \(error)")
        }
    }
}

struct HumanEntry: Identifiable {
    let id: UUID
    let date: String
    let filename: String
    let fileURL: URL
    let modificationDate: Date
    var previewText: String?  // nil means not loaded yet
    var isPreviewLoading: Bool = false

    static func createNew() -> HumanEntry {
        let id = UUID()
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let dateString = dateFormatter.string(from: now)

        // For display
        dateFormatter.dateFormat = "MMM d"
        let displayDate = dateFormatter.string(from: now)

        let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("Freewrite")
        let filename = "[\(id)]-[\(dateString)].md"

        return HumanEntry(
            id: id,
            date: displayDate,
            filename: filename,
            fileURL: documentsDirectory.appendingPathComponent(filename),
            modificationDate: now,
            previewText: nil
        )
    }
}

struct HeartEmoji: Identifiable {
    let id = UUID()
    var position: CGPoint
    var offset: CGFloat = 0
}

struct ContentView: View {
    // MARK: - State Objects
    @StateObject private var appearance = AppearanceSettings()
    @StateObject private var timer = TimerState()
    @StateObject private var hoverStates = HoverStates()
    @StateObject private var uiState = UIState()
    @StateObject private var entryManager = EntryManager()

    // MARK: - Constants
    private let headerString = "\n\n"
    private let systemTimer = Timer.publish(every: 1, on: .main, in: .common)
        .autoconnect()
    private let entryHeight: CGFloat = 40

    private let availableFonts = NSFontManager.shared.availableFontFamilies
    private let standardFonts = [
        "Lato-Regular", "Arial", ".AppleSystemUIFont", "Palatino",
    ]
    private let fontSizes: [CGFloat] = [16, 18, 20, 22, 24, 26]
    private let placeholderOptions = [
        "Begin writing",
        "Pick a thought and go",
        "Start typing",
        "What's on your mind",
        "Just start",
        "Type your first thought",
        "Start with one sentence",
        "Just say it",
    ]

    // Add file manager
    private let fileManager = FileManager.default

    // Add cached documents directory
    private let documentsDirectory: URL = {
        let directory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("Freewrite")

        // Create Freewrite directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true
                )
                print("Successfully created Freewrite directory")
            } catch {
                print("Error creating directory: \(error)")
            }
        }

        return directory
    }()

    // Add shared prompt constant
    private let aiChatPrompt = """
        below is my journal entry. wyt? talk through it with me like a friend. don't therpaize me and give me a whole breakdown, don't repeat my thoughts with headings. really take all of this, and tell me back stuff truly as if you're an old homie.

        Keep it casual, dont say yo, help me make new connections i don't see, comfort, validate, challenge, all of it. dont be afraid to say a lot. format with markdown headings if needed.

        do not just go through every single thing i say, and say it back to me. you need to proccess everythikng is say, make connections i don't see it, and deliver it all back to me as a story that makes me feel what you think i wanna feel. thats what the best therapists do.

        ideally, you're style/tone should sound like the user themselves. it's as if the user is hearing their own tone but it should still feel different, because you have different things to say and don't just repeat back they say.

        else, start by saying, "hey, thanks for showing me this. my thoughts:"
            
        my entry:
        """

    private let claudePrompt = """
        Take a look at my journal entry below. I'd like you to analyze it and respond with deep insight that feels personal, not clinical.
        Imagine you're not just a friend, but a mentor who truly gets both my tech background and my psychological patterns. I want you to uncover the deeper meaning and emotional undercurrents behind my scattered thoughts.
        Keep it casual, dont say yo, help me make new connections i don't see, comfort, validate, challenge, all of it. dont be afraid to say a lot. format with markdown headings if needed.
        Use vivid metaphors and powerful imagery to help me see what I'm really building. Organize your thoughts with meaningful headings that create a narrative journey through my ideas.
        Don't just validate my thoughts - reframe them in a way that shows me what I'm really seeking beneath the surface. Go beyond the product concepts to the emotional core of what I'm trying to solve.
        Be willing to be profound and philosophical without sounding like you're giving therapy. I want someone who can see the patterns I can't see myself and articulate them in a way that feels like an epiphany.
        Start with 'hey, thanks for showing me this. my thoughts:' and then use markdown headings to structure your response.

        Here's my journal entry:
        """

    // Modify getDocumentsDirectory to use cached value
    private func getDocumentsDirectory() -> URL {
        return documentsDirectory
    }

    // Add function to load existing entries (metadata only)
    private func loadExistingEntries() {
        let documentsDirectory = getDocumentsDirectory()
        print("Looking for entries in: \(documentsDirectory.path)")

        do {
            // Load file metadata including modification dates
            let resourceKeys: [URLResourceKey] = [
                .contentModificationDateKey, .fileSizeKey,
            ]
            let fileURLs = try fileManager.contentsOfDirectory(
                at: documentsDirectory,
                includingPropertiesForKeys: resourceKeys
            )
            let mdFiles = fileURLs.filter { $0.pathExtension == "md" }

            print("Found \(mdFiles.count) .md files")

            // Process each file (metadata only)
            let entriesWithDates = mdFiles.compactMap {
                fileURL -> (entry: HumanEntry, date: Date)? in
                let filename = fileURL.lastPathComponent
                print("Processing metadata for: \(filename)")

                // Extract UUID and date from filename - pattern [uuid]-[yyyy-MM-dd-HH-mm-ss].md
                guard
                    let uuidMatch = filename.range(
                        of: "\\[(.*?)\\]",
                        options: .regularExpression
                    ),
                    let dateMatch = filename.range(
                        of: "\\[(\\d{4}-\\d{2}-\\d{2}-\\d{2}-\\d{2}-\\d{2})\\]",
                        options: .regularExpression
                    ),
                    let uuid = UUID(
                        uuidString: String(
                            filename[uuidMatch].dropFirst().dropLast()
                        )
                    )
                else {
                    print(
                        "Failed to extract UUID or date from filename: \(filename)"
                    )
                    return nil
                }

                // Get modification date from file system
                do {
                    let resourceValues = try fileURL.resourceValues(
                        forKeys: Set(resourceKeys)
                    )
                    let modificationDate =
                        resourceValues.contentModificationDate ?? Date()

                    // Parse the date string for display
                    let dateString = String(
                        filename[dateMatch].dropFirst().dropLast()
                    )
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"

                    guard let fileDate = dateFormatter.date(from: dateString)
                    else {
                        print("Failed to parse date from filename: \(filename)")
                        return nil
                    }

                    // Format display date
                    dateFormatter.dateFormat = "MMM d"
                    let displayDate = dateFormatter.string(from: fileDate)

                    return (
                        entry: HumanEntry(
                            id: uuid,
                            date: displayDate,
                            filename: filename,
                            fileURL: fileURL,
                            modificationDate: modificationDate,
                            previewText: nil  // Will be loaded lazily
                        ),
                        date: fileDate
                    )
                } catch {
                    print("Error getting file metadata: \(error)")
                    return nil
                }
            }

            // Sort by modification date (most recent first)
            entryManager.entries =
                entriesWithDates
                .sorted {
                    $0.entry.modificationDate > $1.entry.modificationDate
                }
                .map { $0.entry }

            print(
                "Successfully loaded metadata for \(entryManager.entries.count) entries"
            )

            // Handle entry selection logic
            handleInitialEntrySelection()

        } catch {
            print("Error loading directory contents: \(error)")
            print("Creating default entry after error")
            createNewEntry()
        }
    }

    private func handleInitialEntrySelection() {
        let calendar = Calendar.current
        let today = Date()
        let todayStart = calendar.startOfDay(for: today)

        // Check if there's a recent entry from today
        let todayEntry = entryManager.entries.first { entry in
            let entryDayStart = calendar.startOfDay(for: entry.modificationDate)
            return calendar.isDate(entryDayStart, inSameDayAs: todayStart)
        }

        if entryManager.entries.isEmpty {
            // First time user - create entry with welcome message
            print("First time user, creating welcome entry")
            createNewEntry()
        } else if let todayEntry = todayEntry {
            // Select today's entry
            entryManager.selectedEntryId = todayEntry.id
            loadEntry(entry: todayEntry)
        } else {
            // No entry for today - create new entry
            print("No entry for today, creating new entry")
            createNewEntry()
        }
    }

    var randomButtonTitle: String {
        return appearance.currentRandomFont.isEmpty
            ? "Random" : "Random [\(appearance.currentRandomFont)]"
    }

    var timerButtonTitle: String {
        if !timer.timerIsRunning && timer.timeRemaining == 900 {
            return "15:00"
        }
        let minutes = timer.timeRemaining / 60
        let seconds = timer.timeRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var timerColor: Color {
        if timer.timerIsRunning {
            return hoverStates.isHoveringTimer
                ? appearance.primaryActionColor : .gray.opacity(0.8)
        } else {
            return hoverStates.isHoveringTimer
                ? appearance.primaryActionColor : appearance.secondaryTextColor
        }
    }

    var lineHeight: CGFloat {
        let font =
            NSFont(name: appearance.selectedFont, size: appearance.fontSize)
            ?? .systemFont(ofSize: appearance.fontSize)
        let defaultLineHeight = font.ascender - font.descender + font.leading
        return (appearance.fontSize * 1.5) - defaultLineHeight
    }

    var fontSizeButtonTitle: String {
        return "\(Int(appearance.fontSize))px"
    }

    var body: some View {
        let navHeight: CGFloat = 64

        HStack(spacing: 0) {
            // Main content
            ZStack {
                appearance.backgroundColor
                    .ignoresSafeArea()

                VStack(spacing: 2) {
                    Spacer()
                        .frame(height: abs(lineHeight * 8))

                    TextEditor(text: $entryManager.text)
                        .background(appearance.backgroundColor)
                        .font(
                            .custom(
                                appearance.selectedFont,
                                size: appearance.fontSize
                            )
                        )
                        .foregroundColor(appearance.textColor)
                        .scrollContentBackground(.hidden)
                        .scrollIndicators(.never)
                        .lineSpacing(lineHeight)
                        .frame(maxWidth: 660)
                        .autocorrectionDisabled(false)
                        .colorScheme(appearance.colorScheme)

                    // Bottom spacing for nav area
                    if uiState.bottomNavOpacity > 0 {
                        Spacer()
                            .frame(height: navHeight)
                    }
                }
                .onAppear {
                    uiState.placeholderText =
                        placeholderOptions.randomElement()
                        ?? "Begin writing"
                }
                .overlay(
                    ZStack(alignment: .topLeading) {
                        if entryManager.text.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty {
                            Text(uiState.placeholderText)
                                .font(
                                    .custom(
                                        appearance.selectedFont,
                                        size: appearance.fontSize
                                    )
                                )
                                .foregroundColor(
                                    appearance.placeholderTextColor
                                )
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    uiState.viewHeight = height
                }

                VStack {
                    Spacer()
                    HStack {
                        // Font buttons (moved to left)
                        HStack(spacing: 8) {
                            Button(fontSizeButtonTitle) {
                                if let currentIndex = fontSizes.firstIndex(
                                    of: appearance.fontSize
                                ) {
                                    let nextIndex =
                                        (currentIndex + 1) % fontSizes.count
                                    appearance.fontSize = fontSizes[nextIndex]
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
                                    availableFonts.randomElement()
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

                        Spacer()

                        // Utility buttons (moved to right)
                        HStack(spacing: 8) {
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

                            Text("•")
                                .foregroundColor(.gray)

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
                                VStack(spacing: 0) {  // Wrap everything in a VStack for consistent styling and onChange
                                    let trimmedText = entryManager.text
                                        .trimmingCharacters(
                                            in: .whitespacesAndNewlines
                                        )

                                    // Calculate potential URL lengths
                                    let gptFullText =
                                        aiChatPrompt + "\n\n" + trimmedText
                                    let claudeFullText =
                                        claudePrompt + "\n\n" + trimmedText
                                    let encodedGptText =
                                        gptFullText.addingPercentEncoding(
                                            withAllowedCharacters:
                                                .urlQueryAllowed
                                        ) ?? ""
                                    let encodedClaudeText =
                                        claudeFullText.addingPercentEncoding(
                                            withAllowedCharacters:
                                                .urlQueryAllowed
                                        ) ?? ""

                                    let gptUrlLength =
                                        "https://chat.openai.com/?m=".count
                                        + encodedGptText.count
                                    let claudeUrlLength =
                                        "https://claude.ai/new?q=".count
                                        + encodedClaudeText.count
                                    let isUrlTooLong =
                                        gptUrlLength > 6000
                                        || claudeUrlLength > 6000

                                    if isUrlTooLong {
                                        // View for long text (URL too long)
                                        Text(
                                            "Hey, your entry is long. It'll break the URL. Instead, copy prompt by clicking below and paste into AI of your choice!"
                                        )
                                        .font(.system(size: 14))
                                        .foregroundColor(
                                            appearance.popoverTextColor
                                        )
                                        .lineLimit(nil)
                                        .multilineTextAlignment(.leading)
                                        .frame(width: 200, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)

                                        Divider()

                                        Button(action: {
                                            copyPromptToClipboard()
                                            uiState.didCopyPrompt = true
                                        }) {
                                            Text(
                                                uiState.didCopyPrompt
                                                    ? "Copied!" : "Copy Prompt"
                                            )
                                            .frame(
                                                maxWidth: .infinity,
                                                alignment: .leading
                                            )
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(
                                            appearance.popoverTextColor
                                        )
                                        .onHover { hovering in
                                            if hovering {
                                                NSCursor.pointingHand.push()
                                            } else {
                                                NSCursor.pop()
                                            }
                                        }

                                    } else if entryManager.text
                                        .trimmingCharacters(
                                            in: .whitespacesAndNewlines
                                        ).hasPrefix("hi. my name is farza.")
                                    {
                                        Text(
                                            "Yo. Sorry, you can't chat with the guide lol. Please write your own entry."
                                        )
                                        .font(.system(size: 14))
                                        .foregroundColor(
                                            appearance.popoverTextColor
                                        )
                                        .frame(width: 250)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                    } else if entryManager.text.count < 350 {
                                        Text(
                                            "Please free write for at minimum 5 minutes first. Then click this. Trust."
                                        )
                                        .font(.system(size: 14))
                                        .foregroundColor(
                                            appearance.popoverTextColor
                                        )
                                        .frame(width: 250)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                    } else {
                                        // View for normal text length
                                        Button(action: {
                                            uiState.showingChatMenu = false
                                            openChatGPT()
                                        }) {
                                            Text("ChatGPT")
                                                .frame(
                                                    maxWidth: .infinity,
                                                    alignment: .leading
                                                )
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(
                                            appearance.popoverTextColor
                                        )
                                        .onHover { hovering in
                                            if hovering {
                                                NSCursor.pointingHand.push()
                                            } else {
                                                NSCursor.pop()
                                            }
                                        }

                                        Divider()

                                        Button(action: {
                                            uiState.showingChatMenu = false
                                            openClaude()
                                        }) {
                                            Text("Claude")
                                                .frame(
                                                    maxWidth: .infinity,
                                                    alignment: .leading
                                                )
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(
                                            appearance.popoverTextColor
                                        )
                                        .onHover { hovering in
                                            if hovering {
                                                NSCursor.pointingHand.push()
                                            } else {
                                                NSCursor.pop()
                                            }
                                        }

                                        Divider()

                                        Button(action: {
                                            // Don't dismiss menu, just copy and update state
                                            copyPromptToClipboard()
                                            uiState.didCopyPrompt = true
                                        }) {
                                            Text(
                                                uiState.didCopyPrompt
                                                    ? "Copied!" : "Copy Prompt"
                                            )
                                            .frame(
                                                maxWidth: .infinity,
                                                alignment: .leading
                                            )
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(
                                            appearance.popoverTextColor
                                        )
                                        .onHover { hovering in
                                            if hovering {
                                                NSCursor.pointingHand.push()
                                            } else {
                                                NSCursor.pop()
                                            }
                                        }
                                    }
                                }
                                .frame(minWidth: 120, maxWidth: 250)  // Allow width to adjust
                                .background(appearance.popoverBackgroundColor)
                                .cornerRadius(8)
                                .shadow(
                                    color: Color.black.opacity(0.1),
                                    radius: 4,
                                    y: 2
                                )
                                // Reset copied state when popover dismisses
                                .onChange(of: uiState.showingChatMenu) {
                                    oldValue,
                                    newValue in
                                    if !newValue {
                                        uiState.didCopyPrompt = false
                                    }
                                }
                            }

                            Text("•")
                                .foregroundColor(.gray)

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

                            Text("•")
                                .foregroundColor(.gray)

                            Button(action: {
                                createNewEntry()
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

                            Text("•")
                                .foregroundColor(.gray)

                            // Theme toggle button
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

                            Text("•")
                                .foregroundColor(.gray)

                            // Version history button
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
                        .padding(8)
                        .cornerRadius(6)
                        .onHover { hovering in
                            hoverStates.isHoveringBottomNav = hovering
                        }
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

            // Right sidebar
            if uiState.showingSidebar {
                Divider()

                VStack(spacing: 0) {
                    // Header
                    Button(action: {
                        NSWorkspace.shared.selectFile(
                            nil,
                            inFileViewerRootedAtPath: getDocumentsDirectory()
                                .path
                        )
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Text("History")
                                        .font(.system(size: 13))
                                        .foregroundColor(
                                            hoverStates.isHoveringHistory
                                                ? appearance.primaryActionColor
                                                : appearance.secondaryTextColor
                                        )
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 10))
                                        .foregroundColor(
                                            hoverStates.isHoveringHistory
                                                ? appearance.primaryActionColor
                                                : appearance.secondaryTextColor
                                        )
                                }
                                Text(getDocumentsDirectory().path)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .onHover { hovering in
                        hoverStates.isHoveringHistory = hovering
                    }

                    Divider()

                    // Entries List
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(entryManager.entries) { entry in
                                Button(action: {
                                    if entryManager.selectedEntryId != entry.id
                                    {
                                        // Save current entry before switching
                                        if let currentId = entryManager
                                            .selectedEntryId,
                                            let currentEntry = entryManager
                                                .entries.first(where: {
                                                    $0.id == currentId
                                                })
                                        {
                                            // Save immediately with current text content
                                            Task {
                                                await entryManager
                                                    .saveEntryAsync(
                                                        entry: currentEntry
                                                    )
                                                // Only switch after saving is complete
                                                await MainActor.run {
                                                    entryManager
                                                        .selectedEntryId =
                                                        entry.id
                                                    loadEntry(entry: entry)
                                                }
                                            }
                                        } else {
                                            // No current entry to save, switch immediately
                                            entryManager.selectedEntryId =
                                                entry.id
                                            loadEntry(entry: entry)
                                        }
                                    }
                                }) {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 4)
                                        {
                                            HStack {
                                                if entry.isPreviewLoading {
                                                    Text("Loading...")
                                                        .font(.system(size: 13))
                                                        .lineLimit(1)
                                                        .foregroundColor(
                                                            .secondary
                                                        )
                                                } else {
                                                    Text(
                                                        entry.previewText ?? ""
                                                    )
                                                    .font(.system(size: 13))
                                                    .lineLimit(1)
                                                    .foregroundColor(.primary)
                                                }

                                                Spacer()

                                                // Export/Trash icons that appear on hover
                                                if hoverStates.hoveredEntryId
                                                    == entry.id
                                                {
                                                    HStack(spacing: 8) {
                                                        // Export PDF button
                                                        Button(action: {
                                                            exportEntryAsPDF(
                                                                entry: entry
                                                            )
                                                        }) {
                                                            Image(
                                                                systemName:
                                                                    "arrow.down.circle"
                                                            )
                                                            .font(
                                                                .system(
                                                                    size: 11
                                                                )
                                                            )
                                                            .foregroundColor(
                                                                hoverStates
                                                                    .hoveredExportId
                                                                    == entry.id
                                                                    ? (appearance
                                                                        .colorScheme
                                                                        == .light
                                                                        ? .black
                                                                        : .white)
                                                                    : (appearance
                                                                        .colorScheme
                                                                        == .light
                                                                        ? .gray
                                                                        : .gray
                                                                            .opacity(
                                                                                0.8
                                                                            ))
                                                            )
                                                        }
                                                        .buttonStyle(.plain)
                                                        .help(
                                                            "Export entry as PDF"
                                                        )
                                                        .onHover { hovering in
                                                            withAnimation(
                                                                .easeInOut(
                                                                    duration:
                                                                        0.2
                                                                )
                                                            ) {
                                                                hoverStates
                                                                    .hoveredExportId =
                                                                    hovering
                                                                    ? entry.id
                                                                    : nil
                                                            }
                                                            if hovering {
                                                                NSCursor
                                                                    .pointingHand
                                                                    .push()
                                                            } else {
                                                                NSCursor.pop()
                                                            }
                                                        }

                                                        // Trash icon
                                                        Button(action: {
                                                            deleteEntry(
                                                                entry: entry
                                                            )
                                                        }) {
                                                            Image(
                                                                systemName:
                                                                    "trash"
                                                            )
                                                            .font(
                                                                .system(
                                                                    size: 11
                                                                )
                                                            )
                                                            .foregroundColor(
                                                                hoverStates
                                                                    .hoveredTrashId
                                                                    == entry.id
                                                                    ? .red
                                                                    : .gray
                                                            )
                                                        }
                                                        .buttonStyle(.plain)
                                                        .onHover { hovering in
                                                            withAnimation(
                                                                .easeInOut(
                                                                    duration:
                                                                        0.2
                                                                )
                                                            ) {
                                                                hoverStates
                                                                    .hoveredTrashId =
                                                                    hovering
                                                                    ? entry.id
                                                                    : nil
                                                            }
                                                            if hovering {
                                                                NSCursor
                                                                    .pointingHand
                                                                    .push()
                                                            } else {
                                                                NSCursor.pop()
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            Text(entry.date)
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(backgroundColor(for: entry))
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .contentShape(Rectangle())
                                .onHover { hovering in
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        hoverStates.hoveredEntryId =
                                            hovering ? entry.id : nil
                                    }
                                }
                                .onAppear {
                                    NSCursor.pop()  // Reset cursor when button appears
                                    // Load preview text lazily when entry becomes visible
                                    loadPreviewText(for: entry)
                                }
                                .help("Click to select this entry")  // Add tooltip

                                if entry.id != entryManager.entries.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                    .scrollIndicators(.never)
                }
                .frame(width: 200)
                .background(
                    Color(
                        appearance.colorScheme == .light
                            ? .white : NSColor.black
                    )
                )
            }
        }
        .frame(minWidth: 1100, minHeight: 600)
        .animation(.easeInOut(duration: 0.2), value: uiState.showingSidebar)
        .preferredColorScheme(appearance.colorScheme)
        .onAppear {
            uiState.showingSidebar = false  // Hide sidebar by default
            loadExistingEntries()
        }
        .onChange(of: entryManager.text) { oldValue, newValue in
            // Use the debounced save method from EntryManager
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
                if !hoverStates.isHoveringBottomNav {
                    withAnimation(.easeOut(duration: 1.0)) {
                        uiState.bottomNavOpacity = 1.0
                    }
                }
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

    private func backgroundColor(for entry: HumanEntry) -> Color {
        if entry.id == entryManager.selectedEntryId {
            return Color.gray.opacity(0.1)  // More subtle selection highlight
        } else if entry.id == hoverStates.hoveredEntryId {
            return Color.gray.opacity(0.05)  // Even more subtle hover state
        } else {
            return Color.clear
        }
    }

    private func loadPreviewText(for entry: HumanEntry) {
        // Don't load if already loading or loaded
        guard entry.previewText == nil && !entry.isPreviewLoading else {
            return
        }

        // Mark as loading
        if let index = entryManager.entries.firstIndex(where: {
            $0.id == entry.id
        }) {
            entryManager.entries[index].isPreviewLoading = true
        }

        // Load preview asynchronously
        Task.detached {
            do {
                let content = try String(
                    contentsOf: entry.fileURL,
                    encoding: .utf8
                )
                let preview =
                    content
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let truncated =
                    preview.isEmpty
                    ? ""
                    : (preview.count > 30
                        ? String(preview.prefix(30)) + "..." : preview)

                await MainActor.run {
                    // Find and update the entry in the entries array
                    if let index = entryManager.entries.firstIndex(where: {
                        $0.id == entry.id
                    }) {
                        entryManager.entries[index].previewText = truncated
                        entryManager.entries[index].isPreviewLoading = false
                    }
                }
            } catch {
                print("Error loading preview text: \(error)")
                await MainActor.run {
                    if let index = entryManager.entries.firstIndex(where: {
                        $0.id == entry.id
                    }) {
                        entryManager.entries[index].previewText =
                            "Error loading preview"
                        entryManager.entries[index].isPreviewLoading = false
                    }
                }
            }
        }
    }

    private func saveEntry(entry: HumanEntry) {
        entryManager.saveEntry(entry: entry)
    }

    private func loadEntry(entry: HumanEntry) {
        do {
            if fileManager.fileExists(atPath: entry.fileURL.path) {
                entryManager.text = try String(
                    contentsOf: entry.fileURL,
                    encoding: .utf8
                )
                print("Successfully loaded entry: \(entry.filename)")
            }
        } catch {
            print("Error loading entry: \(error)")
        }
    }

    private func createNewEntry() {
        let newEntry = HumanEntry.createNew()
        entryManager.entries.insert(newEntry, at: 0)  // Add to the beginning
        entryManager.selectedEntryId = newEntry.id

        // If this is the first entry (entries was empty before adding this one)
        if entryManager.entries.count == 1 {
            // Read welcome message from default.md
            if let defaultMessageURL = Bundle.main.url(
                forResource: "default",
                withExtension: "md"
            ),
                let defaultMessage = try? String(
                    contentsOf: defaultMessageURL,
                    encoding: .utf8
                )
            {
                entryManager.text = defaultMessage
            }
            // Save the welcome message immediately
            entryManager.saveEntry(entry: newEntry)
        } else {
            // Regular new entry starts empty
            entryManager.text = ""
            // Randomize placeholder text for new entry
            uiState.placeholderText =
                placeholderOptions.randomElement() ?? "Begin writing"
            // Save the empty entry
            entryManager.saveEntry(entry: newEntry)
        }
    }

    private func openChatGPT() {
        let trimmedText = entryManager.text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let fullText = aiChatPrompt + "\n\n" + trimmedText

        if let encodedText = fullText.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ),
            let url = URL(string: "https://chat.openai.com/?m=" + encodedText)
        {
            NSWorkspace.shared.open(url)
        }
    }

    private func openClaude() {
        let trimmedText = entryManager.text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let fullText = claudePrompt + "\n\n" + trimmedText

        if let encodedText = fullText.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ),
            let url = URL(string: "https://claude.ai/new?q=" + encodedText)
        {
            NSWorkspace.shared.open(url)
        }
    }

    private func copyPromptToClipboard() {
        let trimmedText = entryManager.text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let fullText = aiChatPrompt + "\n\n" + trimmedText

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(fullText, forType: .string)
        print("Prompt copied to clipboard")
    }

    private func deleteEntry(entry: HumanEntry) {
        // Delete the file from the filesystem
        do {
            try fileManager.removeItem(at: entry.fileURL)
            print("Successfully deleted file: \(entry.filename)")

            // Remove the entry from the entries array
            if let index = entryManager.entries.firstIndex(where: {
                $0.id == entry.id
            }) {
                entryManager.entries.remove(at: index)

                // If the deleted entry was selected, select the first entry or create a new one
                if entryManager.selectedEntryId == entry.id {
                    if let firstEntry = entryManager.entries.first {
                        entryManager.selectedEntryId = firstEntry.id
                        loadEntry(entry: firstEntry)
                    } else {
                        createNewEntry()
                    }
                }
            }
        } catch {
            print("Error deleting file: \(error)")
        }
    }

    // Extract a title from entry content for PDF export
    private func extractTitleFromContent(_ content: String, date: String)
        -> String
    {
        // Clean up content by removing leading/trailing whitespace and newlines
        let trimmedContent = content.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        // If content is empty, just use the date
        if trimmedContent.isEmpty {
            return "Entry \(date)"
        }

        // Split content into words, ignoring newlines and removing punctuation
        let words =
            trimmedContent
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .map { word in
                word.trimmingCharacters(
                    in: CharacterSet(charactersIn: ".,!?;:\"'()[]{}<>")
                )
                .lowercased()
            }
            .filter { !$0.isEmpty }

        // If we have at least 4 words, use them
        if words.count >= 4 {
            return "\(words[0])-\(words[1])-\(words[2])-\(words[3])"
        }

        // If we have fewer than 4 words, use what we have
        if !words.isEmpty {
            return words.joined(separator: "-")
        }

        // Fallback to date if no words found
        return "Entry \(date)"
    }

    private func exportEntryAsPDF(entry: HumanEntry) {
        // First make sure the current entry is saved
        if entryManager.selectedEntryId == entry.id {
            entryManager.saveEntry(entry: entry)
        }

        // Get entry content
        do {
            // Read the content of the entry
            let entryContent = try String(
                contentsOf: entry.fileURL,
                encoding: .utf8
            )

            // Extract a title from the entry content and add .pdf extension
            let suggestedFilename =
                extractTitleFromContent(entryContent, date: entry.date) + ".pdf"

            // Create save panel
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [UTType.pdf]
            savePanel.nameFieldStringValue = suggestedFilename
            savePanel.isExtensionHidden = false  // Make sure extension is visible

            // Show save dialog
            if savePanel.runModal() == .OK, let url = savePanel.url {
                // Create PDF data
                if let pdfData = createPDFFromText(text: entryContent) {
                    try pdfData.write(to: url)
                    print("Successfully exported PDF to: \(url.path)")
                }
            }
        } catch {
            print("Error in PDF export: \(error)")
        }
    }

    private func createPDFFromText(text: String) -> Data? {
        // Letter size page dimensions
        let pageWidth: CGFloat = 612.0  // 8.5 x 72
        let pageHeight: CGFloat = 792.0  // 11 x 72
        let margin: CGFloat = 72.0  // 1-inch margins

        // Calculate content area
        let contentRect = CGRect(
            x: margin,
            y: margin,
            width: pageWidth - (margin * 2),
            height: pageHeight - (margin * 2)
        )

        // Create PDF data container
        let pdfData = NSMutableData()

        // Configure text formatting attributes
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineHeight

        let font =
            NSFont(name: appearance.selectedFont, size: appearance.fontSize)
            ?? .systemFont(ofSize: appearance.fontSize)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(
                red: 0.20,
                green: 0.20,
                blue: 0.20,
                alpha: 1.0
            ),
            .paragraphStyle: paragraphStyle,
        ]

        // Trim the initial newlines before creating the PDF
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Create the attributed string with formatting
        let attributedString = NSAttributedString(
            string: trimmedText,
            attributes: textAttributes
        )

        // Create a Core Text framesetter for text layout
        let framesetter = CTFramesetterCreateWithAttributedString(
            attributedString
        )

        // Create a PDF context with the data consumer
        guard
            let pdfContext = CGContext(
                consumer: CGDataConsumer(data: pdfData as CFMutableData)!,
                mediaBox: nil,
                nil
            )
        else {
            print("Failed to create PDF context")
            return nil
        }

        // Track position within text
        var currentRange = CFRange(location: 0, length: 0)
        var pageIndex = 0

        // Create a path for the text frame
        let framePath = CGMutablePath()
        framePath.addRect(contentRect)

        // Continue creating pages until all text is processed
        while currentRange.location < attributedString.length {
            // Begin a new PDF page
            pdfContext.beginPage(mediaBox: nil)

            // Fill the page with white background
            pdfContext.setFillColor(NSColor.white.cgColor)
            pdfContext.fill(
                CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
            )

            // Create a frame for this page's text
            let frame = CTFramesetterCreateFrame(
                framesetter,
                currentRange,
                framePath,
                nil
            )

            // Draw the text frame
            CTFrameDraw(frame, pdfContext)

            // Get the range of text that was actually displayed in this frame
            let visibleRange = CTFrameGetVisibleStringRange(frame)

            // Move to the next block of text for the next page
            currentRange.location += visibleRange.length

            // Finish the page
            pdfContext.endPage()
            pageIndex += 1

            // Safety check - don't allow infinite loops
            if pageIndex > 1000 {
                print("Safety limit reached - stopping PDF generation")
                break
            }
        }

        // Finalize the PDF document
        pdfContext.closePDF()

        return pdfData as Data
    }
}

// Add helper extension to find NSTextView
extension NSView {
    func findTextView() -> NSView? {
        if self is NSTextView {
            return self
        }
        for subview in subviews {
            if let textView = subview.findTextView() {
                return textView
            }
        }
        return nil
    }
}

// Add helper extension for finding subviews of a specific type
extension NSView {
    func findSubview<T: NSView>(ofType type: T.Type) -> T? {
        if let typedSelf = self as? T {
            return typedSelf
        }
        for subview in subviews {
            if let found = subview.findSubview(ofType: type) {
                return found
            }
        }
        return nil
    }
}

#Preview {
    ContentView()
}
