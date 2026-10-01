//
//  ImageStore.swift
//  Timetable
//
//  Created by Zack on 2026/9/29.
//

import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics

enum ImageStore {
    static func saveRaw(_ data: Data) throws -> String {
        guard let type = imageUTType(of: data),
              let ext = type.preferredFilenameExtension else {
            throw CocoaError(.fileWriteUnknown)
        }
        let name = UUID().uuidString + "." + ext
        try data.write(to: url(for: name), options: [.atomic])
        return name
    }

    static func saveProcessed(_ image: CGImage,
                              as type: UTType = .jpeg,
                              quality: CGFloat = 0.7) throws -> String {
        guard let data = encode(image, as: type, quality: quality) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let ext = type.preferredFilenameExtension ?? "dat"
        let name = UUID().uuidString + "." + ext
        try data.write(to: url(for: name), options: [.atomic])
        return name
    }

    static func loadCGImage(_ fileName: String) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url(for: fileName) as CFURL, nil)
        else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    static func loadThumbnail(_ fileName: String, maxPixel: Int = 512) -> CGImage? {
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let src = CGImageSourceCreateWithURL(url(for: fileName) as CFURL, nil)
        else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
    }

    static func delete(_ fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    static func imageUTType(of data: Data) -> UTType? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let id = CGImageSourceGetType(src) else { return nil }
        return UTType(id as String)
    }

    private static func encode(_ image: CGImage, as type: UTType,
                               quality: CGFloat) -> Data? {
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            out, type.identifier as CFString, 1, nil
        ) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(dest, image, opts as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }

    private static func url(for fileName: String) -> URL {
        URL.documentsDirectory.appending(path: fileName)
    }
}
