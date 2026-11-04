# Winios

Winios is an experimental native iOS project exploring a lightweight Windows compatibility environment for older devices. The current build is a native iOS 15 application foundation: it imports Windows-related files into its sandbox, manages a local library, stores a performance profile selection, presents a native Metal test pattern, and reports basic process and graphics diagnostics.

**It does not currently run Windows software.** Wine, CPU translation, guest graphics, audio, controls, and executable launch are not implemented. No compatibility claim is made.

## Build

Open `Winios.xcodeproj` in Xcode 15 or later, select the `Winios` scheme, and build for an iOS 15 simulator or device. Command-line examples:

```sh
xcodebuild -resolvePackageDependencies -project Winios.xcodeproj -scheme Winios
xcodebuild -project Winios.xcodeproj -scheme Winios -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Winios.xcodeproj -scheme Winios -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

The GitHub Actions workflow performs simulator and generic-device builds, runs unit tests, and packages an unsigned Release `test.ipa` for iOS 15. The workflow checks its minimum OS, bundle ID, ARM64 architecture, and IPA ZIP integrity. Download the `winios-<commit>-ios15-test-ipa-unsigned` artifact from a successful Actions run and install it with TrollStore. It contains no Apple certificate or provisioning profile; no signing secrets are used.

The app currently does not request or use JIT and does not include Wine or a Windows runtime. TrollStore/JIT availability on a device does not add those features. Physical-device, memory-pressure, graphics, and Windows compatibility tests have not yet been performed.

## Current functionality

- Imports one EXE, MSI, ZIP, or folder at a time through the system file importer. Selecting one item immediately returns it to Winios; the extension is validated after selection.
- Registers EXE, MSI, and ZIP document types so choosing Winios from Files can import the selected item into the library; picker failures are surfaced to the user.
- Reads bounded DOS/PE headers for imported EXE files and displays the machine architecture when recognized; no executable content is loaded or run.
- Tapping a library item opens a details sheet with its file type, PE architecture, and actual runtime availability; diagnostic details can be copied.
- Copies selections into the app's private Documents directory and persists a library index.
- Removes imported items from the library and local storage.
- Saves Low-End, Balanced, or Performance profile selection. These tune only the Metal preview's resolution scale and frame-rate cap; they do not tune a Windows runtime.
- Displays process resident memory samples and the system Metal device name.
- Renders a native Metal test pattern with FPS reporting, profile-based drawable scaling, and pause behavior when the Graphics tab is inactive.
- Shows explicit status that Wine/JIT/guest rendering are not integrated.

The drawable memory estimate represents one 32-bit color surface. It does not measure all driver-managed or in-flight graphics memory.

## Feasibility and proposed architecture

See [docs/FEASIBILITY.md](docs/FEASIBILITY.md) for the technical assessment, dependency table, constraints, milestone sequence, and current Wine/FEX runtime references. Winios has not copied source from those projects; their newer-device or jailbreak requirements do not establish compatibility with Winios's iOS 15/A9 target.

The app is structured as a UIKit/SwiftUI frontend and orchestrator, a sandboxed import/library layer, then separately integrated native runtime, translation, and rendering modules if an iOS-compatible path is established. The Metal preview demonstrates host presentation only; guest graphics translation is a distinct future capability.

## Development from Windows

Swift sources, project settings, documentation, and workflow files can be edited on Windows. Actual iOS compilation and simulator tests require Xcode on macOS; the workflow uses GitHub-hosted `macos-15` runners. Keep native dependency build scripts under `Scripts/Build/` when those dependencies are introduced.

## License

MIT. See [LICENSE](LICENSE) for the original copyright notice.
