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

                let ext = source.pathExtension.lowercased()
                guard ["exe", "msi", "zip"].contains(ext) || (try source.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true) else {
                    throw ImportFailure.unsupported(source.lastPathComponent)
                }
                let id = UUID()
                let destinationName = "\(id.uuidString)-\(source.lastPathComponent)"
                let destination = ImportedApplication.importsDirectory.appendingPathComponent(destinationName)
                try FileManager.default.copyItem(at: source, to: destination)
                let item = ImportedApplication(id: id, name: source.deletingPathExtension().lastPathComponent, filename: source.lastPathComponent, relativePath: destinationName, importedAt: Date())
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

    private func saveIndex() throws {
        let data = try JSONEncoder().encode(applications)
        try data.write(to: indexURL, options: .atomic)
    }
}

enum ImportFailure: LocalizedError {
    case unsupported(String)
    var errorDescription: String? {
        if case .unsupported(let name) = self { return "Unsupported file type: \(name). Choose an EXE, MSI, ZIP, or folder." }
        return nil
    }
}
