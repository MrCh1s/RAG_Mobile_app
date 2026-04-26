import Foundation
import SwiftUI
import MLCChat // Thư viện lõi của MLC-LLM dành cho iOS

/**
 * File này mô phỏng lại 100% tệp 'run_test.py' để chạy ứng dụng trên hệ sinh thái Apple (iOS/iPadOS).
 * Lưu ý: Bạn sẽ cần nhúng file này vào dự án Xcode.
 */

class RAGViewModel: ObservableObject {
    @Published var chatLog: String = ""
    @Published var isTyping = false
    
    // Core Engine của MLC-LLM
    private var engine: MLCEngine?
    
    // Đường dẫn tới file database trong Bundle
    private var dbPath: String {
        return Bundle.main.path(forResource: "notes", ofType: "db") ?? ""
    }
    
    init() {
        print("Đang khởi tạo MLCEngine trên thiết bị iOS...")
        // Tên model phải khớp với ID trong mlc-package-config.json
        self.engine = MLCEngine("Qwen2.5-1.5B-Instruct")
    }
    
    // ==========================================
    // MODULE: Tìm kiếm Database (Vecto + SQLite)
    // ==========================================
    func searchDatabaseOffline(question: String) -> [String] {
        // 1. Sinh Vector từ câu hỏi (Cần model CoreML tương ứng)
        let questionVector = generateVectorFromCoreML(text: question)
        if questionVector.isEmpty {
            print("Cảnh báo: Không thể tạo vector cho câu hỏi.")
            return []
        }
        
        // 2. Tra cứu SQLite và tính toán độ tương đồng
        return fetchFromSQLiteNative(vector: questionVector, threshold: 0.6)
    }
    
    // ==========================================
    // MODULE: Vận hành LLM Chat
    // ==========================================
    func sendMessage(userInput: String) async {
        await updateChatLog("\nNhập câu hỏi: \(userInput)", isTyping: true)
        
        // 1. Quét Database lấy ngữ cảnh
        let ragContexts = searchDatabaseOffline(question: userInput)
        
        // 2. Kiểm tra nếu không có dữ liệu (Chặn Hallucination)
        if ragContexts.isEmpty {
            await updateChatLog("\n=> Hệ thống: Không tìm thấy dữ liệu liên quan trong Sổ tay.\n", isTyping: false)
            return
        }
        
        // 3. Xây dựng Prompt từ ngữ cảnh đã tìm thấy
        let contextText = ragContexts.map { "- \($0)" }.joined(separator: "\n")
        let finalPrompt = "Đây là TÀI LIỆU SỔ TAY:\n\(contextText)\n\nCâu hỏi: \(userInput)"
        
        await updateChatLog("\n Qwen2.5: ", isTyping: true)
        
        // 4. Sinh phản hồi từ LLM
        if let engine = engine {
            do {
                let stream = try await engine.chat.completions.create(
                    messages: [
                        [.role: "system", .content: "Bạn là Trợ lý AI cá nhân. Bạn CHỈ ĐƯỢC phép dùng dữ kiện trong phần TÀI LIỆU SỔ TAY. Nếu thông tin không có, hãy trả lời là \"không tìm thấy\"."],
                        [.role: "user", .content: finalPrompt]
                    ]
                )
                
                for try await chunk in stream {
                    if let content = chunk.choices.first?.delta.content {
                        await updateChatLog(content, append: true)
                    }
                }
            } catch {
                print("Lỗi Generation: \(error)")
                await updateChatLog("\n[Lỗi: \(error.localizedDescription)]")
            }
        }
        
        await updateChatLog("\n", isTyping: false)
    }
    
    // Helper để cập nhật UI từ Background Thread
    @MainActor
    private func updateChatLog(_ text: String, isTyping: Bool? = nil, append: Bool = true) {
        if append {
            self.chatLog += text
        } else {
            self.chatLog = text
        }
        if let typing = isTyping {
            self.isTyping = typing
        }
    }

    // ==========================================
    // MODULE: Phép tính Vector (Cosine Similarity)
    // ==========================================
    private func cosineSimilarity(_ v1: [Float], _ v2: [Float]) -> Float {
        guard v1.count == v2.count && v1.count > 0 else { return 0.0 }
        
        var dotProduct: Float = 0.0
        var normV1: Float = 0.0
        var normV2: Float = 0.0
        
        for i in 0..<v1.count {
            dotProduct += v1[i] * v2[i]
            normV1 += v1[i] * v1[i]
            normV2 += v2[i] * v2[i]
        }
        
        let denom = sqrt(normV1) * sqrt(normV2)
        return denom == 0 ? 0.0 : dotProduct / denom
    }

    // ------- Logic kết nối Database thật -------
    private func fetchFromSQLiteNative(vector: [Float], threshold: Float) -> [String] {
        // Tạm thời dùng Keyword Search từ câu hỏi vì chưa có model Embedding CoreML
        // Đây là giải pháp "No-Mac" hiệu quả nhất.
        return LocalDatabase.shared.searchNotes(keyword: "") // keyword sẽ được xử lý ở searchDatabaseOffline
    }
    
    func searchDatabaseOffline(question: String) -> [String] {
        // Giải pháp No-Mac: Tìm kiếm từ khóa trực tiếp từ câu hỏi
        // (Trong tương lai, bạn có thể tách keyword quan trọng từ question)
        let keywords = question.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 2 } // Lọc các từ ngắn
        
        var allResults: Set<String> = []
        for word in keywords {
            let matches = LocalDatabase.shared.searchNotes(keyword: word)
            for match in matches {
                allResults.insert(match)
            }
        }
        
        return Array(allResults.prefix(3))
    }
    
    private func generateVectorFromCoreML(text: String) -> [Float] {
        return [] 
    }
}
