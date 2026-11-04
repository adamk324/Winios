import Metal
import MetalKit
import QuartzCore
import SwiftUI
import UIKit

final class MetalPreviewMetrics: ObservableObject {
    @Published var framesPerSecond = 0.0
    @Published var drawableMemoryMB = 0.0
    @Published var error: String?
}

struct MetalPreview: UIViewRepresentable {
    let profile: PerformanceProfile
    let isActive: Bool
    @ObservedObject var metrics: MetalPreviewMetrics

    func makeCoordinator() -> Renderer {
        Renderer(metrics: metrics)
    }

    func makeUIView(context: Context) -> ScaledMetalView {
        let view = ScaledMetalView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.delegate = context.coordinator
        view.backgroundColor = .black
        context.coordinator.configure(view: view, profile: profile, isActive: isActive)
        return view
    }

    func updateUIView(_ view: ScaledMetalView, context: Context) {
        context.coordinator.configure(view: view, profile: profile, isActive: isActive)
    }

    final class ScaledMetalView: MTKView {
        var resolutionScale: CGFloat = 1 {
            didSet { setNeedsLayout() }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard bounds.width > 0, bounds.height > 0 else { return }
            let scale = contentScaleFactor * resolutionScale
            drawableSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        }
    }

    final class Renderer: NSObject, MTKViewDelegate {
        private let metrics: MetalPreviewMetrics
        private let device: MTLDevice?
        private let commandQueue: MTLCommandQueue?
        private let pipeline: MTLRenderPipelineState?
        private var frameCount = 0
        private var sampleStart = CACurrentMediaTime()
        private var startTime = CACurrentMediaTime()

        init(metrics: MetalPreviewMetrics) {
            self.metrics = metrics
            device = MTLCreateSystemDefaultDevice()
            commandQueue = device?.makeCommandQueue()

            let shaderSource = """
            #include <metal_stdlib>
            using namespace metal;

            struct PreviewVertex {
                float4 position [[position]];
                float2 uv;
            };

            vertex PreviewVertex preview_vertex(uint vertexID [[vertex_id]]) {
                const float2 positions[3] = {
                    float2(-1.0, -1.0),
                    float2( 3.0, -1.0),
                    float2(-1.0,  3.0)
                };
                PreviewVertex output;
                float2 position = positions[vertexID];
                output.position = float4(position, 0.0, 1.0);
                output.uv = position * 0.5 + 0.5;
                return output;
            }

            fragment float4 preview_fragment(PreviewVertex input [[stage_in]], constant float &time [[buffer(0)]]) {
                float wave = 0.5 + 0.5 * sin(time + input.uv.x * 4.0);
                float3 dark = float3(0.025, 0.055, 0.13);
                float3 bright = float3(0.18, 0.42, 0.78);
                float glow = smoothstep(0.0, 1.0, input.uv.y) * wave;
                return float4(mix(dark, bright, glow), 1.0);
            }
            """

            if let device {
                do {
                    let library = try device.makeLibrary(source: shaderSource, options: nil)
                    let descriptor = MTLRenderPipelineDescriptor()
                    descriptor.vertexFunction = library.makeFunction(name: "preview_vertex")
                    descriptor.fragmentFunction = library.makeFunction(name: "preview_fragment")
                    descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
                    pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
                    metrics.error = nil
                } catch {
                    pipeline = nil
                    metrics.error = "Metal pipeline could not be created: \(error.localizedDescription)"
                }
            } else {
                pipeline = nil
                metrics.error = "No Metal device is available on this device."
            }
            super.init()
        }

        func configure(view: ScaledMetalView, profile: PerformanceProfile, isActive: Bool) {
            view.device = device
            view.autoResizeDrawable = false
            view.preferredFramesPerSecond = profile.frameRateLimit
            view.resolutionScale = profile.previewResolutionScale
            view.isPaused = !isActive
            view.layoutIfNeeded()
            updateDrawableEstimate(view.drawableSize)
        }

        func draw(in view: MTKView) {
            guard let renderView = view as? ScaledMetalView,
                  let descriptor = renderView.currentRenderPassDescriptor,
                  let drawable = renderView.currentDrawable,
                  let commandBuffer = commandQueue?.makeCommandBuffer() else { return }

            if let pipeline, let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) {
                encoder.setRenderPipelineState(pipeline)
                var elapsed = Float(CACurrentMediaTime() - startTime)
                encoder.setFragmentBytes(&elapsed, length: MemoryLayout<Float>.size, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                encoder.endEncoding()
            }

            commandBuffer.present(drawable)
            commandBuffer.commit()
            recordFrame()
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            updateDrawableEstimate(size)
        }

        private func updateDrawableEstimate(_ size: CGSize) {
            let megabytes = size.width * size.height * 4 / 1_048_576
            DispatchQueue.main.async { [weak metrics] in
                metrics?.drawableMemoryMB = Double(megabytes)
            }
        }

        private func recordFrame() {
            frameCount += 1
            let now = CACurrentMediaTime()
            let interval = now - sampleStart
            guard interval >= 1 else { return }
            let measuredFPS = Double(frameCount) / interval
            frameCount = 0
            sampleStart = now
            DispatchQueue.main.async { [weak metrics] in
                metrics?.framesPerSecond = measuredFPS
            }
        }
    }
}

private extension PerformanceProfile {
    var frameRateLimit: Int {
        switch self {
        case .lowEnd, .balanced: return 30
        case .performance: return 60
        }
    }

    var previewResolutionScale: CGFloat {
        switch self {
        case .lowEnd: return 0.7
        case .balanced: return 0.85
        case .performance: return 1.0
        }
    }
}
