import HouseKit
import Testing

@Suite struct GlyphTests {
    @Test func glyphsStayInsideTheField() {
        for (name, glyph) in HouseGlyphs.all {
            for mark in glyph.marks {
                #expect(mark.rect.minX >= 0 && mark.rect.minY >= 0, "\(name)")
                #expect(mark.rect.maxX <= 1.0001 && mark.rect.maxY <= 1.0001, "\(name)")
            }
        }
    }

    @Test func iconRendersEverySize() {
        for size in IconPlate.iconsetSizes {
            let bitmap = IconPlate.bitmap(glyph: HouseGlyphs.clip, pixels: size.pixels)
            #expect(bitmap.pixelsWide == size.pixels)
        }
    }
}
