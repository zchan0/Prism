import SwiftUI

/// Every text style in the panels and the Prism window.
public enum PanelFont {
    /// The one big state on a card, such as Lumos's time left.
    public static let hero = Font.system(size: 17, weight: .semibold)
    /// Names and values.
    public static let name = Font.system(size: 13, weight: .semibold)
    /// Row titles and button titles.
    public static let title = Font.system(size: 12, weight: .medium)
    /// Notes and states.
    public static let note = Font.system(size: 11)
    /// The title above a `PanelSection`'s card.
    public static let section = Font.system(size: 11, weight: .semibold)
    /// A page's name in the Prism window.
    public static let pageTitle = Font.system(size: 15, weight: .semibold)
}

/// The motion every part shares, and its stand-in when the person asks for less motion.
public enum PanelMotion {
    public static let spring = Animation.spring(duration: 0.3, bounce: 0.25)
    public static let fade = Animation.easeInOut(duration: 0.15)

    public static func spring(reduced: Bool) -> Animation {
        reduced ? fade : spring
    }
}

/// A rounded group of rows. Put `PanelDivider.inCard` between the rows.
public struct PanelCard<Content: View>: View {
    private let tint: CardTint?
    private let isTinted: Bool
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        tint = nil
        isTinted = false
        self.content = content()
    }

    /// A card that takes `tint`'s colors while `isTinted`, fading between the two.
    public init(tint: CardTint, isTinted: Bool, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.isTinted = isTinted
        self.content = content()
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                shape.fill(Color(nsColor: Palette.card)).opacity(isTinted ? 0 : 1)
                if let tint {
                    shape.fill(Color(nsColor: tint.fill)).opacity(isTinted ? 1 : 0)
                }
            }
        }
        .overlay {
            ZStack {
                shape.strokeBorder(Color(nsColor: Palette.cardBorder), lineWidth: 1).opacity(isTinted ? 0 : 1)
                if let tint {
                    shape.strokeBorder(Color(nsColor: tint.border), lineWidth: 1).opacity(isTinted ? 1 : 0)
                }
            }
        }
        .clipShape(shape)
        .animation(.easeInOut(duration: 0.25), value: isTinted)
    }
}

/// A card's colors while it stands out, such as Lumos's card while it keeps the Mac awake.
public struct CardTint: Sendable {
    public let fill: NSColor
    public let border: NSColor

    public init(fill: NSColor, border: NSColor) {
        self.fill = fill
        self.border = border
    }

    public static let lumos = CardTint(fill: Palette.lumosWash, border: Palette.lumosLine)
}

/// The title above a card.
public struct PanelSectionTitle: View {
    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(PanelFont.section)
            .foregroundStyle(Color(nsColor: Palette.ink3))
            .lineLimit(1)
            .padding(.leading, 8)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A `PanelCard` with an optional title above it and an optional note under it.
public struct PanelSection<Content: View>: View {
    private let title: String?
    private let note: String?
    private let content: Content

    public init(_ title: String? = nil, note: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.note = note
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                PanelSectionTitle(title)
            }
            PanelCard { content }
            if let note {
                PanelNote(note)
            }
        }
    }
}

/// A line of small print next to a card, lined up with the card's title.
public struct PanelNote: View {
    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(PanelFont.note)
            .foregroundStyle(Color(nsColor: Palette.ink3))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
    }
}

/// A thin bar filled up to `fraction`, such as a Vitals reading or a download.
public struct LevelBar: View {
    private let fraction: Double
    private let color: NSColor

    public init(fraction: Double, color: NSColor) {
        self.fraction = fraction
        self.color = color
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(nsColor: Palette.well))
                Capsule()
                    .fill(Color(nsColor: color))
                    .frame(width: max(4, proxy.size.width * fraction))
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}

/// A tool's symbol on a rounded square of its color.
public struct ToolTile: View {
    public enum Size {
        /// The Prism window's list.
        case small
        case regular
        /// The top of a page in the Prism window.
        case large

        var side: CGFloat {
            switch self {
            case .small: 26
            case .regular: 30
            case .large: 36
            }
        }

        var radius: CGFloat {
            switch self {
            case .small: 8
            case .regular: 9
            case .large: 11
            }
        }

        var symbolSize: CGFloat { self == .large ? 17 : 13 }
    }

    private let symbol: String
    private let primaryLayerOnly: Bool
    private let tint: ToolTint
    private let size: Size

    public init(symbol: String, primaryLayerOnly: Bool = false, tint: ToolTint, size: Size = .regular) {
        self.symbol = symbol
        self.primaryLayerOnly = primaryLayerOnly
        self.tint = tint
        self.size = size
    }

    /// In the tool's color while it is on, and grey while it is off.
    public init(_ tool: Tool, isOn: Bool, size: Size = .regular) {
        self.init(
            symbol: tool.symbolName,
            primaryLayerOnly: tool.symbolPrimaryLayerOnly,
            tint: isOn ? tool.tint : Palette.neutral,
            size: size
        )
    }

    public var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size.symbolSize, weight: .medium))
            .symbolPrimaryLayerOnly(primaryLayerOnly, color: Color(nsColor: tint.glyph))
            .frame(width: size.side, height: size.side)
            .background(RoundedRectangle(cornerRadius: size.radius, style: .continuous).fill(Color(nsColor: tint.fill)))
            .accessibilityHidden(true)
    }
}

/// Shrinks a little while pressed, or dims instead when the person asks for less motion.
public struct PanelPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed && reduceMotion ? 0.7 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A round borderless button with a symbol, such as the gear at the bottom of a tool's panel.
public struct PanelIconButton: View {
    private let symbol: String
    private let title: String
    private let isRevealed: Bool
    private let badge: String?
    private let action: @MainActor () -> Void
    @State private var hovered = false

