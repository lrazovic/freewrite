import SwiftUI

struct FontSelectionView: View {
    @EnvironmentObject var appearance: AppearanceSettings
    @EnvironmentObject var hoverStates: HoverStates
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: {}) {
                Text("􀅒")
                    .font(.system(size: 13, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundColor(appearance.primaryActionColor)

            if isHovering {
                FontOptionsView()
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
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
