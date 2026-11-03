import SwiftUI

/// The pet: a small sun that burns bright while the Mac is kept awake and dozes off with floating Zs when it may sleep.
///
/// Everything is drawn in one `Canvas` pass from the current time. Building the rays, disc and face out of dozens
/// of SwiftUI views meant laying the whole tree out on every animation frame; a canvas only redraws, which is cheap
/// enough to leave running while the Mac sits idle.
struct SunPetView: View {
    static let size: CGFloat = 140
    /// The numbers below are designed against a 70-point radius and scaled from there.
    private static let designRadius: CGFloat = 70

    let isAwake: Bool
    let stage: SunStage
    let remainingText: String?
    let animates: Bool
    let onToggle: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    @State private var didDrag = false

    private var isAnimating: Bool { animates && !reduceMotion }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 10.0, paused: !isAnimating)) { context in
            Canvas { canvas, size in
                draw(in: &canvas, size: size, time: context.date.timeIntervalSinceReferenceDate)
            }
        }
        .background(SunGlow(isAwake: isAwake))
        .frame(width: Self.size, height: Self.size)
        .opacity(isAwake ? 1 : 0.9)
        .gesture(clickOrDrag)
        .onHover { hovering = $0 }
        .overlay(alignment: .top) {
            if hovering, let remainingText {
                Text(remainingText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(nsColor: Palette.onWarm).opacity(0.82)))
                    .padding(.top, 2)
                    .allowsHitTesting(false)
            }
        }
        .help(isAwake ? Strings.petAwakeHint : Strings.petAsleepHint)
        .accessibilityAddTraits([.isButton])
        .accessibilityLabel(Strings.yourSun)
        .accessibilityValue(isAwake ? Strings.petAwakeHint : Strings.petAsleepHint)
    }

    /// One gesture for both, so a click is never mistaken for the start of a drag.
    private var clickOrDrag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                let moved = hypot(value.translation.width, value.translation.height)
                guard moved > 4 else { return }
                guard let window = PetDragging.window, let origin = PetDragging.origin else { return }
                didDrag = true
                window.setFrameOrigin(NSPoint(x: origin.x + value.translation.width, y: origin.y - value.translation.height))
            }
            .onEnded { value in
                let moved = hypot(value.translation.width, value.translation.height)
                if didDrag {
                    PetDragging.finish()
                    didDrag = false
                } else if moved <= 4 {
                    onToggle()
                }
            }
    }

    private func draw(in canvas: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let scale = size.width / (Self.designRadius * 2) * stage.scale
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let bob = isAwake && isAnimating ? CGFloat(sin(time * 1.4)) * 1.2 : 0
        let body = CGPoint(x: center.x, y: center.y + bob)

        drawRays(in: &canvas, center: center, scale: scale, time: time)
        drawDisc(in: &canvas, center: body, scale: scale)
        drawFace(in: &canvas, center: body, scale: scale, time: time)
        if !isAwake {
            drawZs(in: &canvas, center: center, time: time)
        }
    }

    private func drawRays(in canvas: inout GraphicsContext, center: CGPoint, scale: CGFloat, time: TimeInterval) {
        let count = isAwake ? 12 : 8
        let breath = isAwake && isAnimating ? 1 + 0.045 * sin(time * 1.4) : 1
        let inner = 44 * scale * breath
        let length = (isAwake ? 16 : 8) * scale * breath
        let width = isAwake ? 4.2 : 3.4
        let spin = isAwake && isAnimating ? time.truncatingRemainder(dividingBy: 90) * 4 : 0
        for index in 0..<count {
            let angle = Double(index) / Double(count) * .pi * 2 + spin * .pi / 180
            let direction = CGPoint(x: cos(angle), y: sin(angle))
            let start = CGPoint(x: center.x + direction.x * inner, y: center.y + direction.y * inner)
            let end = CGPoint(x: center.x + direction.x * (inner + length), y: center.y + direction.y * (inner + length))
            var path = Path()
            path.move(to: start)
            path.addLine(to: end)
            let gradient = Gradient(colors: [
                Color(nsColor: Palette.sun).opacity(isAwake ? 0.95 : 0.5),
                Color(nsColor: Palette.sunPale).opacity(isAwake ? 0.72 : 0.3),
            ])
            canvas.stroke(
                path,
                with: .linearGradient(gradient, startPoint: start, endPoint: end),
                style: StrokeStyle(lineWidth: width, lineCap: .round)
            )
        }
    }

    private func drawDisc(in canvas: inout GraphicsContext, center: CGPoint, scale: CGFloat) {
        let radius = 41 * scale
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        let colors = isAwake
            ? [Color(nsColor: Palette.sunPale), Color(nsColor: Palette.sun), Color(nsColor: Palette.sunDeep)]
            : [Color(nsColor: Palette.sunPale).opacity(0.85), Color(nsColor: Palette.sun).opacity(0.6)]
        canvas.fill(
            Path(ellipseIn: rect),
            with: .linearGradient(
                Gradient(colors: colors),
                startPoint: CGPoint(x: rect.minX, y: rect.minY),
                endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
            )
        )
        canvas.stroke(
            Path(ellipseIn: rect.insetBy(dx: 0.5, dy: 0.5)),
            with: .color(.white.opacity(isAwake ? 0.5 : 0.28)),
            lineWidth: 1
        )
    }

    private func drawFace(in canvas: inout GraphicsContext, center: CGPoint, scale: CGFloat, time: TimeInterval) {
        let eyeGap = 20 * scale
        let eyeWidth: CGFloat = 8
        let blink = isAwake && isAnimating ? blinkAmount(at: time) : 0
        let eyeHeight = isAwake ? max(2, 13 * (1 - blink)) : 0
        let eyeInk = Color(nsColor: Palette.onWarm).opacity(0.8)

        for side in [-1.0, 1.0] {
            let x = center.x + side * eyeGap
            if isAwake {
                let eye = CGRect(x: x - eyeWidth / 2, y: center.y - 8 - eyeHeight / 2, width: eyeWidth, height: eyeHeight)
                canvas.fill(Path(roundedRect: eye, cornerRadius: eyeWidth / 2), with: .color(eyeInk))
                // A highlight keeps the eye from looking printed.
                let glint = CGRect(x: eye.maxX - 3.4, y: eye.minY + 2.2, width: 2.2, height: 2.2)
                canvas.fill(Path(ellipseIn: glint), with: .color(.white.opacity(0.75)))
            } else {
                // A curved lid, so the sleeping sun looks peaceful rather than switched off.
                var lid = Path()
                lid.move(to: CGPoint(x: x - 5, y: center.y - 6))
                lid.addQuadCurve(to: CGPoint(x: x + 5, y: center.y - 6), control: CGPoint(x: x, y: center.y - 1.5))
                canvas.stroke(lid, with: .color(eyeInk), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        }

        let mouthY = center.y + 7
        if isAwake {
            var smile = Path()
            smile.move(to: CGPoint(x: center.x - 7.5 * scale, y: mouthY - 2))
            smile.addQuadCurve(
                to: CGPoint(x: center.x + 7.5 * scale, y: mouthY - 2),
                control: CGPoint(x: center.x, y: mouthY + 7)
            )
            canvas.stroke(smile, with: .color(eyeInk.opacity(0.85)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        } else {
            let mouth = CGRect(x: center.x - 4, y: mouthY - 1, width: 8, height: 2.6)
            canvas.fill(Path(roundedRect: mouth, cornerRadius: 1.3), with: .color(eyeInk.opacity(0.7)))
        }
    }

    private func drawZs(in canvas: inout GraphicsContext, center: CGPoint, time: TimeInterval) {
        let cycle = time.truncatingRemainder(dividingBy: 3.6) / 3.6
        for index in 0..<3 {
            let phase = (cycle + Double(index) / 3).truncatingRemainder(dividingBy: 1)
            let text = Text(verbatim: "z")
                .font(.system(size: 12 + phase * 9, weight: .bold, design: .rounded))
                .foregroundStyle(Color(nsColor: Palette.moon).opacity((1 - phase) * 0.9))
            let position = CGPoint(x: center.x + 36 + phase * 20, y: center.y - 20 - phase * 32)
            canvas.draw(text, at: position, anchor: .top)
        }
    }

    /// Blinks once every few seconds, for a fifth of a second.
    private func blinkAmount(at time: TimeInterval) -> Double {
        let cycle = time.truncatingRemainder(dividingBy: 4.6)
        guard cycle > 4.35 else { return 0 }
        return sin((cycle - 4.35) / 0.25 * .pi)
    }
}

/// The halo behind the sun. It breathes on its own timeline, so the canvas below only redraws the parts that
/// actually move.
private struct SunGlow: View {
    let isAwake: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 4.0, paused: !isAwake || reduceMotion)) { context in
            let breathe = 0.5 + 0.5 * sin(context.date.timeIntervalSinceReferenceDate * 1.4)
            RadialGradient(
                colors: [
                    Color(nsColor: Palette.sun).opacity(isAwake ? 0.40 + 0.12 * breathe : 0.16),
                    Color(nsColor: Palette.sun).opacity(0),
                ],
                center: .center,
                startRadius: 2,
                endRadius: SunPetView.size * 0.48
            )
        }
        .frame(width: SunPetView.size, height: SunPetView.size)
        .blur(radius: 1)
        .allowsHitTesting(false)
    }
}
