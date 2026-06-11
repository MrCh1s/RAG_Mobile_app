//
//  ChatState.swift
//  LLMChat
//

import Foundation
import MLCSwift
import os

enum MessageRole {
    case user
    case assistant
}

extension MessageRole {
    var isUser: Bool { self == .user }
}

struct MessageData: Hashable {
    let id = UUID()
    var role: MessageRole
    var message: String
}

final class ChatState: ObservableObject {
    fileprivate enum ModelChatState {
        case generating
        case resetting
        case reloading
        case terminating
        case ready
        case failed
        case pendingImageUpload
        case processingImage
    }

    @Published var displayMessages = [MessageData]()
    @Published var infoText = ""
    @Published var legacyUseImage = false
    @Published var ramUsageText = ""

    private let modelChatStateLock = NSLock()
    private var modelChatState: ModelChatState = .ready

    // the new mlc engine
    private let engine = MLCEngine()
    // history messages
    private var historyMessages = [ChatCompletionMessage]()

    // streaming text that get updated
    private var streamingText = ""

    private var modelLib = ""
    private var modelPath = ""
    var modelID = ""
    var displayName = ""

    init() {
        startMemoryMonitoring()
    }

    private func startMemoryMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.ramUsageText = "RAM: \(MemoryUtil.getMemoryUsageString())"
            }
        }
    }

    var isInterruptible: Bool {
        return getModelChatState() == .ready
        || getModelChatState() == .generating
        || getModelChatState() == .failed
        || getModelChatState() == .pendingImageUpload
    }

    var isChattable: Bool {
        return getModelChatState() == .ready
    }

    var isUploadable: Bool {
        return getModelChatState() == .pendingImageUpload
    }

    var isResettable: Bool {
        return getModelChatState() == .ready
        || getModelChatState() == .generating
    }

    func requestResetChat() {
        assert(isResettable)
        interruptChat(prologue: {
            switchToResetting()
        }, epilogue: { [weak self] in
            self?.mainResetChat()
        })
    }

    // reset the chat if we switch to background
    // during generation to avoid permission issue
    func requestSwitchToBackground() {
        if (getModelChatState() == .generating) {
            self.requestResetChat()
        }
    }


    func requestTerminateChat(callback: @escaping () -> Void) {
        assert(isInterruptible)
        interruptChat(prologue: {
            switchToTerminating()
        }, epilogue: { [weak self] in
            self?.mainTerminateChat(callback: callback)
        })
    }

    func requestReloadChat(modelID: String, modelLib: String, modelPath: String, estimatedVRAMReq: Int, displayName: String) {
        debugLog("requestReloadChat called for \(modelID)")
        if (isCurrentModel(modelID: modelID)) {
            return
        }
        assert(isInterruptible)
        interruptChat(prologue: {
            switchToReloading()
        }, epilogue: { [weak self] in
            self?.mainReloadChat(modelID: modelID,
                                 modelLib: modelLib,
                                 modelPath: modelPath,
                                 estimatedVRAMReq: estimatedVRAMReq,
                                 displayName: displayName)
        })
    }


    func requestGenerate(prompt: String) {
        assert(isChattable)
        switchToGenerating()
        
        // RAG Logic: Semantic search - chỉ lấy tối đa 8 ghi chú liên quan nhất với câu hỏi
        let relevantNotes = LocalDatabase.shared.searchRelevantNotes(query: prompt, topK: 8)
        
        // Format notes - giới hạn số ký tự để tránh OOM
        var context = ""
        var currentLength = 0
        let maxContextChars = 3000 // Chặt chặt hơn vì đã lọc từ trước
        
        for note in relevantNotes {
            let noteStr = "- \(note.createdAt): \(note.content)\n"
            if currentLength + noteStr.count < maxContextChars {
                context += noteStr
                currentLength += noteStr.count
            } else {
                break
            }
        }
        
        let systemPrompt = """
        BẠN LÀ MỘT TRỢ LÝ SỔ TAY THÔNG MINH.
        CHỈ SỬ DỤNG NHỮNG THÔNG TIN DƯỚI ĐÂY ĐỂ TRẢ LỜI CÂU HỎI CỦA NGƯỜI DÙNG:
        
        === NỘI DUNG SỔ TAY ===
        \(context.isEmpty ? "(Sổ tay hiện đang trống)" : context)
        ========================
        
        QUY TẮC BẮT BUỘC:
        1. CHỈ trả lời dựa trên nội dung trong mục "NỘI DUNG SỔ TAY".
        2. Nếu câu hỏi không có thông tin trong sổ tay, bạn PHẢI trả lời: "Xin lỗi, thông tin này không có trong sổ tay của bạn. Bạn có muốn ghi chú thêm không?"
        3. TUYỆT ĐỐI không sử dụng kiến thức bên ngoài, không tìm kiếm web.
        4. Trả lời bằng tiếng Việt, súc tích và chính xác.
        """
        
        appendMessage(role: .user, message: prompt)
        appendMessage(role: .assistant, message: "")
        
        Task {
            // Thêm câu hỏi thuần túy của người dùng vào lịch sử chat (không chứa systemPrompt)
            self.historyMessages.append(
                ChatCompletionMessage(role: .user, content: prompt)
            )
            
            // Tạo mảng message tạm thời để gửi đi cho lần chat này
            var currentRequestMessages = self.historyMessages
            if let lastMsg = currentRequestMessages.last {
                let combinedContent = """
                \(systemPrompt)

                CÂU HỎI CỦA NGƯỜI DÙNG:
                \(lastMsg.content ?? "")
                """
                // Ghi đè tin nhắn cuối cùng (user) bằng nội dung đã kẹp RAG context
                currentRequestMessages[currentRequestMessages.count - 1] = ChatCompletionMessage(role: .user, content: combinedContent)
            }
            
            var finishReasonLength = false
            var finalUsageTextLabel = ""

            for await res in await engine.chat.completions.create(
                messages: currentRequestMessages,
                stream_options: StreamOptions(include_usage: true)
            ) {
                for choice in res.choices {
                    if let content = choice.delta.content {
                        self.streamingText += content.asText()
                    }
                    if let finish_reason = choice.finish_reason {
                        if finish_reason == "length" {
                            finishReasonLength = true
                        }
                    }
                }
                if let finalUsage = res.usage {
                    finalUsageTextLabel = finalUsage.extra?.asTextLabel() ?? ""
                }
                if getModelChatState() != .generating {
                    break
                }

                var updateText = self.streamingText
                if finishReasonLength {
                    updateText += " [output truncated due to context length limit...]"
                }

                let newText = updateText
                DispatchQueue.main.async {
                    self.updateMessage(role: .assistant, message: newText)
                }
            }

            // Record history messages
            if !self.streamingText.isEmpty {
                self.historyMessages.append(
                    ChatCompletionMessage(role: .assistant, content: self.streamingText)
                )
                self.streamingText = ""
            } else {
                // Xóa user message vừa append nếu AI không trả lời được
                self.historyMessages.removeLast()
            }

            // FIX: Cắt bớt lịch sử chat nếu quá dài
            if finishReasonLength {
                // historyMessages = [user, assistant, user, assistant, ...]
                // Số lượng tin nhắn phải là số chẵn. Ta xóa cặp cũ nhất ở đầu.
                let conversationCount = self.historyMessages.count
                if conversationCount >= 4 {
                    // Xóa cặp user+assistant cũ nhất (index 0 và 1)
                    self.historyMessages.removeSubrange(0..<2)
                }
            }

            if getModelChatState() == .generating {
                let runtimStats = finalUsageTextLabel
                DispatchQueue.main.async {
                    self.infoText = runtimStats
                    self.switchToReady()
                }
            }
        }
    }

    func isCurrentModel(modelID: String) -> Bool {
        return self.modelID == modelID
    }
}

