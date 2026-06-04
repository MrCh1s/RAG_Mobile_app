import Foundation
import SwiftUI
import CoreML
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
    
    // Mô hình CoreML sinh Vector
    private var embeddingModel: MLModel?
    private var tokenizer: BERTTokenizer?
    
    // Đường dẫn tới file database trong Bundle
    private var dbPath: String {
        return Bundle.main.path(forResource: "notes", ofType: "db") ?? ""
    }
    
    init() {
        NSLog("DEBUG: RAGViewModel starting MLCEngine on iOS...")
        // Tên model phải khớp với ID trong mlc-package-config.json
        self.engine = MLCEngine("Qwen2.5-1.5B-Instruct-q4f16_1-MLC")
        NSLog("DEBUG: MLCEngine object created")
        
        // Khởi tạo Embedding Model offline
        loadEmbeddingModel()
        
        // Khởi tạo Tokenizer (Tìm trong folder bundle trước)
        var vocabURL = Bundle.main.url(forResource: "vocab", withExtension: "txt", subdirectory: "bundle")
        if vocabURL == nil {
            vocabURL = Bundle.main.url(forResource: "vocab", withExtension: "txt")
        }
        
        if let finalVocabURL = vocabURL {
            self.tokenizer = BERTTokenizer(vocabURL: finalVocabURL)
        }
    }
    
    private func loadEmbeddingModel() {
        // Tải mô hình Vietnamese_SBERT_CoreML đã convert từ Python script
        // Tìm trong thư mục con "bundle" trước (theo cấu trúc CI build mới), nếu không có thì tìm ở root
        var modelURL = Bundle.main.url(forResource: "Vietnamese_SBERT_CoreML", withExtension: "mlmodelc", subdirectory: "bundle")
        if modelURL == nil {
            modelURL = Bundle.main.url(forResource: "Vietnamese_SBERT_CoreML", withExtension: "mlmodelc")
        }
        
        guard let finalModelURL = modelURL else {
            NSLog("Cảnh báo: Không tìm thấy file Vietnamese_SBERT_CoreML.mlmodelc trong Xcode Bundle.")
            return
        }
        do {
            self.embeddingModel = try MLModel(contentsOf: finalModelURL)
            NSLog("DEBUG: Đã tải thành công mô hình sinh Vector Tiếng Việt Offline.")
        } catch {
            NSLog("Lỗi khi tải CoreML: \(error)")
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

    // ==========================================
    // MODULE: Mã hóa Câu hỏi thành Vector Offline
    // ==========================================
    private func generateVectorFromCoreML(text: String) -> [Float] {
        guard let model = embeddingModel, let tokenizer = tokenizer else {
            print("Chưa có model hoặc tokenizer.")
            return []
        }
        
        let maxLen = 128
        let tokens = tokenizer.tokenize(text: text, maxLen: maxLen)
        
        do {
            // 1. Chuẩn bị đầu vào cho CoreML
            let inputIdsArray = try MLMultiArray(shape: [1, maxLen as NSNumber], dataType: .int32)
            let attentionMaskArray = try MLMultiArray(shape: [1, maxLen as NSNumber], dataType: .int32)
            
            for i in 0..<maxLen {
                inputIdsArray[i] = tokens.inputIds[i] as NSNumber
                attentionMaskArray[i] = tokens.attentionMask[i] as NSNumber
            }
            
            // 2. Chạy Model Inference
            let inputProvider = try MLDictionaryFeatureProvider(dictionary: [
                "input_ids": inputIdsArray,
                "attention_mask": attentionMaskArray
            ])
            
            let output = try model.prediction(from: inputProvider)
            
            // 3. Xử lý Output (Mean Pooling)
            // Giả sử output name là "last_hidden_state" với shape (1, 128, 768)
            guard let lastHiddenState = output.featureValue(for: "last_hidden_state")?.multiArrayValue else {
                return []
            }
            
            let seqLen = 128
            let hiddenSize = 768 // Thường là 768 cho BERT-base
            var sentenceEmbedding = [Float](repeating: 0, count: hiddenSize)
            
            // Tính trung bình cộng của tất cả các token (Mean Pooling đơn giản)
            for h in 0..<hiddenSize {
                var sum: Float = 0
                for s in 0..<seqLen {
                    // Truy cập index trong MLMultiArray: [batch, seq, hidden] -> index = s * hiddenSize + h
                    sum += lastHiddenState[s * hiddenSize + h].floatValue
                }
                sentenceEmbedding[h] = sum / Float(seqLen)
            }
            
            return sentenceEmbedding
            
        } catch {
            print("Lỗi sinh Vector CoreML: \(error)")
            return []
        }
    }

    // ==========================================
    // MODULE: Tìm kiếm Database (Vecto + SQLite)
    // ==========================================
    func searchDatabaseOffline(question: String) -> [String] {
        // 1. Sinh vector từ câu hỏi
        let questionVector = generateVectorFromCoreML(text: question)
        
        var results: [(content: String, score: Float)] = []
        
        // 2. TÌM KIẾM THEO TỪ KHÓA (Ghi chú cũ)
        let keywords = question.components(separatedBy: .whitespacesAndNewlines).filter { $0.count > 2 }
        for word in keywords {
            let matches = LocalDatabase.shared.searchNotes(keyword: word)
            for match in matches {
                results.append((content: match, score: 0.5)) // Gán điểm cơ bản cho từ khóa
            }
        }
        
        // 3. TÌM KIẾM THEO NGỮ NGHĨA (Tài liệu PDF mới)
        if !questionVector.isEmpty {
            let allChunks = LocalDatabase.shared.getAllChunks()
            for chunk in allChunks {
                guard let chunkVector = chunk.embedding else { continue }
                let score = cosineSimilarity(questionVector, chunkVector)
                
                // Chỉ lấy các đoạn có độ tương đồng cao (> 0.6)
                if score > 0.6 {
                    results.append((content: chunk.content, score: score))
                }
            }
        }
        
        // Sắp xếp theo điểm số từ cao xuống thấp và lấy top 3
        let topResults = results.sorted { $0.score > $1.score }
                                .prefix(3)
                                .map { $0.content }
                                
        return Array(topResults)
    }
    
    // ==========================================
    // MODULE: Xử lý tài liệu (PDF/Khoa học)
    // ==========================================
    func processDocument(at url: URL) async {
        // Yêu cầu quyền truy cập file (đối với file từ app Files)
        guard url.startAccessingSecurityScopedResource() else {
            await updateChatLog("\n[Lỗi] Không có quyền truy cập tài liệu.", isTyping: false)
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        await updateChatLog("\n[Hệ thống] Đang đọc tài liệu: \(url.lastPathComponent)...", isTyping: true)
        
        // 1. Trích xuất text từ PDF
        guard let text = PDFManager.shared.extractText(from: url) else {
            await updateChatLog("\n[Lỗi] Không thể trích xuất văn bản từ PDF.", isTyping: false)
            return
        }
        
        // 2. Chia nhỏ văn bản (Chunking)
        let chunks = PDFManager.shared.chunkText(text)
        
        // 3. Lưu thông tin tài liệu vào DB
        let docId = LocalDatabase.shared.insertDocument(name: url.lastPathComponent)
        
        // 4. Sinh vector và lưu từng đoạn văn bản
        var successCount = 0
        for chunk in chunks {
            let vector = generateVectorFromCoreML(text: chunk)
            
            // Lưu vào database (kể cả khi vector rỗng - fallback)
            LocalDatabase.shared.insertChunk(documentId: docId, content: chunk, embedding: vector)
            if !vector.isEmpty { successCount += 1 }
        }
        
        await updateChatLog("\n[Thành công] Đã nạp tài liệu. Đã vector hóa \(successCount)/\(chunks.count) đoạn văn bản.", isTyping: false)
    }
    
    // ==========================================
    // MODULE: Vận hành LLM Chat (RAG Chatbot)
    // ==========================================
    func sendMessage(userInput: String) async {
        await updateChatLog("\nNhập câu hỏi: \(userInput)", isTyping: true)
        
        // 1. Quét Database lấy ngữ cảnh
        let ragContexts = searchDatabaseOffline(question: userInput)
        
        // 2. Chặn Hallucination
        if ragContexts.isEmpty {
            await updateChatLog("\n=> Hệ thống: Không tìm thấy mảnh dữ liệu trong Sổ tay. Từ chối trả lời.\n", isTyping: false)
            return
        }
        
        // 3. Xây dựng Prompt
        let contextText = ragContexts.map { "- \($0)" }.joined(separator: "\n")
        let finalPrompt = "TÀI LIỆU SỔ TAY:\n\(contextText)\n\nLệnh của sếp: \(userInput)"
        
        await updateChatLog("\n Qwen2.5: ", isTyping: true)
        
        // 4. Sinh phản hồi
        if let engine = engine {
            do {
                let stream = try await engine.chat.completions.create(
                    messages: [
                        [.role: "system", .content: "Bạn là Trợ lý AI cá nhân chuyên tra cứu sổ tay. Nhiệm vụ của bạn là trả lời câu hỏi dựa TRỰC TIẾP và DUY NHẤT vào tài liệu được cung cấp. Trả lời cực kỳ ngắn gọn (1-2 câu), không lặp lại thông tin. Nếu không có thông tin, hãy từ chối trả lời."],
                        [.role: "user", .content: finalPrompt]
                    ],
                    repetition_penalty: 1.15,
                    max_tokens: 128
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
    
    // Helper để cập nhật UI
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
}
