
import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appearance: AppearanceSettings
    @EnvironmentObject var uiState: UIState
    @EnvironmentObject var entryManager: EntryManager
    @EnvironmentObject var hoverStates: HoverStates

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: {
                NSWorkspace.shared.selectFile(
                    nil,
                    inFileViewerRootedAtPath: entryManager.getDocumentsDirectory().path
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
                        Text(entryManager.getDocumentsDirectory().path)
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
                                            entryManager.loadEntry(entry: entry)
                                        }
                                    }
                                } else {
                                    // No current entry to save, switch immediately
                                    entryManager.selectedEntryId =
                                        entry.id
                                    entryManager.loadEntry(entry: entry)
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
                                                    entryManager.exportEntryAsPDF(
                                                        entry: entry,
                                                        appearance: appearance
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
                                                    entryManager.deleteEntry(
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
                            entryManager.loadPreviewText(for: entry)
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

    private func backgroundColor(for entry: HumanEntry) -> Color {
        if entry.id == entryManager.selectedEntryId {
            return Color.gray.opacity(0.1)  // More subtle selection highlight
        } else if entry.id == hoverStates.hoveredEntryId {
            return Color.gray.opacity(0.05)  // Even more subtle hover state
        } else {
            return Color.clear
        }
    }
}
