import SwiftUI

struct FontSelectionView: View {
    @EnvironmentObject var appearance: AppearanceSettings
    @EnvironmentObject var hoverStates: HoverStates
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: {}) {
                Image(systemName: "textformat")
                    .font(.system(size: 13, weight: .regular))
            }
            .buttonStyle(.plain)
            .foregroundColor(appearance.primaryActionColor)

            if isHovering {
                FontOptionsView()
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .onHover { hovering in
            withAnimation(.spring()) {
                isHovering = hovering
            }
        }
    }
}

struct FontOptionsView: View {
    @EnvironmentObject var appearance: AppearanceSettings
    @EnvironmentObject var hoverStates: HoverStates

    private var fontOptions: [(name: String, fontValue: String)] {
        return Constants.standardFonts.compactMap { fontValue in
            switch fontValue {
            case "Palatino":
                return ("Palatino", fontValue)
            case "Baskerville":
                return ("Baskerville", fontValue)
            default:
                return nil
            }
        } + [("Serif", "Times New Roman")]
    }

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
            }

            ForEach(Array(fontOptions.enumerated()), id: \.offset) { _, font in
                Text("•")
                    .foregroundColor(.gray)

                FontButton(
                    name: font.name,
                    fontValue: font.fontValue
                )
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
            }
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

struct FontButton: View {
    @EnvironmentObject var appearance: AppearanceSettings
    @EnvironmentObject var hoverStates: HoverStates

    let name: String
    let fontValue: String

    var body: some View {
        Button(name) {
            appearance.selectedFont = fontValue
            appearance.currentRandomFont = ""
        }
        .buttonStyle(.plain)
        .foregroundColor(
            hoverStates.hoveredFont == name
                ? appearance.primaryActionColor
                : appearance.secondaryTextColor
        )
        .onHover { hovering in
            hoverStates.hoveredFont = hovering ? name : nil
        }
    }
}
