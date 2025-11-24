import SQLiteData
import SwiftUI

#if canImport(UIKit)
import UIKit

typealias NativeColor = UIColor
#elseif canImport(AppKit)
import AppKit

typealias NativeColor = NSColor
#endif

public extension Color {
    struct HexRepresentation: QueryRepresentable, Codable {
        public var queryOutput: Color

        public init(queryOutput: Color) {
            self.queryOutput = queryOutput
        }

        public init(hexValue: Int64) {
            self.init(
                queryOutput: Color(
                    red: Double((hexValue >> 24) & 0xFF) / 255.0,
                    green: Double((hexValue >> 16) & 0xFF) / 255.0,
                    blue: Double((hexValue >> 8) & 0xFF) / 255.0,
                    opacity: Double(hexValue & 0xFF) / 255.0
                )
            )
        }

        public var hexValue: Int64? {
            #if canImport(UIKit)
            let uiColor = UIColor(queryOutput)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }

            return (Int64(r * 255) << 24) |
                (Int64(g * 255) << 16) |
                (Int64(b * 255) << 8) |
                Int64(a * 255)

            #elseif canImport(AppKit)
            let nsColor = NSColor(queryOutput)
            guard let rgb = nsColor.usingColorSpace(.deviceRGB) else { return nil }

            return (Int64(rgb.redComponent * 255) << 24) |
                (Int64(rgb.greenComponent * 255) << 16) |
                (Int64(rgb.blueComponent * 255) << 8) |
                Int64(rgb.alphaComponent * 255)
            #else
            return nil
            #endif
        }

        // MARK: - Codable

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let hex = try container.decode(Int64.self)
            self.init(hexValue: hex)
        }

        public func encode(to encoder: Encoder) throws {
            guard let hexValue = hexValue else {
                struct InvalidColor: Error {}
                throw InvalidColor()
            }
            var container = encoder.singleValueContainer()
            try container.encode(hexValue)
        }
    }
}

// MARK: - QueryBindable

extension Color.HexRepresentation: QueryBindable {
    public init?(queryBinding: QueryBinding) {
        guard case .int(let hexValue) = queryBinding else { return nil }
        self.init(hexValue: hexValue)
    }

    public var queryBinding: QueryBinding {
        guard let hexValue else {
            struct InvalidColor: Error {}
            return .invalid(InvalidColor())
        }
        return .int(hexValue)
    }
}

// MARK: - QueryDecodable

extension Color.HexRepresentation: QueryDecodable {
    public init(decoder: inout some QueryDecoder) throws {
        try self.init(hexValue: Int64(decoder: &decoder))
    }
}
