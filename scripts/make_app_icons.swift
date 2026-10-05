#!/usr/bin/env swift
// Draws the app icon: a shopping cart with a check, at 1024x1024.
//
// Writes three opaque PNGs (iOS rejects icons with transparency) into the
// asset catalog: the normal icon, a dark-mode variant and a grayscale one the
// system tints. Run from the repository root:
//
//     swift scripts/make_app_icons.swift
//
// The cart is the 24-unit path from the design, scaled up, with the check
// nudged down so it stays clear of the basket rim at small sizes.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Variant {
    let file: String
    let background: (CGFloat, CGFloat, CGFloat)
    let glyph: (CGFloat, CGFloat, CGFloat)
}

let variants = [
    Variant(file: "AppIcon.png", background: (10 / 255, 100 / 255, 216 / 255), glyph: (1, 1, 1)),
    Variant(file: "AppIcon-Dark.png", background: (8 / 255, 43 / 255, 92 / 255), glyph: (1, 1, 1)),
    Variant(file: "AppIcon-Tinted.png", background: (0, 0, 0), glyph: (1, 1, 1)),
]

let size = 1024
let outputDirectory = URL(fileURLWithPath: "src/app/Assets.xcassets/AppIcon.appiconset")

func render(_ variant: Variant) -> CGImage {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    let bg = variant.background
    context.setFillColor(CGColor(red: bg.0, green: bg.1, blue: bg.2, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: size, height: size))

    // Work in the cart's 24-unit space, y pointing down like SVG: scale 25
    // makes the glyph about 600 px. The offsets center it optically, since the
    // cart's handle makes its box lopsided.
    context.translateBy(x: 231, y: CGFloat(size) - 201)
    context.scaleBy(x: 25, y: -25)
    let g = variant.glyph
    context.setStrokeColor(CGColor(red: g.0, green: g.1, blue: g.2, alpha: 1))
    context.setLineWidth(1.7)
    context.setLineCap(.round)
    context.setLineJoin(.round)

    let cart = CGMutablePath()
    cart.move(to: CGPoint(x: 3, y: 4))
    cart.addLine(to: CGPoint(x: 5.2, y: 4))
    cart.addLine(to: CGPoint(x: 7.2, y: 15))
    cart.addLine(to: CGPoint(x: 17.6, y: 15))
    cart.addLine(to: CGPoint(x: 19.5, y: 7))
    cart.addLine(to: CGPoint(x: 6.3, y: 7))
    cart.addEllipse(in: CGRect(x: 9 - 1.4, y: 19.5 - 1.4, width: 2.8, height: 2.8))
    cart.addEllipse(in: CGRect(x: 17 - 1.4, y: 19.5 - 1.4, width: 2.8, height: 2.8))
    // The check sits low in the basket so it never touches the rim, even small.
    cart.move(to: CGPoint(x: 10.3, y: 11.2))
    cart.addLine(to: CGPoint(x: 11.7, y: 12.6))
    cart.addLine(to: CGPoint(x: 14.5, y: 9.7))
    context.addPath(cart)
    context.strokePath()
    return context.makeImage()!
}

for variant in variants {
    let url = outputDirectory.appending(path: variant.file)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Couldn't create \(url.path)")
    }
    CGImageDestinationAddImage(destination, render(variant), nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Couldn't write \(url.path)") }
    print("wrote \(url.path)")
}
