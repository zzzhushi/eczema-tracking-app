// Generates the 1024x1024 app icon: a soft teal gradient with a white
// droplet and a lowercase "x" (the eXzema mark) inside it.
// Run: swift scripts/make_icon.swift eXzema/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import AppKit

let outPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "eXzema/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

// Background gradient, soothing teal.
let top = NSColor(calibratedRed: 0.49, green: 0.84, blue: 0.79, alpha: 1)
let bottom = NSColor(calibratedRed: 0.10, green: 0.45, blue: 0.49, alpha: 1)
NSGradient(starting: top, ending: bottom)!
    .draw(in: NSRect(origin: .zero, size: size), angle: -60)

// Droplet: apex on top, round bulb below (origin is bottom-left).
let bulbCenter = NSPoint(x: 512, y: 420)
let bulbRadius: CGFloat = 270
let apex = NSPoint(x: 512, y: 860)

let droplet = NSBezierPath()
droplet.move(to: apex)
droplet.curve(
    to: NSPoint(x: bulbCenter.x + bulbRadius, y: bulbCenter.y),
    controlPoint1: NSPoint(x: 570, y: 720),
    controlPoint2: NSPoint(x: bulbCenter.x + bulbRadius, y: bulbCenter.y + 170)
)
droplet.appendArc(withCenter: bulbCenter, radius: bulbRadius, startAngle: 0, endAngle: 180, clockwise: true)
droplet.curve(
    to: apex,
    controlPoint1: NSPoint(x: bulbCenter.x - bulbRadius, y: bulbCenter.y + 170),
    controlPoint2: NSPoint(x: 454, y: 720)
)
droplet.close()

NSShadow().shadowBlurRadius = 0
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
shadow.shadowOffset = NSSize(width: 0, height: -14)
shadow.shadowBlurRadius = 36
NSGraphicsContext.saveGraphicsState()
shadow.set()
NSColor.white.setFill()
droplet.fill()
NSGraphicsContext.restoreGraphicsState()

// Lowercase "x" centered in the bulb, in the gradient's deep teal.
var font = NSFont.systemFont(ofSize: 340, weight: .heavy)
if let rounded = font.fontDescriptor.withDesign(.rounded), let r = NSFont(descriptor: rounded, size: 340) {
    font = r
}
let text = NSAttributedString(string: "x", attributes: [
    .font: font,
    .foregroundColor: bottom,
])
let textSize = text.size()
text.draw(at: NSPoint(
    x: bulbCenter.x - textSize.width / 2,
    y: bulbCenter.y - textSize.height / 2
))

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:])
else { fatalError("Could not render PNG") }
try! png.write(to: URL(fileURLWithPath: outPath))
print("Wrote \(outPath)")
