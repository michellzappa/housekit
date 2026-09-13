import Foundation
import HouseKit

// housekit-icon <glyph> <output.icns | output.iconset/ | output.png [pixels]>
//
// One house glyph → app icon. Used by each app's build script so the family
// is generated from the same source it draws its menu bar icon with.

let arguments = CommandLine.arguments.dropFirst()
guard arguments.count >= 2, let glyph = HouseGlyphs.all[arguments.first!] else {
    let names = HouseGlyphs.all.keys.sorted().joined(separator: "|")
    fputs("usage: housekit-icon <\(names)> <out.icns | out.iconset | out.png [pixels]>\n", stderr)
    exit(1)
}
let output = URL(fileURLWithPath: arguments[arguments.startIndex + 1])
do {
    switch output.pathExtension {
    case "icns":
        try IconPlate.writeICNS(glyph: glyph, to: output)
    case "iconset":
        try IconPlate.writeIconset(glyph: glyph, to: output)
    case "png":
        let pixels = arguments.count >= 3 ? Int(arguments[arguments.startIndex + 2]) ?? 1024 : 1024
        try IconPlate.png(glyph: glyph, pixels: pixels).write(to: output)
    default:
        fputs("unknown output type: \(output.lastPathComponent)\n", stderr)
        exit(1)
    }
    print(output.path)
} catch {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
