import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var graphicsMetrics = MetalPreviewMetrics()
    @State private var showingImporter = false
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            library.tag(0).tabItem { Label("Library", systemImage: "square.grid.2x2") }
            settings.tag(1).tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
            diagnostics.tag(2).tabItem { Label("Graphics", systemImage: "waveform.path.ecg") }
        }
        .tint(.indigo)
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.item, .folder], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { model.importItems(from: urls) }
        }
        .alert("Import failed", isPresented: Binding(get: { model.importError != nil }, set: { if !$0 { model.importError = nil } })) {
            Button("OK", role: .cancel) { model.importError = nil }
        } message: { Text(model.importError ?? "") }
    }

    private var library: some View {
        NavigationView {
            Group {
                if model.applications.isEmpty {
                    ContentUnavailableViewCompat(title: "No applications yet", message: "Import an EXE, MSI, ZIP archive, or application folder to keep it in your library.", systemImage: "shippingbox") { showingImporter = true }
                } else {
                    List {
                        Section {
                            ForEach(model.applications) { app in
                                HStack(spacing: 14) {
                                    Image(systemName: app.filename.lowercased().hasSuffix(".exe") ? "app.dashed" : "doc.zipper")
                                        .font(.title2).foregroundColor(.indigo).frame(width: 38, height: 38)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(app.name).font(.headline)
                                        Text(app.filename).font(.caption).foregroundColor(.secondary).lineLimit(1)
                                        Text(app.kind ?? "Imported file").font(.caption2).foregroundColor(.secondary).lineLimit(1)
                                    }
                                    Spacer()
                                    Text("Imported").font(.caption2).foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                                .swipeActions { Button("Remove", role: .destructive) { model.remove(app) } }
                            }
                        } header: { Text("Imported files") }
                        Section { Text("Windows execution is not available yet. Imported files are stored locally; no compatibility runtime is included in this build.").font(.footnote).foregroundColor(.secondary) }
                    }
                }
            }
            .navigationTitle("Winios")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button { showingImporter = true } label: { Label("Import", systemImage: "plus") } } }
        }
        .navigationViewStyle(.stack)
    }

    private var settings: some View {
        NavigationView {
            Form {
                Section("Performance profile") {
                    Picker("Profile", selection: $model.profile) {
                        ForEach(PerformanceProfile.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Text(profileDescription).font(.footnote).foregroundColor(.secondary)
                }
                Section("Storage") {
                    LabeledContentCompat(label: "Imported items", value: "\(model.applications.count)")
                    Text("Files remain inside the Winios application sandbox. Removing the app removes its imported data.").font(.footnote).foregroundColor(.secondary)
                }
            }.navigationTitle("Settings")
        }.navigationViewStyle(.stack)
    }

    private var diagnostics: some View {
        let info = RuntimeDiagnostics.capture()
        return NavigationView {
            Form {
                Section("Device") {
                    LabeledContentCompat(label: "System", value: UIDevice.current.systemName + " " + UIDevice.current.systemVersion)
                    LabeledContentCompat(label: "Metal device", value: info.metalDevice)
                }
                Section("Metal presentation preview") {
                    if let error = graphicsMetrics.error {
                        Text(error).font(.footnote).foregroundColor(.red)
                    } else {
                        MetalPreview(profile: model.profile, isActive: selection == 2, metrics: graphicsMetrics)
                            .frame(height: 170)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        LabeledContentCompat(label: "Measured frame rate", value: String(format: "%.0f FPS", graphicsMetrics.framesPerSecond))
                        LabeledContentCompat(label: "Drawable memory estimate", value: String(format: "%.1f MB", graphicsMetrics.drawableMemoryMB))
                        Text("Host Metal test pattern only. This surface does not display Windows application graphics.").font(.footnote).foregroundColor(.secondary)
                    }
                }
                Section("Memory") {
                    LabeledContentCompat(label: "Current process", value: String(format: "%.1f MB", info.currentMemoryMB))
                    LabeledContentCompat(label: "Peak observed", value: String(format: "%.1f MB", info.peakMemoryMB))
                    Text("Peak is observed while this screen is open; it is not a device memory limit or available-memory estimate.").font(.footnote).foregroundColor(.secondary)
                }
                Section("Runtime") {
                    LabeledContentCompat(label: "Profile", value: model.profile.rawValue)
                    LabeledContentCompat(label: "CPU translation / JIT", value: info.jitStatus)
                    LabeledContentCompat(label: "Wine", value: "Not integrated")
                    LabeledContentCompat(label: "Guest graphics", value: "Not implemented")
                }
            }.navigationTitle("Diagnostics")
        }.navigationViewStyle(.stack)
    }

    private var profileDescription: String {
        switch model.profile {
        case .lowEnd: return "Caps the Metal preview at 30 FPS and lowers its drawable resolution. No Windows runtime is present."
        case .balanced: return "Uses a 30 FPS preview cap with moderate drawable scaling. No Windows runtime is present."
        case .performance: return "Allows a 60 FPS preview cap at native drawable resolution. No Windows runtime is present."
        }
    }
}

private struct ContentUnavailableViewCompat: View {
    let title: String
    let message: String
    let systemImage: String
    let onImport: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage).font(.system(size: 42)).foregroundColor(.secondary)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
            Button("Import files", action: onImport).buttonStyle(.borderedProminent)
        }.padding(32)
    }
}

private struct LabeledContentCompat: View {
    let label: String
    let value: String
    var body: some View { HStack(alignment: .top) { Text(label); Spacer(minLength: 12); Text(value).foregroundColor(.secondary).multilineTextAlignment(.trailing) } }
}

