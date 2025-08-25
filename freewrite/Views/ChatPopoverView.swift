import SwiftUI

struct ChatPopoverView: View {
    @EnvironmentObject var appearance: AppearanceSettings
    @EnvironmentObject var uiState: UIState
    @EnvironmentObject var entryManager: EntryManager

    var body: some View {
        VStack(spacing: 0) {
            let trimmedText = entryManager.text
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

            // Calculate potential URL lengths
            let gptFullText =
                Constants.aiChatPrompt + "\n\n" + trimmedText
            let claudeFullText =
                Constants.claudePrompt + "\n\n" + trimmedText
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

    private func openChatGPT() {
        let trimmedText = entryManager.text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let fullText = Constants.aiChatPrompt + "\n\n" + trimmedText

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
        let fullText = Constants.claudePrompt + "\n\n" + trimmedText

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
        let fullText = Constants.aiChatPrompt + "\n\n" + trimmedText

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(fullText, forType: .string)
        print("Prompt copied to clipboard")
    }
}
