import SwiftUI

struct EditorView: View {
    @EnvironmentObject var appearance: AppearanceSettings
    @EnvironmentObject var uiState: UIState
    @Binding var text: String

    var body: some View {
        TextEditor(text: $text)
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
            .overlay(
                ZStack(alignment: .topLeading) {
                    if text.trimmingCharacters(
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
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                },
                alignment: .topLeading
            )
    }

    private var lineHeight: CGFloat {
        let font =
            NSFont(name: appearance.selectedFont, size: appearance.fontSize)
            ?? .systemFont(ofSize: appearance.fontSize)
        let defaultLineHeight = font.ascender - font.descender + font.leading
        return (appearance.fontSize * 1.5) - defaultLineHeight
    }
}
