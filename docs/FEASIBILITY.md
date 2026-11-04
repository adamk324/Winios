# Winios technical feasibility — initial assessment

**Status:** research assessment for Milestone 0, 4 November 2026. No Windows executable has been run by this project. The target is an iOS 15 app; simulator and physical-device results must be reported separately.

## Executive assessment

A native iOS shell, file import, settings, diagnostics, and Metal presentation are practical. A general-purpose Winlator-like environment on stock iOS is a high-risk research project. The key blockers are availability of a permitted executable-code/JIT strategy for CPU translation, porting Wine's Unix-facing runtime and process model to iOS, and integrating guest graphics APIs under iOS constraints. ARM64 instructions alone do not solve Wine's Windows API, PE loading, Unix syscall, thread, registry, and filesystem requirements.

The present app therefore provides file organization and truthful diagnostics only. It does not load or execute PE files. A future milestone should be gated on a small, legal, device-tested proof of executable-code policy and a demonstrated Wine-compatible single-process runtime before substantial porting begins.

## Proposed architecture

1. **SwiftUI/UIKit app shell (implemented foundation):** tabs for Library, Settings, Diagnostics; iOS 15 API baseline.
2. **Sandbox storage (implemented foundation):** document-picker import, copy into app Documents, JSON index. Keep large data on disk and avoid duplicating it into memory.
3. **Runtime coordinator (future):** explicit runtime state machine and diagnostics. No launch action until a real backend exists.
4. **Compatibility runtime (unproven):** Wine API layer plus adapted server/process/thread services, likely one host process if child process creation cannot meet iOS policy.
5. **CPU execution (unproven):** native ARM64 Windows ABI path first; x86/x64 would require a permitted interpreter or JIT translation engine plus Windows ABI/runtime integration.
6. **Graphics (future):** Metal-backed host surface and presentation module; guest API translation isolated behind replaceable interfaces. Metal presentation does not itself translate Direct3D/OpenGL.
7. **Audio/input (future):** CoreAudio output, UIKit touch/mouse/keyboard mapping and external controllers after a genuine runtime surface exists.

## Dependency and compatibility table

| Component | iOS 15 assessment | Current evidence/status |
|---|---|---|
| SwiftUI/UIKit shell | Viable | Implemented in this milestone; macOS CI build pending. |
| Document picker | Viable | User-selected sandbox import, including folders on iOS 13+; used here for explicit file/folder import. |
| Metal | Viable for host rendering | Implemented a host test-pattern pipeline, presentation surface, FPS measurement, profile-based drawable scaling, and preferred frame rate. No guest renderer or translation exists. |
| Wine | Major porting work; not directly usable as a desktop build | Wine upstream lists Linux, FreeBSD, Solaris, NetBSD, and macOS; iOS is not an upstream target. A separate open-source iOS product documents a large Wine port using one host process, but this does not establish iOS 15/A9 compatibility. |
| FEX-Emu | Not directly compatible as published | Upstream targets ARM64 Linux. The iOS reference product uses a heavily patched FEX port and in-process integration; this is evidence of feasibility on its supported setup, not drop-in compatibility. |
| Native Windows ARM64 PE | Not a drop-in path | The CPU ISA may match, but iOS cannot simply load and execute arbitrary PE modules. Wine API, loader, ABI, memory, and OS-service work remains. |
| JIT | Critical policy/platform gate | iOS requires executable memory to satisfy code-signing rules. Apple documents JIT-related entitlements/APIs in scoped contexts; this does not establish that a normal third-party iOS app can obtain the required capability for general emulation. Do not rely on private APIs or entitlement hacks. |
| OpenGL / GLES | Legacy/limited route | iOS provides legacy OpenGL ES support on this target but it is deprecated; desktop OpenGL compatibility needs a translation implementation and testing. |
| Zink / Vulkan / MoltenVK | Unverified for this app target | Desktop/Linux availability is insufficient evidence of iOS support. Each requires a separate source, licensing, SDK, and runtime feasibility audit. |
| DXVK / DXMT | Not assessed as viable on iOS | Do not integrate until upstream support, licensing, and iOS API requirements are verified. |
| CoreAudio | Viable for host audio | Future module; no Windows audio bridge exists. |