private extension ChatState {
    func getModelChatState() -> ModelChatState {
        modelChatStateLock.lock()
        defer { modelChatStateLock.unlock() }
        return modelChatState
    }

    func setModelChatState(_ newModelChatState: ModelChatState) {
        modelChatStateLock.lock()
        modelChatState = newModelChatState
        modelChatStateLock.unlock()
    }

    func appendMessage(role: MessageRole, message: String) {
        displayMessages.append(MessageData(role: role, message: message))
    }

    func updateMessage(role: MessageRole, message: String) {
        displayMessages[displayMessages.count - 1] = MessageData(role: role, message: message)
    }

    func clearHistory() {
        displayMessages.removeAll()
        infoText = ""
        historyMessages.removeAll()
        streamingText = ""
    }

    func switchToResetting() {
        setModelChatState(.resetting)
    }

    func switchToGenerating() {
        setModelChatState(.generating)
    }

    func switchToReloading() {
        setModelChatState(.reloading)
    }

    func switchToReady() {
        setModelChatState(.ready)
    }

    func switchToTerminating() {
        setModelChatState(.terminating)
    }

    func switchToFailed() {
        setModelChatState(.failed)
    }

    func switchToPendingImageUpload() {
        setModelChatState(.pendingImageUpload)
    }

    func switchToProcessingImage() {
        setModelChatState(.processingImage)
    }

