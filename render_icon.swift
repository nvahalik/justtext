import AppKit

let size: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Background: dark rounded square
NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size),
             xRadius: size * 0.22, yRadius: size * 0.22).fill()

let font = NSFont.monospacedSystemFont(ofSize: 250, weight: .bold)
let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]

func measure(_ s: String) -> CGSize { (s as NSString).size(withAttributes: attrs) }
let justW = measure("Just").width
let textW = measure("Text").width
let lineH = measure("Text").height
let charW = textW / 4

let totalH = lineH * 2
let startY = (size - totalH) / 2          // lower-left y of bottom line ("Text")
let centerX = size / 2

// Center the "Text" + cursor as one group so the cursor has margin
let gap = charW * 0.28
let cursorW = charW * 0.6
let groupW = textW + gap + cursorW
let textX = centerX - groupW / 2
let justX = centerX - justW / 2
("Just" as NSString).draw(at: NSPoint(x: justX, y: startY + lineH), withAttributes: attrs)
("Text" as NSString).draw(at: NSPoint(x: textX, y: startY), withAttributes: attrs)

// Amber block cursor after "Text", cap-height aligned
let baseline = startY - font.descender
NSColor(red: 1.0, green: 0.71, blue: 0.33, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: textX + textW + gap, y: baseline,
                          width: cursorW, height: font.capHeight)).fill()

NSGraphicsContext.restoreGraphicsState()

let data = rep.representation(using: .png, properties: [:])!
try! data.write(to: URL(fileURLWithPath: "icon_1024.png"))
print("wrote icon_1024.png")
