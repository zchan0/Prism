import AppKit
import PrismKit
import Testing
@testable import LumosTool
@testable import VitalsTool

@MainActor
struct MenuBarGlyphTests {
    @Test func theImageIsATemplateSoTheMenuBarTintsIt() {
        #expect(MenuBarGlyph.image(symbol: "wand.and.stars", text: nil, accessibilityDescription: "x").isTemplate)
    }

    @Test func theBareWandDrawsFarLessThanTheWandWithStars() {
        let bare = MenuBarGlyph.image(symbol: "wand.and.stars", primaryLayerOnly: true, text: nil, accessibilityDescription: "x")
        let lit = MenuBarGlyph.image(symbol: "wand.and.stars", text: nil, accessibilityDescription: "x")
        #expect(Self.coverage(bare) < Self.coverage(lit) * 0.75)
        #expect(bare.size == lit.size)
    }

    @Test func textMakesTheItemWider() {
        let bare = MenuBarGlyph.image(symbol: "internaldrive", text: nil, accessibilityDescription: "x")
        let withText = MenuBarGlyph.image(symbol: "internaldrive", text: "119 GB", accessibilityDescription: "x")
        #expect(withText.size.width > bare.size.width)
    }

    @Test func emptyTextIsTheSameAsNone() {
        let bare = MenuBarGlyph.image(symbol: "internaldrive", text: nil, accessibilityDescription: "x")
        let empty = MenuBarGlyph.image(symbol: "internaldrive", text: "", accessibilityDescription: "x")
        #expect(empty.size == bare.size)
    }

    @Test func theWidthIsWholePointsSoNeighboursDoNotShift() {
        for text in [nil, "25m", "119 GB", "9.8 GB", "62%"] {
            let width = MenuBarGlyph.image(symbol: "wand.and.stars", text: text, accessibilityDescription: "x").size.width
            #expect(width == width.rounded())
        }
    }

    @Test func paddedCPULoadKeepsTheIconWidth() {
        let width = { (usage: Double) in
            MenuBarGlyph.image(
                symbol: "cpu",
                text: CPUReading(user: usage, system: 0).reading.menuBarText,
                accessibilityDescription: "x"
            ).size.width
        }
        #expect(width(0.05) == width(1))
        #expect(width(0.42) == width(1))
    }

    @Test func theCacheHandsBackTheSameImageUntilSomethingChanges() {
        let cache = MenuBarGlyph.Cache()
        let first = cache.image(symbol: "wand.and.stars", primaryLayerOnly: true, text: nil, accessibilityDescription: "x")
        #expect(cache.image(symbol: "wand.and.stars", primaryLayerOnly: true, text: nil, accessibilityDescription: "x") === first)
        #expect(cache.image(symbol: "wand.and.stars", text: nil, accessibilityDescription: "x") !== first)
        #expect(cache.image(symbol: "wand.and.stars", text: "25m", accessibilityDescription: "x") !== first)
    }

    /// The sum of every pixel's alpha: how much ink the menu bar would draw.
    private static func coverage(_ image: NSImage) -> Double {
        guard let data = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: data) else { return 0 }
        var total = 0.0
        for x in 0..<bitmap.pixelsWide {
            for y in 0..<bitmap.pixelsHigh {
                total += Double(bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0)
            }
        }
        return total
    }
}

@MainActor
struct MenuBarStateTests {
    @Test func countingShowsTimeOnlyWhenAsked() {
        #expect(MenuBarState(mode: .counting(remaining: 1500), showsTime: true).timeText == "25m")
        #expect(MenuBarState(mode: .counting(remaining: 1500), showsTime: false).timeText == nil)
    }

    @Test func foreverHasNoCountdown() {
        #expect(MenuBarState(mode: .forever, showsTime: true).timeText == nil)
        #expect(!MenuBarState(mode: .forever, showsTime: true).accessibilityText.isEmpty)
    }

    @Test func theWandIsLitOnlyWhileAwake() {
        #expect(!MenuBarState(mode: .asleep, showsTime: true).isLit)
        #expect(MenuBarState(mode: .forever, showsTime: true).isLit)
        #expect(MenuBarState(mode: .counting(remaining: 60), showsTime: true).isLit)
    }
}

struct BatterySymbolTests {
    @Test func theGlyphDrainsWithTheLevel() {
        #expect(Reading.batterySymbol(percent: 100) == "battery.100percent")
        #expect(Reading.batterySymbol(percent: 88) == "battery.100percent")
        #expect(Reading.batterySymbol(percent: 87) == "battery.75percent")
        #expect(Reading.batterySymbol(percent: 62) == "battery.50percent")
        #expect(Reading.batterySymbol(percent: 37) == "battery.25percent")
        #expect(Reading.batterySymbol(percent: 12) == "battery.0percent")
        #expect(Reading.batterySymbol(percent: 0) == "battery.0percent")
    }

    @Test func everySymbolExists() {
        for name in ["wand.and.stars", "triangle"]
            + Reading.Kind.allCases.map(\.symbolName)
            + [100, 75, 50, 25, 0].map({ Reading.batterySymbol(percent: $0) }) {
            #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil, "\(name)")
        }
    }
}