    func interruptChat(prologue: () -> Void, epilogue: @escaping () -> Void) {
        assert(isInterruptible)
        if getModelChatState() == .ready
            || getModelChatState() == .failed
            || getModelChatState() == .pendingImageUpload {
            prologue()
            epilogue()
        } else if getModelChatState() == .generating {
            prologue()
            DispatchQueue.main.async {
                epilogue()
            }
        } else {
            assert(false)
        }
    }

    func mainResetChat() {
        Task {
            self.historyMessages = []
            self.streamingText = ""

            DispatchQueue.main.async {
                self.clearHistory()
                self.switchToReady()
            }
        }
    }

    func mainTerminateChat(callback: @escaping () -> Void) {
        Task {
            await engine.unload()
            DispatchQueue.main.async {
                self.clearHistory()
                self.modelID = ""
                self.modelLib = ""
                self.modelPath = ""
                self.displayName = ""
                self.legacyUseImage = false
                self.switchToReady()
                callback()
            }
        }
    }

    func mainReloadChat(modelID: String, modelLib: String, modelPath: String, estimatedVRAMReq: Int, displayName: String) {
        clearHistory()
        self.modelID = modelID
        self.modelLib = modelLib
        self.modelPath = modelPath
        self.displayName = displayName

        Task {
            DispatchQueue.main.async {
                self.appendMessage(role: .assistant, message: "[System] Initalize...")
            }

            debugLog("Starting mainReloadChat for modelID: \(modelID)")
            debugLog("modelPath: \(modelPath)")
            debugLog("modelLib: \(modelLib)")

            await engine.unload()
            debugLog("Engine unloaded")

            let vRAM = os_proc_available_memory()
            debugLog("Available memory: \(vRAM) bytes")
            
            // Log file listing for debugging
            debugLog("Checking files at modelPath: \(modelPath)")
            let fileManager = FileManager.default
            do {
                let files = try fileManager.contentsOfDirectory(atPath: modelPath)
                debugLog("Files found (\(files.count)): \(files.joined(separator: ", "))")
                
                // Read and log mlc-chat-config.json
                let configPath = (modelPath as NSString).appendingPathComponent("mlc-chat-config.json")
                if fileManager.fileExists(atPath: configPath) {
                    let configContent = try String(contentsOfFile: configPath, encoding: .utf8)
                    debugLog("mlc-chat-config.json content: \(configContent)")
                } else {
                    debugLog("mlc-chat-config.json NOT FOUND at \(configPath)")
                }
            } catch {
                debugLog("Error listing files at modelPath: \(error.localizedDescription)")
            }

            if (vRAM < estimatedVRAMReq) {
                let requiredMemory = String (
                    format: "%.1fMB", Double(estimatedVRAMReq) / Double(1 << 20)
                )
                let errorMessage = (
                    "Sorry, the system cannot provide \(requiredMemory) VRAM as requested to the app, " +
                    "so we cannot initialize this model on this device."
                )
                debugLog("Insufficient memory. Required: \(estimatedVRAMReq)")
                DispatchQueue.main.sync {
                    self.displayMessages.append(MessageData(role: MessageRole.assistant, message: errorMessage))
                    self.switchToFailed()
                }
                return
            }

            debugLog("Calling engine.reload...")
            await engine.reload(
                modelPath: modelPath, modelLib: modelLib
            )
            debugLog("engine.reload completed successfully")

            // TODO(mlc-team) run a system message prefill
            DispatchQueue.main.async {
                self.updateMessage(role: .assistant, message: "[System] Ready to chat")
                self.switchToReady()
            }

        }
    }
}

extension ChatState {
    // AI helper to clean up note text
    func cleanUpNoteText(rawText: String) async -> String {
        guard isChattable else { return rawText }
        
        DispatchQueue.main.async { self.switchToGenerating() }
        defer { DispatchQueue.main.async { self.switchToReady() } }
        
        let systemPrompt = """
        Bạn là chuyên gia biên tập. Nhiệm vụ của bạn là chuẩn hóa và sửa lỗi chính tả ghi chú thô của người dùng. 
        CHÚ Ý: Dựa vào ngữ cảnh tiếng Việt để sửa lỗi gõ vội/teencode. KHÔNG dịch sang tiếng Anh.
        
        QUY TẮC BẮT BUỘC:
        - CHỈ in ra nội dung đã sửa dưới dạng 1 đoạn văn duy nhất.
        - KHÔNG giải thích, KHÔNG thêm bất kỳ câu giao tiếp nào (ví dụ: không nói 'Đây là...', 'Dưới đây là...').
        - KHÔNG sử dụng ký hiệu markdown.

        Ví dụ:
        Input: "hôm nay tôi đi sthi mua táo, cá. quên mất còn phải mua dao cạo râu nữa, chán thế"
        Output: "Hôm nay tôi đi siêu thị mua táo, cá. Quên mất còn phải mua dao cạo râu nữa, chán thế."

        Input: "mai 9h sáng họp vs team mkt"
        Output: "Mai 9h sáng họp với team Marketing."
        """
        let fullPrompt = """
        \(systemPrompt)

        Input: "\(rawText)"
        Output:
        """
        let messages = [
            ChatCompletionMessage(role: .user, content: fullPrompt)
        ]
        
        var replyText = ""
        
        for await res in await engine.chat.completions.create(
            messages: messages,
            stream_options: StreamOptions(include_usage: true),
            temperature: 0.1
        ) {
            for choice in res.choices {
                if let content = choice.delta.content {
                    replyText += content.asText()
                }
            }
        }
        
        let result = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? rawText : result
    }

