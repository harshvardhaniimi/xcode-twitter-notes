import Foundation
import Vision
import UIKit
import PDFKit

class OCRService {
    static let shared = OCRService()

    private init() {}

    /// Extract text from a UIImage using Vision framework
    func extractText(from image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }

                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                let fullText = recognizedStrings.joined(separator: " ")
                continuation.resume(returning: fullText.isEmpty ? nil : fullText)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    /// Extract text from PDF data
    func extractText(from pdfData: Data) -> String? {
        guard let pdfDocument = PDFDocument(data: pdfData) else { return nil }

        var fullText = ""

        for pageIndex in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: pageIndex),
               let pageText = page.string {
                fullText += pageText + " "
            }
        }

        return fullText.isEmpty ? nil : fullText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extract text from PDF at URL
    func extractText(from url: URL) -> String? {
        guard let pdfDocument = PDFDocument(url: url) else { return nil }

        var fullText = ""

        for pageIndex in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: pageIndex),
               let pageText = page.string {
                fullText += pageText + " "
            }
        }

        return fullText.isEmpty ? nil : fullText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
