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
    
    init() {
        print("Đang khởi tạo MLCEngine trên thiết bị iOS...")
        // Trên iOS, MLCEngine MẶC ĐỊNH SẼ TỰ ĐỘNG GỌI METAL (Card đồ hoạ của iPhone)
        // Bạn không cần phải khai báo device="metal" như trên Python.
        self.engine = MLCEngine("qwen2.5-1.5b-instruct-q4f16_1-MLC")
    }
    
    // ==========================================
    // MODULE: Tìm kiếm Database (Thay thế cho bge-m3 + SQLite Python)
    // ==========================================
    func searchDatabaseOffline(question: String) -> [String] {
        // [CẦN LƯU Ý KHI CODE TRÊN XCODE]
        // 1. Sinh Vector: Apple không có Ollama. Bạn phải xuất mô hình bge-m3 sang định dạng .mlmodel (CoreML)
        // và dùng hàm của Apple để biến chữ thành vector (Hoặc dùng thư viện llama.cpp trên iOS).
        let questionVector = generateVectorFromCoreML(text: question)
        
        // 2. Tra cứu SQLite: Trên iOS, bạn cài thư viện "SQLite.swift", nó sẽ chọc vào file notes.db y hệt Python
        let matchedNotes = fetchFromSQLiteNative(vector: questionVector, threshold: 0.6)
        
        return matchedNotes
    }
    
    // ==========================================
    // MODULE: Vận hành LLM Chat (Nhái lại vòng lặp while True)
    // ==========================================
    func sendMessage(userInput: String) async {
        DispatchQueue.main.async {
            self.chatLog += "\nNhập câu hỏi: \(userInput)"
            self.isTyping = true
        }
        
        // 1. Quét Database
        let ragContexts = searchDatabaseOffline(question: userInput)
        
        // 2. Chặn đứt mạch nếu không có đáp án (Y hệt dòng 66 Python)
        if ragContexts.isEmpty {
            DispatchQueue.main.async {
                self.chatLog += "\n=> Hệ thống: Không tìm thấy dữ liệu liên quan trong Sổ tay. Yêu cầu truy vấn bị từ chối nhằm đảm bảo tính chính xác.\n"
                self.isTyping = false
            }
            return
        }
        
        // 3. Có đáp án -> Gộp Prompt như Python (Y hệt dòng 71 Python)
        let contextText = ragContexts.map { "- \($0)" }.joined(separator: "\n")
        let finalPrompt = "Đây là TÀI LIỆU SỔ TAY:\n\(contextText)\n\nCâu hỏi lệnh: \(userInput)"
        
        DispatchQueue.main.async {
            self.chatLog += "\n Qwen2.5: "
        }
        
        // 4. Sinh chữ (Streaming) bằng Chip A16 Bionic 
        // Lệnh Async/Await này nhái lại vòng lặp "for chunk in engine.chat.completions..." bên Python
        if let engine = engine {
            do {
                let stream = try await engine.chat.completions.create(
                    messages: [
                        [.role: "system", .content: "Bạn là Trợ lý AI cá nhân. Bạn CHỈ ĐƯỢC phép dùng dữ kiện trong phần TÀI LIỆU SỔ TAY."],
                        [.role: "user", .content: finalPrompt]
                    ]
                )
                
                for try await chunk in stream {
                    if let content = chunk.choices.first?.delta.content {
                        DispatchQueue.main.async {
                            self.chatLog += content // Chữ tuôn ra màn hình iPhone
                        }
                    }
                }
            } catch {
                print("Lỗi khi sinh chữ: \(error)")
            }
        }
        
        DispatchQueue.main.async {
            self.chatLog += "\n"
            self.isTyping = false
        }
    }
    
    // ------- Các hàm ảo (Bạn sẽ thiết lập bên trong Xcode sau) -------
    private func generateVectorFromCoreML(text: String) -> [Float] { return [] }
    private func fetchFromSQLiteNative(vector: [Float], threshold: Float) -> [String] { 
        return ["Ví dụ: Tủ lạnh để trữ đồ ăn"] 
    }
}