## iOS 15, memory, and performance

- Minimum deployment is set to iOS 15.0 in the Xcode project. UI code avoids iOS 16-only `ContentUnavailableView` and `LabeledContent`.
- The requested 1 GiB is a design ceiling, not a guaranteed allocation budget. iOS termination thresholds depend on device and system pressure; there is no universal safe per-app limit. Respond to memory warnings and profile on real devices.
- Current diagnostics sample the process resident footprint using Mach task information and the default Metal device name. They do not estimate free system RAM, graphics allocation, or jetsam thresholds.
- The three profiles adjust the host Metal preview's drawable scale and frame-rate cap. They do not tune a Windows runtime or imply broader resource throttling.
- Future profiles should set explicit working-set and texture ceilings based on device capability, with low-end as the default and cleanup on memory warnings/backgrounding.

## Wine integration strategy and blockers

Do not compile desktop Wine unchanged and assume it can execute on iOS. First audit loader/PE support, Darwin/iOS build configuration, Mach-O dependencies, Unix syscalls, dynamic libraries, executable-memory requirements, process creation, wineserver IPC, signals/exceptions, filesystem/registry behavior, and the iOS sandbox. A public reference implementation demonstrates a single-process Wine/server model on newer iOS and hardware. No Wine modifications or runtime code have been added to Winios.

## CPU translation and JIT strategy

Prefer native Windows ARM64 machine code only if a supported loader/runtime route is demonstrated. For x86/x64, upstream FEX's stated host is ARM64 Linux, not iOS; Linux syscalls/rootfs and JIT behavior cannot be assumed to transfer. Compare an interpreter fallback against a permitted JIT path only after establishing executable-memory policy on the intended distribution channel and OS versions. Capability diagnostics must be based on actual runtime checks, never marketing assumptions. Current app reports translation/JIT as not integrated.

## Graphics strategy

Keep host presentation separate from guest API compatibility. Start with an iOS 15-compatible Metal surface, resource lifecycle, resolution/FPS instrumentation, and device capability checks. Then select one guest graphics path based on source-level iOS support and a real Windows test application. Treat desktop OpenGL, GLES, Vulkan, and Direct3D as separate APIs. No guest graphics support is implemented.

## Major blockers and decision gates

1. **Executable-code/JIT policy:** prove a legitimate install/distribution route with required dynamic code execution or define a useful interpreter route.
2. **Wine runtime port:** demonstrate a minimal Windows program running through real Wine API implementations on a physical iOS device.
3. **Process model:** establish whether a single-process server/runtime is viable within iOS sandbox and lifecycle constraints.
4. **Translator compatibility:** establish iOS build/runtime support, architecture requirements, and memory/performance on A9-class hardware.
5. **Graphics:** prove one guest API translation path with an actual Windows graphics app; Metal-only output is not compatibility.
6. **Distribution/legal policy:** assess Apple program rules and distribution channel before promising a general downloadable app execution environment.
7. **Hardware:** validate memory, thermal behavior, JIT/translation, and input on physical older iPhones. Simulator results cannot establish these.

## Reference implementation discovered (4 November 2026)

