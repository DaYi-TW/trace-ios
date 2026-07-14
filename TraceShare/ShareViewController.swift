import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let statusLabel = UILabel()
    private var hasStarted = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        statusLabel.text = "正在加入留痕…"
        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasStarted else { return }
        hasStarted = true
        Task { await saveSharedImages() }
    }

    private func saveSharedImages() async {
        do {
            let images = try await loadImages()
            guard !images.isEmpty else { throw ShareError.noImages }
            _ = try SharedImportStore.write(images: images)
            statusLabel.text = "已加入留痕，請回到 App 整理。"
            try? await Task.sleep(for: .milliseconds(450))
            extensionContext?.completeRequest(returningItems: nil)
        } catch {
            statusLabel.text = error.localizedDescription
            try? await Task.sleep(for: .seconds(1))
            extensionContext?.cancelRequest(withError: error)
        }
    }

    private func loadImages() async throws -> [(data: Data, fileName: String)] {
        let inputItems = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        let providers = inputItems.flatMap { $0.attachments ?? [] }.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
        }
        return try await withThrowingTaskGroup(of: (Data, String)?.self) { group in
            for (index, provider) in providers.enumerated() {
                group.addTask {
                    let image = try await provider.traceImageData()
                    return (image.data, "聊天截圖-\(index + 1).\(image.fileExtension)")
                }
            }
            var images: [(Data, String)] = []
            for try await image in group {
                if let image { images.append(image) }
            }
            return images
        }
    }
}

private extension NSItemProvider {
    func traceImageData() async throws -> (data: Data, fileExtension: String) {
        let typeIdentifier = registeredTypeIdentifiers.first {
            UTType($0)?.conforms(to: .image) == true
        } ?? UTType.image.identifier
        let fileExtension = UTType(typeIdentifier)?.preferredFilenameExtension ?? "img"
        let data: Data = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                if let error { continuation.resume(throwing: error) }
                else if let data { continuation.resume(returning: data) }
                else { continuation.resume(throwing: ShareError.noImages) }
            }
        }
        return (data, fileExtension)
    }
}

private enum ShareError: LocalizedError {
    case noImages

    var errorDescription: String? { "找不到可加入的圖片。" }
}
