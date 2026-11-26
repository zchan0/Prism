#if DEBUG
import AppKit
import SwiftUI

/// A fixed, colorful scene behind a window or panel for a screenshot, so glass shows the same thing in every shot and
/// nothing else on the screen gets into it.
@MainActor
final class DebugBackdrop {
    /// How far the scene reaches past what it is behind; a screenshot takes 24 points around it.
    static let margin: CGFloat = 80

    let window: NSWindow

    init() {
        window = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = true
        window.backgroundColor = .black
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.contentView = NSHostingView(rootView: BackdropScene())
    }

    /// Puts the scene under `frame`, at the normal window level: a panel stays above it, and a normal window has to
    /// be brought up again after this.
    func cover(_ frame: NSRect) {
        window.setFrame(frame.insetBy(dx: -Self.margin, dy: -Self.margin), display: true)
        window.orderFrontRegardless()
    }

    func hide() {
        window.orderOut(nil)
    }
}

/// Saturated blocks in a grid, with lines of black and of white text across them.
private struct BackdropScene: View {
    private static let colors: [Color] = [
        Color(red: 0.93, green: 0.20, blue: 0.24),
        Color(red: 1.00, green: 0.62, blue: 0.04),
        Color(red: 0.98, green: 0.86, blue: 0.10),
        Color(red: 0.20, green: 0.72, blue: 0.35),
        Color(red: 0.08, green: 0.62, blue: 0.86),
        Color(red: 0.22, green: 0.30, blue: 0.90),
        Color(red: 0.62, green: 0.30, blue: 0.88),
        Color(red: 0.95, green: 0.35, blue: 0.62),
    ]
    private static let blockSize: CGFloat = 120

    var body: some View {
        GeometryReader { proxy in
            let columns = Int(proxy.size.width / Self.blockSize) + 1
            let rows = Int(proxy.size.height / Self.blockSize) + 1
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<columns, id: \.self) { column in
                                Rectangle()
                                    .fill(Self.colors[(row * 3 + column) % Self.colors.count])
                                    .frame(width: Self.blockSize, height: Self.blockSize)
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(0..<Int(proxy.size.height / 40) + 1, id: \.self) { line in
                        Text(verbatim: String(repeating: "Glass shows what is behind it 0123456789 · ", count: 8))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(line.isMultiple(of: 2) ? Color.black : Color.white)
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
                .padding(.top, 10)
                .padding(.leading, 10)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .clipped()
        }
    }
}
#endif
