import Foundation
import SQLite3

class LocalDatabase {
    static let shared = LocalDatabase()
    private var db: OpaquePointer?
    
    struct Note: Identifiable {
        let id: Int32
        let content: String
        let folderName: String
        let tags: String
        let createdAt: String
    }

    struct DocumentChunk {
        let id: Int32
        let documentId: Int32
        let content: String
        let embedding: [Float]?
    }
    
    private init() {
        openDatabase()
        createTables()
    }
    
    private func openDatabase() {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dbPath = documentsURL.appendingPathComponent("notes.db").path
        
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("Lỗi: Không thể mở database")
        }
    }
    
    private func createTables() {
        let createTableString = """
        CREATE TABLE IF NOT EXISTS notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content TEXT NOT NULL,
            folder_name TEXT DEFAULT 'Chưa phân loại',
            tags TEXT DEFAULT '',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS documents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS document_chunks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            document_id INTEGER,
            content TEXT NOT NULL,
            embedding BLOB,
            FOREIGN KEY(document_id) REFERENCES documents(id)
        );
        """
        
        var createTableStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) == SQLITE_DONE {
                print("Bảng notes đã sẵn sàng.")
            } else {
                print("Lỗi: Không thể tạo bảng notes.")
            }
        }
        sqlite3_finalize(createTableStatement)

        // Run migrations for old databases
        let addFolderColumnString = "ALTER TABLE notes ADD COLUMN folder_name TEXT DEFAULT 'Chưa phân loại';"
        var addFolderStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, addFolderColumnString, -1, &addFolderStatement, nil) == SQLITE_OK {
            sqlite3_step(addFolderStatement)
        }
        sqlite3_finalize(addFolderStatement)
        
        let addTagsColumnString = "ALTER TABLE notes ADD COLUMN tags TEXT DEFAULT '';"
        var addTagsStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, addTagsColumnString, -1, &addTagsStatement, nil) == SQLITE_OK {
            sqlite3_step(addTagsStatement)
        }
        sqlite3_finalize(addTagsStatement)
    }
    
    func insertNote(content: String, folderName: String = "Chưa phân loại", tags: String = "") {
        let insertStatementString = "INSERT INTO notes (content, folder_name, tags) VALUES (?, ?, ?);"
        var insertStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertStatementString, -1, &insertStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(insertStatement, 1, (content as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 2, (folderName as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 3, (tags as NSString).utf8String, -1, nil)
            
            if sqlite3_step(insertStatement) == SQLITE_DONE {
                print("Đã thêm ghi chú thành công.")
            } else {
                print("Lỗi: Thêm ghi chú thất bại.")
            }
        }
        sqlite3_finalize(insertStatement)
    }
    
    func fetchAllNotes() -> [Note] {
        let queryStatementString = "SELECT id, content, folder_name, tags, created_at FROM notes ORDER BY created_at DESC;"
        var queryStatement: OpaquePointer?
        var notes: [Note] = []
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                let id = sqlite3_column_int(queryStatement, 0)
                let content = String(cString: sqlite3_column_text(queryStatement, 1))
                
                let folderNameVal = sqlite3_column_text(queryStatement, 2)
                let folderName = folderNameVal != nil ? String(cString: folderNameVal!) : "Chưa phân loại"
                
                let tagsVal = sqlite3_column_text(queryStatement, 3)
                let tags = tagsVal != nil ? String(cString: tagsVal!) : ""
                
                let createdAt = String(cString: sqlite3_column_text(queryStatement, 4))
                
                notes.append(Note(id: id, content: content, folderName: folderName, tags: tags, createdAt: createdAt))
            }
        }
        sqlite3_finalize(queryStatement)
        return notes
    }
    
    func deleteNote(id: Int32) {
        let deleteStatementString = "DELETE FROM notes WHERE id = ?;"
        var deleteStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteStatementString, -1, &deleteStatement, nil) == SQLITE_OK {
            sqlite3_bind_int(deleteStatement, 1, id)
            sqlite3_step(deleteStatement)
        }
        sqlite3_finalize(deleteStatement)
    }
    
    func searchNotes(keyword: String) -> [String] {
        // Tìm kiếm từ khóa cơ bản
        let query = "SELECT content FROM notes WHERE content LIKE '%\(keyword)%';"
        var queryStatement: OpaquePointer?
        var results: [String] = []
        
        if sqlite3_prepare_v2(db, query, -1, &queryStatement, nil) == SQLITE_OK {
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                let content = String(cString: sqlite3_column_text(queryStatement, 0))
                results.append(content)
            }
        }
        sqlite3_finalize(queryStatement)
        return results
    }

    // MARK: - Semantic Search (CoreML: vietnamese-sbert)
    
    // Uncomment the following imports manually if you want to inspect locally
    // For GitHub Actions, they will be injected automatically
    #if canImport(Transformers)
    import Transformers
    #endif
    #if canImport(CoreML)
    import CoreML
    #endif
    #if canImport(Accelerate)
    import Accelerate
    #endif

    /// Trả về tối đa `topK` ghi chú liên quan nhất với câu hỏi.
    /// Thuật toán: Dùng `vietnamese-sbert` CoreML model để tính Cosine Similarity.
    func searchRelevantNotes(query: String, topK: Int = 8) async -> [Note] {
        let allNotes = fetchAllNotes()
        guard !allNotes.isEmpty else { return [] }

        #if canImport(Transformers) && canImport(CoreML) && canImport(Accelerate)
        
        // 1. Initialize Tokenizer from local folder
        guard let tokenizerURL = Bundle.main.url(forResource: "VietnameseSBERT_Tokenizer", withExtension: nil),
              let tokenizer = try? await AutoTokenizer.from(modelFolder: tokenizerURL) else {
            print("Lỗi: Không thể load Tokenizer từ bundle")
            return fallbackSearch(query: query, notes: allNotes, topK: topK)
        }

        // 2. Initialize Model
        guard let model = try? VietnameseSBERT(configuration: MLModelConfiguration()) else {
            print("Lỗi: Không thể load model VietnameseSBERT")
            return fallbackSearch(query: query, notes: allNotes, topK: topK)
        }

        // Helper to get embeddings
        func getEmbedding(text: String) -> [Float]? {
            let inputIds = tokenizer.encode(text: text)
            
            guard let mlInputIds = try? MLMultiArray(shape: [1, 128], dataType: .int32),
                  let mlAttentionMask = try? MLMultiArray(shape: [1, 128], dataType: .int32) else {
                return nil
            }
            
            for i in 0..<128 {
                if i < inputIds.count {
                    mlInputIds[i] = NSNumber(value: inputIds[i])
                    mlAttentionMask[i] = 1
                } else {
                    mlInputIds[i] = 0 // padding token id is usually 0 or 1 for XLM-R, but attention_mask=0 ignores it
                    mlAttentionMask[i] = 0
                }
            }
            
            guard let prediction = try? model.prediction(input_ids: mlInputIds, attention_mask: mlAttentionMask) else {
                return nil
            }
            
            let multiArray = prediction.embeddings
            var vector = [Float](repeating: 0, count: multiArray.count)
            for i in 0..<multiArray.count {
                vector[i] = multiArray[i].floatValue
            }
            return vector
        }

        func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
            var dotProduct: Float = 0
            var magA: Float = 0
            var magB: Float = 0
            vDSP_dotpr(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))
            vDSP_svesq(a, 1, &magA, vDSP_Length(a.count))
            vDSP_svesq(b, 1, &magB, vDSP_Length(b.count))
            return dotProduct / (sqrt(magA) * sqrt(magB))
        }

        // 3. Convert query to vector
        guard let queryVector = getEmbedding(text: query) else {
            return fallbackSearch(query: query, notes: allNotes, topK: topK)
        }

        // 4. Score all notes
        var scored: [(note: Note, similarity: Float)] = allNotes.compactMap { note in
            let textToEmbed = "\(note.folderName) \(note.tags) \(note.content)"
            guard let noteVector = getEmbedding(text: textToEmbed) else { return nil }
            let sim = cosineSimilarity(queryVector, noteVector)
            return (note, sim)
        }

        // 5. Sort and return
        scored.sort { $0.similarity > $1.similarity }
        let topNotes = scored.prefix(topK).map { $0.note }
        return Array(topNotes)
        
        #else
        // Fallback if modules are missing (e.g. local IDE)
        return fallbackSearch(query: query, notes: allNotes, topK: topK)
        #endif
    }
    
    // MARK: - Fallback Lexical Search
    func fallbackSearch(query: String, notes allNotes: [Note], topK: Int) -> [Note] {
        let stopWords: Set<String> = [
            "là", "và", "của", "có", "không", "trong", "này", "cho", "với",
            "về", "đã", "được", "thì", "mà", "còn", "khi", "để", "từ",
            "tôi", "bạn", "cái", "những", "các", "một", "hai", "ba",
            "the", "is", "a", "an", "of", "in", "to", "for", "on"
        ]
        let queryTokens = tokenize(text: query)
            .filter { $0.count > 2 && !stopWords.contains($0) }
        
        guard !queryTokens.isEmpty else {
            return Array(allNotes.prefix(topK))
        }

        var scored: [(note: Note, score: Double)] = allNotes.map { note in
            let noteTokens = tokenize(text: note.content + " " + note.tags)
            let noteTokenSet = Set(noteTokens)
            let tagTokens = Set(tokenize(text: note.tags))
            let folderTokens = Set(tokenize(text: note.folderName))

            var score: Double = 0
            for qToken in queryTokens {
                let tf = noteTokens.filter { $0 == qToken }.count
                if tf > 0 {
                    let tfNorm = Double(tf) / Double(max(noteTokens.count, 1))
                    score += tfNorm * 10.0
                }
                if tagTokens.contains(qToken) { score += 2.0 }
                if folderTokens.contains(qToken) { score += 1.5 }
                if noteTokenSet.contains(qToken) && tf == 0 { score += 0.5 }
            }
            return (note: note, score: score)
        }

        scored.sort { $0.score > $1.score }
        let topNotes = scored.filter { $0.score > 0 }.prefix(topK).map { $0.note }

        if topNotes.isEmpty {
            return Array(allNotes.prefix(topK))
        }
        return Array(topNotes)
    }

    /// Tách văn bản thành mảng token chữ thường, loại bỏ dấu câu.
    private func tokenize(text: String) -> [String] {
        let lowercased = text.lowercased()
        let allowed = CharacterSet.letters.union(.decimalDigits)
        let cleaned = lowercased.unicodeScalars
            .map { allowed.contains($0) ? Character($0) : Character(" ") }
        let str = String(cleaned)
        return str.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
    }

    // MARK: - Document Storage Logic

    func insertDocument(name: String) -> Int64 {
        let insertString = "INSERT INTO documents (name) VALUES (?);"
        var statement: OpaquePointer?
        var lastId: Int64 = -1
        
        if sqlite3_prepare_v2(db, insertString, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (name as NSString).utf8String, -1, nil)
            if sqlite3_step(statement) == SQLITE_DONE {
                lastId = sqlite3_last_insert_rowid(db)
            }
        }
        sqlite3_finalize(statement)
        return lastId
    }

    func insertChunk(documentId: Int64, content: String, embedding: [Float]) {
        let insertString = "INSERT INTO document_chunks (document_id, content, embedding) VALUES (?, ?, ?);"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertString, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int64(statement, 1, documentId)
            sqlite3_bind_text(statement, 2, (content as NSString).utf8String, -1, nil)
            
            // Chuyển [Float] thành Data để lưu vào BLOB
            let data = embedding.withUnsafeBufferPointer { buffer in
                Data(buffer: buffer)
            }
            _ = data.withUnsafeBytes { bytes in
                sqlite3_bind_blob(statement, 3, bytes.baseAddress, Int32(data.count), nil)
            }
            
            if sqlite3_step(statement) != SQLITE_DONE {
                print("Lỗi: Không thể lưu chunk.")
            }
        }
        sqlite3_finalize(statement)
    }

    func getAllChunks() -> [DocumentChunk] {
        let query = "SELECT id, document_id, content, embedding FROM document_chunks;"
        var statement: OpaquePointer?
        var chunks: [DocumentChunk] = []
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = sqlite3_column_int(statement, 0)
                let docId = sqlite3_column_int(statement, 1)
                let content = String(cString: sqlite3_column_text(statement, 2))
                
                var embedding: [Float]? = nil
                if let blob = sqlite3_column_blob(statement, 3) {
                    let blobSize = sqlite3_column_bytes(statement, 3)
                    let floatCount = Int(blobSize) / MemoryLayout<Float>.size
                    let pointer = blob.bindMemory(to: Float.self, capacity: floatCount)
                    embedding = Array(UnsafeBufferPointer(start: pointer, count: floatCount))
                }
                
                chunks.append(DocumentChunk(id: id, documentId: docId, content: content, embedding: embedding))
            }
        }
        sqlite3_finalize(statement)
        return chunks
    }
}
