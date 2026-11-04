# Winios

Winios is an experimental native iOS project exploring a lightweight Windows compatibility environment for older devices. The current build is a native iOS 15 application foundation: it imports Windows-related files into its sandbox, manages a local library, stores a performance profile selection, and reports basic process and Metal-device diagnostics.

**It does not currently run Windows software.** Wine, CPU translation, guest graphics, audio, controls, and executable launch are not implemented. No compatibility claim is made.

## Build

Open `Winios.xcodeproj` in Xcode 15 or later, select the `Winios` scheme, and build for an iOS 15 simulator or device. Command-line examples:

```sh
xcodebuild -resolvePackageDependencies -project Winios.xcodeproj -scheme Winios
xcodebuild -project Winios.xcodeproj -scheme Winios -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Winios.xcodeproj -scheme Winios -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

The GitHub Actions workflow performs simulator and generic-device builds and runs the unit tests on a macOS runner. An unsigned simulator build is not an installable iPhone IPA. Physical-device, memory-pressure, graphics, and compatibility tests have not yet been performed.

## Current functionality

- Imports EXE, MSI, ZIP, and folder selections using the system file importer.
- Copies selections into the app's private Documents directory and persists a library index.
- Removes imported items from the library and local storage.
- Saves Low-End, Balanced, or Performance profile selection. These labels are configuration only and do not yet tune a runtime.
- Displays process resident memory samples and the system Metal device name.
- Shows explicit status that Wine/JIT/guest rendering are not integrated.

## Feasibility and proposed architecture

See [docs/FEASIBILITY.md](docs/FEASIBILITY.md) for the initial technical assessment, dependency table, constraints, and milestone sequence.

The app is structured as a UIKit/SwiftUI frontend and orchestrator, a sandboxed import/library layer, then separately integrated native runtime, translation, and rendering modules if an iOS-compatible path is established. Metal is intended for host presentation; guest graphics translation is a distinct future capability. This repository currently contains only the native frontend foundation.

## Development from Windows

Swift sources, project settings, documentation, and workflow files can be edited on Windows. Actual iOS compilation and simulator tests require Xcode on macOS; the workflow uses GitHub-hosted `macos-15` runners. Keep native dependency build scripts under `Scripts/Build/` when those dependencies are introduced.

## License

MIT. See [LICENSE](LICENSE) for the original copyright notice.
