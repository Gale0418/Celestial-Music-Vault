// Reproducible, original longitude-wrapping Saturn cloud artwork.
// swiftc -O generate_saturn_clouds.swift -o /tmp/cmv-cloud-art
// /tmp/cmv-cloud-art /absolute/path/to/saturn-cloud-map.png
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func hash(_ x: Int, _ y: Int) -> Double {
    var h = UInt32(truncatingIfNeeded: x) &* 374761393 &+ UInt32(truncatingIfNeeded: y) &* 668265263
    h = (h ^ (h >> 13)) &* 1274126177
    return Double(h ^ (h >> 16)) / Double(UInt32.max)
}
func noise(_ x: Double, _ y: Double, period: Int) -> Double {
    let ix = Int(floor(x)), iy = Int(floor(y))
    let fx = x - floor(x), fy = y - floor(y)
    let sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy)
    func wrap(_ n: Int) -> Int { (n % period + period) % period }
    let a = hash(wrap(ix), iy), b = hash(wrap(ix + 1), iy)
    let c = hash(wrap(ix), iy + 1), d = hash(wrap(ix + 1), iy + 1)
    return (a + (b - a) * sx) * (1 - sy) + (c + (d - c) * sx) * sy
}
func cloudNoise(_ x: Double, _ y: Double, period: Int) -> Double {
    var sum = 0.0, weight = 0.55, frequency = 1
    for _ in 0..<4 {
        sum += (noise(x * Double(frequency), y * Double(frequency), period: period * frequency) - 0.5) * weight
        frequency *= 2; weight *= 0.5
    }
    return sum
}
let width = 2048, height = 1024
var pixels = [UInt8](repeating: 255, count: width * height * 4)
for y in 0..<height {
    let v = Double(y) / Double(height - 1)
    for x in 0..<width {
        let u = Double(x) / Double(width)
        let warp = cloudNoise(u * 8, v * 18, period: 8) * 0.026
                 + cloudNoise(u * 24, v * 48, period: 24) * 0.006
        let latitude = v + warp
        let broad = sin(latitude * .pi * 26) * 0.075 + sin(latitude * .pi * 62 + 0.7) * 0.045
        let fine = sin(latitude * .pi * 236 + cloudNoise(u * 16, v * 32, period: 16) * 7) * 0.030
        let detail = cloudNoise(u * 32, v * 220, period: 32) * 0.42
        let tone = min(1, max(0, 0.62 + broad + fine + detail))
        let color = [0.45 + tone * 0.49, 0.34 + tone * 0.49, 0.23 + tone * 0.45]
        let offset = (y * width + x) * 4
        for channel in 0..<3 { pixels[offset + channel] = UInt8(min(255, max(0, Int(color[channel] * 255)))) }
    }
}
let data = Data(pixels)
let provider = CGDataProvider(data: data as CFData)!
let bitmap = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                     bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                     bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                     provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
guard CommandLine.arguments.count == 2 else { fatalError("Supply the output PNG path") }
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, bitmap, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not write cloud artwork") }
print("Created original seamless cloud map: \(width)x\(height)")
