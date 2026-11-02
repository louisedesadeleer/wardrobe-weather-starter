import SwiftUI
import UIKit
import Vision
import CoreImage
import CryptoKit

actor ImageRepository {
    static let shared = ImageRepository()
    func data(for reference: String, directory: URL) async throws -> Data {
        if reference.hasPrefix("demo:") {
            let name = String(reference.dropFirst(5))
            guard name.range(of: #"^demo-[a-z0-9-]+$"#, options: .regularExpression) != nil,
                  let data = await MainActor.run(body: { UIImage(named: name)?.pngData() }) else { throw WardrobeError.invalidImage }
            return data
        }
        if reference.hasPrefix("photos/") {
            guard reference.range(of: #"^photos/[A-Fa-f0-9-]{36}\.png$"#, options: .regularExpression) != nil else { throw WardrobeError.invalidImage }
            return try Data(contentsOf: directory.appendingPathComponent(reference))
        }
        guard let url = URL(string: reference), url.scheme == "https",
              url.host == "res.myindyx.com" || (url.host == "res.cloudinary.com" && url.path.hasPrefix("/myindyx/")) else { throw WardrobeError.invalidImage }
        let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("WardrobePhotos", isDirectory: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let hash = SHA256.hash(data: Data(reference.utf8)).map { String(format: "%02x", $0) }.joined()
        let file = cache.appendingPathComponent(hash)
        if let data = try? Data(contentsOf: file) { return data }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, data.count < 40_000_000 else { throw WardrobeError.invalidImage }
        try? data.write(to: file, options: .atomic); return data
    }
}
struct WardrobePhoto: View {
    let source: String
    var label: String = ""
    @Environment(WardrobeStore.self) private var store
    @State private var image: UIImage?
    @State private var failed = false
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            else if failed { Image(systemName: "photo").foregroundStyle(.secondary).overlay(alignment: .bottom) { Text("Photo unavailable").font(.caption2).offset(y: 18) } }
            else { ProgressView().controlSize(.small) }
        }
        .accessibilityLabel(label)
        .task(id: source) {
            image = nil; failed = false
            do { let data = try await ImageRepository.shared.data(for: source, directory: store.directory); try Task.checkCancellation(); image = UIImage(data: data); failed = image == nil }
            catch is CancellationError {} catch { failed = true }
        }
    }
}
enum PhotoProcessor {
    static func normalized(_ image: UIImage) -> UIImage {
        let scale = min(1, 1800 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }
    static func cutout(_ data: Data) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            guard let source = UIImage(data: data), let image = normalized(source).cgImage else { throw WardrobeError.invalidImage }
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: image, options: [:]); try handler.perform([request])
            guard let result = request.results?.first, !result.allInstances.isEmpty else { throw WardrobeError.invalidImage }
            let buffer = try result.generateMaskedImage(ofInstances: result.allInstances, from: handler, croppedToInstancesExtent: true)
            let ci = CIImage(cvPixelBuffer: buffer)
            guard let cg = CIContext().createCGImage(ci, from: ci.extent), let png = UIImage(cgImage: cg).pngData() else { throw WardrobeError.invalidImage }
            return png
        }.value
    }
}
