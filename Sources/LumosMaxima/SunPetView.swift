import SwiftUI

/// The pet: a small sun that burns bright while the Mac is kept awake and dozes off with floating Zs when it may sleep.
/// Everything is drawn from the current time, so the view keeps no animation state that could drift.
struct SunPetView: View {
    static let size: CGFloat = 156

    let isAwake: Bool
    let stage: SunStage
    let remainingText: String?
    let animates: Bool
    let onToggle: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    @State private var didDrag = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !animates || reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            ZStack {
                SunGlow(isAwake: isAwake, breathe: breathe(at: time))
                SunRays(isAwake: isAwake, scale: stage.scale, time: time)
                SunDisc(isAwake: isAwake, scale: stage.scale, bob: bob(at: time))
                SunFace(isAwake: isAwake, scale: stage.scale, bob: bob(at: time), blink: blink(at: time))
                if !isAwake {
                    SunSleepingZs(time: time)
                }
            }
            .frame(width: Self.size, height: Self.size)
        }
        .opacity(isAwake ? 1 : 0.88)
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
        .accessibilityLabel(Strings.yourPet)
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

    private func breathe(at time: TimeInterval) -> Double {
        guard isAwake, !reduceMotion else { return 0.5 }
        return 0.5 + 0.5 * sin(time * 1.4)
    }

    private func bob(at time: TimeInterval) -> CGFloat {
        guard isAwake, !reduceMotion else { return 0 }
        return CGFloat(sin(time * 1.4)) * 1.4
    }

    /// Blinks once every few seconds, for a fifth of a second.
    private func blink(at time: TimeInterval) -> Double {
        guard isAwake, !reduceMotion else { return 0 }
        let cycle = time.truncatingRemainder(dividingBy: 4.6)
        guard cycle > 4.35 else { return 0 }
        return sin((cycle - 4.35) / 0.25 * .pi)
    }
}

private struct SunGlow: View {
    let isAwake: Bool
    let breathe: Double

    var body: some View {
        RadialGradient(
            colors: [
                Color(nsColor: Palette.sun).opacity(isAwake ? 0.42 + 0.12 * breathe : 0.14),
                Color(nsColor: Palette.sun).opacity(0),
            ],
            center: .center,
            startRadius: 4,
            endRadius: SunPetView.size * 0.48
        )
        .frame(width: SunPetView.size, height: SunPetView.size)
        .blur(radius: 2)
    }
}

private struct SunRays: View {
    let isAwake: Bool
    let scale: Double
    let time: TimeInterval
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let count = isAwake ? 12 : 8
        let inner = 44 * scale * breath
        let length = (isAwake ? 16 : 8) * scale * breath
        ZStack {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(rayInk)
                    .frame(width: isAwake ? 4.2 : 3.4, height: length)
                    .offset(y: -(inner + length / 2))
                    .rotationEffect(.degrees(Double(index) / Double(count) * 360))
            }
        }
        .rotationEffect(.degrees(spin))
    }

    private var breath: Double {
        guard isAwake, !reduceMotion else { return 1 }
        return 1 + 0.045 * sin(time * 1.4)
    }

    private var spin: Double {
        guard isAwake, !reduceMotion else { return 0 }
        return time.truncatingRemainder(dividingBy: 90) * 4
    }

    private var rayInk: LinearGradient {
        LinearGradient(
            colors: [
                Color(nsColor: Palette.sun).opacity(isAwake ? 0.95 : 0.55),
                Color(nsColor: Palette.sunDeep).opacity(isAwake ? 0.0 : 0.45),
                Color(nsColor: Palette.sunPale).opacity(isAwake ? 0.72 : 0.35),
            ],
            startPoint: .bottom,
            endPoint: .top
        )
    }
}

private struct SunDisc: View {
    let isAwake: Bool
    let scale: Double
    let bob: CGFloat

    var body: some View {
        Circle()
            .fill(fill)
            .frame(width: diameter, height: diameter)
            .overlay(Circle().strokeBorder(.white.opacity(isAwake ? 0.5 : 0.34), lineWidth: 1))
            .shadow(color: Color(nsColor: Palette.sunDeep).opacity(isAwake ? 0.35 : 0.12), radius: 8, y: 3)
            .offset(y: bob)
    }

    private var diameter: CGFloat { 82 * scale }

    private var fill: LinearGradient {
        LinearGradient(
            colors: isAwake
                ? [Color(nsColor: Palette.sunPale), Color(nsColor: Palette.sun), Color(nsColor: Palette.sunDeep)]
                : [Color(nsColor: Palette.sunPale).opacity(0.85), Color(nsColor: Palette.sunDeep).opacity(0.55)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct SunFace: View {
    let isAwake: Bool
    let scale: Double
    let bob: CGFloat
    let blink: Double

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 20 * scale) {
                eye
                eye
            }
            mouth
        }
        .offset(y: -3 + bob)
    }

    private var eye: some View {
        Group {
            if isAwake {
                Capsule()
                    .fill(Color(nsColor: Palette.onWarm).opacity(0.8))
                    .frame(width: 8, height: max(2, 13 * (1 - blink)))
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(.white.opacity(0.75))
                            .frame(width: 2.2, height: 2.2)
                            .offset(x: -2, y: 2.5)
                    }
            } else {
                // A closed eyelid curves, so the sleeping sun looks peaceful rather than switched off.
                Capsule()
                    .strokeBorder(Color(nsColor: Palette.onWarm).opacity(0.85), lineWidth: 2)
                    .frame(width: 10, height: 5)
            }
        }
        .frame(width: 10, height: 15)
    }

    @ViewBuilder private var mouth: some View {
        if isAwake {
            SmileShape()
                .stroke(Color(nsColor: Palette.onWarm).opacity(0.7), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 15 * scale, height: 6)
        } else {
            Capsule()
                .fill(Color(nsColor: Palette.onWarm).opacity(0.65))
                .frame(width: 7, height: 3)
        }
    }
}

private struct SunSleepingZs: View {
    let time: TimeInterval

    var body: some View {
        let cycle = time.truncatingRemainder(dividingBy: 3.6) / 3.6
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let phase = (cycle + Double(index) / 3).truncatingRemainder(dividingBy: 1)
                Text(verbatim: "z")
                    .font(.system(size: 12 + phase * 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(nsColor: Palette.moon).opacity((1 - phase) * 0.9))
                    .offset(x: 36 + phase * 20, y: -20 - phase * 32)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.2))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.2),
            control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.7)
        )
        return path
    }
}