    // AI helper to classify and tag note text
    func classifyAndTagNoteText(rawText: String) async -> (folder: String, tags: [String]) {
        guard isChattable else { return ("Khác", []) }
        
        DispatchQueue.main.async { self.switchToGenerating() }
        defer { DispatchQueue.main.async { self.switchToReady() } }
        
        let systemPrompt = """
        Bạn là một hệ thống phân loại dữ liệu tự động. Nhiệm vụ của bạn là đọc ghi chú của người dùng và xếp nó vào MỘT VÀ CHỈ MỘT danh mục (folder) phù hợp nhất từ danh sách sau:

        1. "Công việc": Lịch họp, dự án, deadline, công tác, nhiệm vụ công ty.
        2. "Học tập": Kiến thức lý thuyết, thuật toán, bài tập, ôn thi, nghiên cứu.
        3. "Gia đình": Mua sắm đồ dùng, việc nhà, chăm sóc con cái, liên hoan.
        4. "Tài chính": Chi tiêu, thanh toán hóa đơn eBanking, đóng tiền, nhắc nợ.
        5. "Ý tưởng": Những ý tưởng bất chợt, dự định cá nhân, sáng tạo.
        6. "Sức khỏe": Tập luyện thể thao, chạy bộ, chế độ ăn kiêng, khám bệnh.
        7. "Khác": Nếu không thuộc bất kỳ nhóm nào ở trên.

        QUY TẮC BẮT BUỘC:
        - CHỈ output ra một chuỗi JSON chuẩn xác theo định dạng: {"folder": "TênDanhMục", "tags": ["tag1", "tag2"]}.
        - KHÔNG giải thích, KHÔNG chào hỏi, KHÔNG thêm bất kỳ ký tự nào ngoài JSON.

        Ví dụ:
        Input: "Ngày mai 9h sáng họp với team Marketing về chiến dịch mới."
        Output: {"folder": "Công việc", "tags": ["họp", "marketing"]}

        Input: "Cần tìm hiểu cách tối ưu hàm tính khoảng cách bằng C++."
        Output: {"folder": "Học tập", "tags": ["lập trình", "c++"]}

        Input: "Nhớ nộp tiền điện và tiền nước tháng này."
        Output: {"folder": "Tài chính", "tags": ["hóa đơn", "thanh toán"]}
        """
        
        let fullPrompt = """
        \(systemPrompt)

        Input: \(rawText)
        Output:
        """
        let messages = [
            ChatCompletionMessage(role: .user, content: fullPrompt)
        ]
        
        var replyText = ""
        
        for await res in await engine.chat.completions.create(
            messages: messages,
            stream_options: StreamOptions(include_usage: true),
            temperature: 0.1
        ) {
            for choice in res.choices {
                if let content = choice.delta.content {
                    replyText += content.asText()
                }
            }
        }
        
        replyText = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var folder = "Khác"
        var tags: [String] = []
        
        var cleanJSON = replyText
        if cleanJSON.contains("```") {
            if cleanJSON.contains("```json") {
                if let range = cleanJSON.range(of: "```json") {
                    let suffix = cleanJSON[range.upperBound...]
                    if let endRange = suffix.range(of: "```") {
                        cleanJSON = String(suffix[..<endRange.lowerBound])
                    }
                }
            } else {
                let parts = cleanJSON.components(separatedBy: "```")
                if parts.count >= 3 {
                    cleanJSON = parts[1]
                }
            }
        }
        
        cleanJSON = cleanJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let data = cleanJSON.data(using: .utf8) {
            do {
                if let jsonDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    if let f = jsonDict["folder"] as? String {
                        folder = f
                    }
                    if let t = jsonDict["tags"] as? [String] {
                        tags = t
                    } else if let tStr = jsonDict["tags"] as? String {
                        tags = [tStr]
                    }
                }
            } catch {
                print("Lỗi parse JSON: \(error). Raw: \(replyText)")
            }
        }
        
        return (folder, tags)
    }
}