    /// `isRevealed` false hides the symbol but keeps the button, so a row does not shift when it appears on hover and
    /// VoiceOver still finds it; a transparent button would drop out of the accessibility tree. A `badge` puts a dot
    /// on the button and is what VoiceOver reads for the dot.
    public init(
        symbol: String,
        title: String,
        isRevealed: Bool = true,
        badge: String? = nil,
        action: @escaping @MainActor () -> Void
    ) {
        self.symbol = symbol
        self.title = title
        self.isRevealed = isRevealed
        self.badge = badge
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(Color(nsColor: hovered ? Palette.ink : Palette.ink2))
                .frame(width: 28, height: 28)
                .background(Circle().fill(hovered ? Color(nsColor: Palette.hover) : .clear))
                .overlay(alignment: .topTrailing) {
                    if badge != nil {
                        BadgeDot()
                    }
                }
                .opacity(isRevealed || hovered ? 1 : 0)
                .contentShape(Circle())
        }
        .buttonStyle(PanelPressStyle())
        .help(title)
        .accessibilityLabel(title)
        .accessibilityValue(badge ?? "")
        .onHover { hovered = $0 }
    }
}

/// The dot that says something waits behind a button or a row, such as a downloaded update.
public struct BadgeDot: View {
    private let ring: NSColor?

    /// `ring` draws a thin outline in the color behind the dot, so the dot stands off what it overlaps.
    public init(ring: NSColor? = nil) {
        self.ring = ring
    }

    public var body: some View {
        Circle()
            .fill(Color(nsColor: Palette.accent))
            .frame(width: 9, height: 9)
            .background {
                if let ring {
                    Circle().fill(Color(nsColor: ring)).frame(width: 13, height: 13)
                }
            }
            .accessibilityHidden(true)
    }
}

/// A button as wide as the card above it.
public struct PanelWideButton: View {
    private let title: String
    private let symbol: String?
    private let action: @MainActor () -> Void
    @State private var hovered = false

    public init(_ title: String, symbol: String? = nil, action: @escaping @MainActor () -> Void) {
        self.title = title
        self.symbol = symbol
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(PanelFont.title)
                    .lineLimit(1)
            }
            .foregroundStyle(Color(nsColor: hovered ? Palette.ink : Palette.ink2))
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(Capsule().fill(Color(nsColor: hovered ? Palette.hover : Palette.chip)))
            .contentShape(Capsule())
        }
        .buttonStyle(PanelPressStyle())
        .onHover { hovered = $0 }
    }
}

/// One of a few side-by-side choices that each turn something on or off, such as Lumos's Screen and Lid closed: a
/// round symbol that fills with the accent color while on, a title, and what the choice does now.
public struct PanelOption: View {
    private let title: String
    private let note: String
    private let symbol: String
    private let isOn: Bool
    private let action: @MainActor () -> Void
    @Environment(\.isEnabled) private var isEnabled

    public init(_ title: String, note: String, symbol: String, isOn: Bool, action: @escaping @MainActor () -> Void) {
        self.title = title
        self.note = note
        self.symbol = symbol
        self.isOn = isOn
        self.action = action
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isOn ? Color.white : Color(nsColor: Palette.ink2))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color(nsColor: isOn ? Palette.accent : Palette.chip)))
                    .animation(.easeInOut(duration: 0.2), value: isOn)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(PanelFont.title)
                        .foregroundStyle(Color(nsColor: Palette.ink))
                    Text(note)
                        .font(PanelFont.note)
                        .foregroundStyle(Color(nsColor: Palette.ink3))
                }
                .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(shape.fill(Color(nsColor: Palette.card)))
            .overlay(shape.strokeBorder(Color(nsColor: Palette.cardBorder), lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(PanelPressStyle())
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(note)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

/// A row of choices in a capsule, with a raised capsule behind the chosen one that slides from choice to choice.
/// Without a choice there is no raised capsule at all.
public struct PanelSegmented<Value: Hashable>: View {
    public struct Item {
        public let value: Value
        public let title: String
        public let accessibilityLabel: String?
        public let help: String?

        public init(_ value: Value, title: String, accessibilityLabel: String? = nil, help: String? = nil) {
            self.value = value
            self.title = title
            self.accessibilityLabel = accessibilityLabel
            self.help = help
        }
    }

    private let items: [Item]
    private let selection: Value?
    private let select: @MainActor (Value) -> Void
    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(_ items: [Item], selection: Value?, select: @escaping @MainActor (Value) -> Void) {
        self.items = items
        self.selection = selection
        self.select = select
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                segment(item)
            }
        }
        .padding(3)
        .frame(height: 30)
        .background(Capsule().fill(Color(nsColor: Palette.well)))
        .animation(PanelMotion.spring(reduced: reduceMotion), value: selection)
    }

    private func segment(_ item: Item) -> some View {
        let isSelected = item.value == selection
        return Button {
            select(item.value)
        } label: {
            Text(item.title)
                .font(PanelFont.title)
                .foregroundStyle(Color(nsColor: isSelected ? Palette.ink : Palette.ink2))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .background {
                    if isSelected {
                        pill
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(item.help ?? "")
        .accessibilityLabel(item.accessibilityLabel ?? item.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder private var pill: some View {
        let shape = Capsule()
            .fill(Color(nsColor: Palette.raised))
            .shadow(color: .black.opacity(0.14), radius: 1.5, y: 1)
        // Sliding is motion; with less motion the capsule fades from one choice to the next instead.
        if reduceMotion {
            shape.transition(.opacity)
        } else {
            shape.matchedGeometryEffect(id: "pill", in: namespace)
        }
    }
}