[Playport](https://github.com/playportdev/playport) is a public project demonstrating that a Wine/FEX-based Windows runtime can run in one iOS app process. Its [architecture](https://github.com/playportdev/playport/blob/main/docs/ARCHITECTURE.md) describes wineserver as an app thread, Wine Unix-side libraries linked into the app, pseudo-processes for guest programs, and a debugger-provided JIT pool. This resolves the earlier question of whether an iOS adaptation is purely hypothetical: a concrete implementation exists.

It does **not** resolve Winios's stated compatibility target. Playport's [build guide](https://github.com/playportdev/playport/blob/main/docs/BUILDING.md) uses an iOS 26.5 SDK; its [device reference](https://github.com/playportdev/playport/blob/main/docs/DEVICE.md) sets deployment target iOS 26.0 and records a known-good run on an iPhone 18,4 (A19 Pro) with iOS 27.0. It says no iOS 26 device run was known good at that time. It provides no evidence for iOS 15 or A9-generation hardware. Its modern JIT route depends on debugger attachment and device/OS-specific helper behavior.

Directly adopting its source also changes the license review substantially. Playport is GPL-3.0-or-later with an additional permission for its own code, while components retain separate licenses. Winios's original MIT `LICENSE` and attribution must remain. Any source integration needs a reviewed component/license inventory, applicable source and notice obligations, and a distribution plan; no Playport source has been copied into Winios.

A second relevant project is [Juice](https://github.com/ExoCore-Kernel/Juice), whose maintainers report physical iPad testing of native ARM64 Wine and FEX-translated x86-64 Windows software. Its stated audited device is iPad12,1 on iPadOS 16.6. Juice's own code is MIT and Wine remains LGPL, which is closer to Winios's existing licensing than Playport's GPL base. However, Juice explicitly targets rootless-jailbroken ARM64 devices and requires private entitlements/CoreTrust signing; it also documents exposing host files through Wine's Z: drive. That path is not equivalent to a stock sandboxed app, has no stated iOS 15 or A9 test evidence, and carries a materially different security and distribution model. No Juice source has been copied into Winios.

For context, [UTM SE](https://github.com/utmapp/UTM) provides a JIT-free interpreter-based full-system emulation option for iOS 15, but it is a slower virtual-machine approach intended for older/lightweight guest operating systems. It does not provide Wine's direct Windows application integration and is not a substitute for the desired runtime.

The current practical gate is therefore a device and execution-model feasibility decision, not a fake runtime wrapper: stock iOS has a recent-device precedent, while the closer iOS 16.6 precedent requires a jailbreak. iOS 15 and A9 remain unproven for either runtime. Keep the native app targeting iOS 15 while testing what real devices and execution model are available before selecting a Wine port.

## Implemented milestone and validation status

Milestone 1 created the native project, import/library, settings, memory/device diagnostics, basic unit tests, and macOS CI. Milestone 2 adds a host Metal test-pattern surface, frame presentation, FPS reporting, drawable-size scaling per profile, and pause behavior while the Graphics tab is inactive. CI passed simulator and generic-device builds and simulator unit tests. Physical-device behavior, older-device performance, thermal impact, and graphics-memory measurements remain unverified.

## References

- [Wine: About](https://www.winehq.org/about/) — POSIX compatibility-layer design.
- [FEX-Emu upstream repository](https://github.com/FEX-Emu/FEX) — project describes ARM64 Linux host and x86/x86-64 emulation.
- [Apple: code-signature requirements for executable code](https://developer.apple.com/documentation/lightweightcoderequirements/ondiskcodesigningflags/valueset/iscodesignaturerequiredforallexecutablecode).
- [Apple: JIT entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.cs.allow-jit).
- [Apple: interpreting Apple's JIT compiler guidance](https://developer.apple.com/documentation/apple-silicon/porting-just-in-time-compilers-to-apple-silicon) — guidance includes macOS Hardened Runtime entitlements and notes API availability; it is not authorization for arbitrary iOS emulators.
- [Apple: memory use and jetsam reports](https://developer.apple.com/documentation/xcode/identifying-high-memory-use-with-jetsam-event-reports).
- [Apple: accessing user-selected directories](https://developer.apple.com/documentation/uikit/providing-access-to-directories).
- [Apple Developer Program License Agreement](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/) — executable code and interpreted-code terms; obtain appropriate review before distribution claims.
- [Playport repository](https://github.com/playportdev/playport) — public implementation reference and its stated testing/distribution setup.
- [Playport architecture](https://github.com/playportdev/playport/blob/main/docs/ARCHITECTURE.md) — in-process Wine/FEX design and debugger-provided JIT model.
- [Playport licensing record](https://github.com/playportdev/playport/blob/main/docs/LICENSING.md) — GPL and per-component licensing obligations.
- [Juice repository](https://github.com/ExoCore-Kernel/Juice) — Wine/FEX app with reported on-device executable tests, MIT project code, and a jailbreak/private-entitlement target.
- [UTM SE](https://github.com/utmapp/UTM) — iOS 15-capable interpreter-based full-system emulation alternative.
