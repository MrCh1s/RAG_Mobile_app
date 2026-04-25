//
//  DownloadView.swift
//  MLCChat
//
//  Created by Yaxing Cai on 5/11/23.
//

import SwiftUI
import SQLite3

struct StartView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isAdding: Bool = false
    @State private var isRemoving: Bool = false
    @State private var inputModelUrl: String = ""

    var body: some View {
        NavigationStack {
            List{
                Section(header: Text("Models")) {
                    ForEach(appState.models) { modelState in
                        ModelView(isRemoving: $isRemoving)
                            .environmentObject(modelState)
                            .environmentObject(appState.chatState)
                    }
                    if !isRemoving {
                        Button("Edit model") {
                            isRemoving = true
                        }
                        .buttonStyle(.borderless)
                    } else {
                        Button("Cancel edit model") {
                            isRemoving = false
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .navigationTitle("MLC Chat")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: NoteEditView()) {
                        Image(systemName: "note.text.badge.plus")
                            .font(.title3)
                    }
                }
            }
            .alert("Error", isPresented: $appState.alertDisplayed) {
                Button("OK") { }
            } message: {
                Text(appState.alertMessage)
            }
        }
    }
}

struct NoteEditView: View {
    @State private var notes: [LocalDatabase.Note] = []
    @State private var newNoteText: String = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            VStack(alignment: .leading) {
                Text("Thêm ghi chú mới")
                    .font(.headline)
                
                TextEditor(text: $newNoteText)
                    .frame(height: 100)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                
                Button(action: saveNote) {
                    Text("Lưu Ghi Chú")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(newNoteText.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(newNoteText.isEmpty)
            }
            .padding()
            
            Divider()
            
            List {
                Section(header: Text("Danh sách ghi chú (\(notes.count))")) {
                    ForEach(notes) { note in
                        VStack(alignment: .leading) {
                            Text(note.content)
                                .font(.body)
                            Text(note.createdAt)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .onDelete(perform: deleteNotes)
                }
            }
        }
        .navigationTitle("Sổ tay AI")
        .onAppear(perform: loadNotes)
    }
    
    private func loadNotes() {
        notes = LocalDatabase.shared.fetchAllNotes()
    }
    
    private func saveNote() {
        LocalDatabase.shared.insertNote(content: newNoteText)
        newNoteText = ""
        loadNotes()
        // Ẩn bàn phím
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func deleteNotes(at offsets: IndexSet) {
        for index in offsets {
            let note = notes[index]
            LocalDatabase.shared.deleteNote(id: note.id)
        }
        loadNotes()
    }
}

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
