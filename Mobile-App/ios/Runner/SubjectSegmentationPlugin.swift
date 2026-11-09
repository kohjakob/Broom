import Flutter
import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

class SubjectSegmentationHandler {
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "removeBackground":
            guard let inputPath = call.arguments as? String else {
                result(FlutterError(code: "INVALID_ARG", message: "Expected file path string", details: nil))
                return
            }
            DispatchQueue.global(qos: .userInitiated).async {
                self.removeBackground(inputPath: inputPath, result: result)
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func removeBackground(inputPath: String, result: @escaping FlutterResult) {
        guard let uiImage = UIImage(contentsOfFile: inputPath) else {
            print("[Segmentation] Failed to load image at: \(inputPath)")
            DispatchQueue.main.async { result(nil) }
            return
        }

        // Normalize orientation so segmented output matches the displayed orientation
        let normalizedImage = self.normalizeOrientation(uiImage)
        guard let cgImage = normalizedImage.cgImage else {
            print("[Segmentation] Failed to get CGImage after normalization")
            DispatchQueue.main.async { result(nil) }
            return
        }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)

        do {
            try handler.perform([request])
        } catch {
            print("[Segmentation] Vision request failed: \(error)")
            DispatchQueue.main.async { result(nil) }
            return
        }

        guard let observation = request.results?.first else {
            print("[Segmentation] No results from Vision request")
            DispatchQueue.main.async { result(nil) }
            return
        }

        do {
            let maskBuffer = try observation.generateScaledMaskForImage(
                forInstances: observation.allInstances,
                from: handler
            )

            let ciMask = CIImage(cvPixelBuffer: maskBuffer)
            let ciOriginal = CIImage(cgImage: cgImage)

            // Sharpen the mask edges: boost contrast so soft edges become crisp
            // Multiply the mask values by 3 and clamp, making the transition zone narrower
            let sharpenedMask = ciMask
                .applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: 3, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: 3, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: 3, w: 0),
                    "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 3),
                    "inputBiasVector": CIVector(x: -1, y: -1, z: -1, w: -1),
                ])
                .applyingFilter("CIColorClamp", parameters: [
                    "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
                    "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1),
                ])

            let transparentBg = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0))
                .cropped(to: ciOriginal.extent)

            let filter = CIFilter.blendWithMask()
            filter.inputImage = ciOriginal
            filter.maskImage = sharpenedMask
            filter.backgroundImage = transparentBg

            guard let outputCIImage = filter.outputImage else {
                print("[Segmentation] Failed to produce output image")
                DispatchQueue.main.async { result(nil) }
                return
            }

            // Use GPU-accelerated context for best quality
            let context = CIContext(options: [
                .useSoftwareRenderer: false,
                .highQualityDownsample: true,
            ])
            guard let outputCGImage = context.createCGImage(
                outputCIImage,
                from: outputCIImage.extent,
                format: .RGBA8,
                colorSpace: CGColorSpaceCreateDeviceRGB()
            ) else {
                print("[Segmentation] Failed to create CGImage")
                DispatchQueue.main.async { result(nil) }
                return
            }

            let outputImage = UIImage(cgImage: outputCGImage)
            guard let pngData = outputImage.pngData() else {
                print("[Segmentation] Failed to encode PNG")
                DispatchQueue.main.async { result(nil) }
                return
            }

            // Save as _seg.png next to original
            let outputPath = self.segmentedPath(for: inputPath)
            do {
                try pngData.write(to: URL(fileURLWithPath: outputPath))
                print("[Segmentation] Saved segmented image to: \(outputPath)")
                DispatchQueue.main.async { result(outputPath) }
            } catch {
                print("[Segmentation] Failed to write output: \(error)")
                DispatchQueue.main.async { result(nil) }
            }
        } catch {
            print("[Segmentation] Mask generation failed: \(error)")
            DispatchQueue.main.async { result(nil) }
        }
    }

    private func normalizeOrientation(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up { return image }
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized ?? image
    }

    private func segmentedPath(for inputPath: String) -> String {
        let url = URL(fileURLWithPath: inputPath)
        let dir = url.deletingLastPathComponent()
        let stem = url.deletingPathExtension().lastPathComponent
        return dir.appendingPathComponent("\(stem)_seg.png").path
    }
}
