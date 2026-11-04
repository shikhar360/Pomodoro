import AppKit

// With two inputs, composites the icon layers. With more inputs, keeps the
// template's contact-sheet behavior for icon review tools.
let args = CommandLine.arguments
let images = args.dropFirst(2).compactMap { NSImage(contentsOfFile: $0) }

if images.count == 2 {
    let size = 1024
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    for image in images {
        image.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
                   from: .zero, operation: .sourceOver, fraction: 1)
    }
    NSGraphicsContext.current = nil
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[1]))
    exit(0)
}

let gap = 48
let height = (images.map { Int($0.size.height) }.max() ?? 0) + gap * 2
let width = images.reduce(gap) { $0 + Int($1.size.width) + gap }
let sheet = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                             isPlanar: false, colorSpaceName: .deviceRGB,
                             bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: sheet)
NSColor(white: 0.55, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()
var x = gap
for image in images {
    let y = (height - Int(image.size.height)) / 2
    image.draw(in: NSRect(x: CGFloat(x), y: CGFloat(y), width: image.size.width, height: image.size.height),
               from: .zero, operation: .sourceOver, fraction: 1)
    x += Int(image.size.width) + gap
}
NSGraphicsContext.current = nil
try! sheet.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[1]))
