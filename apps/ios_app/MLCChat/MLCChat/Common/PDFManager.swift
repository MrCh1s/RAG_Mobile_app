import Foundation
import PDFKit

class PDFManager {
    static let shared = PDFManager()
    
    private init() {}
    
    /// Trích xuất toàn bộ văn bản từ file PDF tại URL cung cấp
    func extractText(from url: URL) -> String? {
        guard let document = PDFDocument(url: url) else {
            print("Lỗi: Không thể mở tài liệu PDF tại \(url)")
            return nil
        }
        
        var fullText = ""
        for i in 0..<document.pageCount {
            if let page = document.page(at: i), let pageText = page.string {
                fullText += pageText + "\n"
            }
        }
        
        return fullText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Chia nhỏ văn bản thành các đoạn (chunks)
    /// - Parameters:
    ///   - text: Văn bản gốc
    ///   - chunkSize: Kích thước tối đa của mỗi đoạn (ký tự)
    ///   - overlap: Độ gối đầu giữa các đoạn để giữ ngữ cảnh
    func chunkText(_ text: String, chunkSize: Int = 500, overlap: Int = 100) -> [String] {
        var chunks: [String] = []
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        var currentChunk: [String] = []
        var currentLength = 0
        
        for word in words {
            currentChunk.append(word)
            currentLength += word.count + 1 // +1 cho khoảng trắng
            
            if currentLength >= chunkSize {
                chunks.append(currentChunk.joined(separator: " "))
                
                // Giữ lại một phần cuối để làm gối đầu (overlap)
                let overlapWords = Array(currentChunk.suffix(max(1, overlap / 10))) // Ước lượng 10 ký tự/từ
                currentChunk = overlapWords
                currentLength = currentChunk.map { $0.count + 1 }.reduce(0, +)
            }
        }
        
        if !currentChunk.isEmpty {
            chunks.append(currentChunk.joined(separator: " "))
        }
        
        return chunks
    }
}
