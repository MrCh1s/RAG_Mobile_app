import Foundation
import SQLite3

class LocalDatabase {
    static let shared = LocalDatabase()
    private var db: OpaquePointer?
    
    struct Note: Identifiable {
        let id: Int32
        let content: String
        let createdAt: String
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
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
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
    }
    
    func insertNote(content: String) {
        let insertStatementString = "INSERT INTO notes (content) VALUES (?);"
        var insertStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertStatementString, -1, &insertStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(insertStatement, 1, (content as NSString).utf8String, -1, nil)
            
            if sqlite3_step(insertStatement) == SQLITE_DONE {
                print("Đã thêm ghi chú thành công.")
            } else {
                print("Lỗi: Thêm ghi chú thất bại.")
            }
        }
        sqlite3_finalize(insertStatement)
    }
    
    func fetchAllNotes() -> [Note] {
        let queryStatementString = "SELECT id, content, created_at FROM notes ORDER BY created_at DESC;"
        var queryStatement: OpaquePointer?
        var notes: [Note] = []
        
        if sqlite3_prepare_v2(db, queryStatementString, -1, &queryStatement, nil) == SQLITE_OK {
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                let id = sqlite3_column_int(queryStatement, 0)
                let content = String(cString: sqlite3_column_text(queryStatement, 1))
                let createdAt = String(cString: sqlite3_column_text(queryStatement, 2))
                
                notes.append(Note(id: id, content: content, createdAt: createdAt))
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
}
