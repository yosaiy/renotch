#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: generate-icon.swift <output.png>\n", stderr)
    exit(2)
}

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
    fputs("Unable to create drawing context\n", stderr)
    exit(1)
}

let colorSpace = CGColorSpaceCreateDeviceRGB()
let colors = [
    NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.12, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.01, green: 0.015, blue: 0.02, alpha: 1).cgColor
] as CFArray
let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1])!

let tileRect = CGRect(x: 64, y: 64, width: 896, height: 896)
let tilePath = CGPath(roundedRect: tileRect, cornerWidth: 205, cornerHeight: 205, transform: nil)
context.saveGState()
context.addPath(tilePath)
context.clip()
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 512, y: 960),
    end: CGPoint(x: 512, y: 64),
    options: []
)
context.restoreGState()

context.setShadow(offset: CGSize(width: 0, height: -24), blur: 50, color: NSColor.black.withAlphaComponent(0.7).cgColor)
let notchRect = CGRect(x: 205, y: 610, width: 614, height: 238)
let notchPath = CGPath(roundedRect: notchRect, cornerWidth: 86, cornerHeight: 86, transform: nil)
context.setFillColor(NSColor.black.cgColor)
context.addPath(notchPath)
context.fillPath()

context.setShadow(offset: .zero, blur: 30, color: NSColor(calibratedRed: 0.58, green: 0.98, blue: 0.67, alpha: 0.34).cgColor)
context.setFillColor(NSColor(calibratedRed: 0.58, green: 0.98, blue: 0.67, alpha: 1).cgColor)
context.fillEllipse(in: CGRect(x: 282, y: 692, width: 72, height: 72))

context.setShadow(offset: .zero, blur: 0)
context.setStrokeColor(NSColor.white.withAlphaComponent(0.78).cgColor)
context.setLineWidth(26)
context.setLineCap(.round)
context.move(to: CGPoint(x: 422, y: 728))
context.addLine(to: CGPoint(x: 690, y: 728))
context.strokePath()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Unable to encode icon\n", stderr)
    exit(1)
}

try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
