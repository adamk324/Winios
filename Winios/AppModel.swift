import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ImportedApplication: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var filename: String
    var relativePath: String
    var importedAt: Date
    var architecture: String? = nil
    var kind: String? = nil

    var fileURL: URL {
        Self.importsDirectory.appendingPathComponent(relativePath)
    }

    static var importsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Imported", isDirectory: true)
    }
}

enum PerformanceProfile: String, CaseIterable, Identifiable {
    case lowEnd = "Low-End"
    case balanced = "Balanced"
    case performance = "Performance"

    var id: String { rawValue }
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var applications: [ImportedApplication] = []
    @Published var profile: PerformanceProfile {
        didSet { UserDefaults.standard.set(profile.rawValue, forKey: "performanceProfile") }
    }
    @Published var importError: String?

    private let indexURL = ImportedApplication.importsDirectory.appendingPathComponent("library.json")

    init() {
        let saved = UserDefaults.standard.string(forKey: "performanceProfile") ?? PerformanceProfile.lowEnd.rawValue
        profile = PerformanceProfile(rawValue: saved) ?? .lowEnd
        loadIndex()
        NotificationCenter.default.addObserver(self, selector: #selector(handleMemoryWarning), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
    }

    @objc private func handleMemoryWarning() {
        // Imported files live on disk; releasing transient UI state is sufficient until a runtime exists.
        applications = applications.filter { FileManager.default.fileExists(atPath: $0.fileURL.path) }
    }

    func importItems(from urls: [URL]) {
        do {
            try FileManager.default.createDirectory(at: ImportedApplication.importsDirectory, withIntermediateDirectories: true)
            for source in urls {
                let scoped = source.startAccessingSecurityScopedResource()
                defer { if scoped { source.stopAccessingSecurityScopedResource() } }
                let item = try importItem(from: source)
                applications.insert(item, at: 0)
            }
            try saveIndex()
            importError = nil
        } catch {
            importError = error.localizedDescription
        }
    }

    func remove(_ application: ImportedApplication) {
        try? FileManager.default.removeItem(at: application.fileURL)
        applications.removeAll { $0.id == application.id }
        try? saveIndex()
    }

    private func loadIndex() {
        guard let data = try? Data(contentsOf: indexURL), let saved = try? JSONDecoder().decode([ImportedApplication].self, from: data) else { return }
        applications = saved.filter { FileManager.default.fileExists(atPath: $0.fileURL.path) }
    }

    private func importItem(from source: URL) throws -> ImportedApplication {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var result: Result<ImportedApplication, Error>?
        var coordinationError: NSError?
        coordinator.coordinate(readingItemAt: source, options: [], error: &coordinationError) { coordinatedURL in
            result = Result {
                let ext = coordinatedURL.pathExtension.lowercased()
                let isDirectory = try coordinatedURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
                guard ["exe", "msi", "zip"].contains(ext) || isDirectory else {
                    throw ImportFailure.unsupported(coordinatedURL.lastPathComponent)
                }
                let architecture = ext == "exe" ? try? PEFileInspector.architecture(of: coordinatedURL) : nil
                let kind: String
                if isDirectory { kind = "Application folder" }
                else if ext == "exe" { kind = architecture.map { "Windows executable · \($0)" } ?? "Windows executable · unrecognized PE" }
                else if ext == "msi" { kind = "Windows installer" }
                else { kind = "ZIP archive" }

                let id = UUID()
                let destinationName = "\(id.uuidString)-\(coordinatedURL.lastPathComponent)"
                let destination = ImportedApplication.importsDirectory.appendingPathComponent(destinationName)
                try FileManager.default.copyItem(at: coordinatedURL, to: destination)
                return ImportedApplication(id: id, name: coordinatedURL.deletingPathExtension().lastPathComponent, filename: coordinatedURL.lastPathComponent, relativePath: destinationName, importedAt: Date(), architecture: architecture, kind: kind)
            }
        }

        if let coordinationError { throw coordinationError }
        guard let result else { throw ImportFailure.coordinationFailed }
        return try result.get()
    }

    private func saveIndex() throws {
        let data = try JSONEncoder().encode(applications)
        try data.write(to: indexURL, options: .atomic)
    }
}

enum ImportFailure: LocalizedError {
    case unsupported(String)
    case coordinationFailed
    var errorDescription: String? {
        if case .unsupported(let name) = self { return "Unsupported file type: \(name). Choose an EXE, MSI, ZIP, or folder." }
        if case .coordinationFailed = self { return "The selected item could not be accessed safely." }
        return nil
    }
}
