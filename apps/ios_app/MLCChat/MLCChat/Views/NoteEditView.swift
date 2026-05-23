import SwiftUI

struct NoteEditView: View {
    @EnvironmentObject private var chatState: ChatState
    @State private var notes: [LocalDatabase.Note] = []
    @State private var newNoteText: String = ""
    @State private var isProcessingAI = false
    @State private var aiStatusText = ""
    @State private var selectedFolderFilter = "Tất cả"
    @State private var isConfirmingDeleteAll = false
    @Environment(\.dismiss) var dismiss
    
    // Get unique list of folders from notes
    private var uniqueFolders: [String] {
        let folders = notes.map { $0.folderName }
        let unique = Set(folders)
        return ["Tất cả"] + unique.sorted()
    }
    
    // Filtered notes based on selection
    private var filteredNotes: [LocalDatabase.Note] {
        if selectedFolderFilter == "Tất cả" {
            return notes
        } else {
            return notes.filter { $0.folderName == selectedFolderFilter }
        }
    }
    
    var body: some View {
        ZStack {
            VStack {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Thêm ghi chú mới")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextEditor(text: $newNoteText)
                        .frame(height: 120)
                        .padding(4)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.15)))
                        .cornerRadius(10)
                    
                    HStack(spacing: 12) {
                        // Clean Up Button
                        Button(action: cleanupNoteText) {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Clean Up (AI)")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(newNoteText.isEmpty ? Color.gray.opacity(0.1) : Color.indigo.opacity(0.15))
                            .foregroundColor(newNoteText.isEmpty ? Color.gray : Color.indigo)
                            .cornerRadius(10)
                        }
                        .disabled(newNoteText.isEmpty)
                        
                        // Save Button
                        Button(action: saveNoteWithAI) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Lưu Ghi Chú")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(newNoteText.isEmpty ? Color.gray.opacity(0.2) : Color.blue)
                            .foregroundColor(newNoteText.isEmpty ? Color.gray : .white)
                            .cornerRadius(10)
                        }
                        .disabled(newNoteText.isEmpty)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 10)
                
                // Folder Filter Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(uniqueFolders, id: \.self) { folder in
                            Text(folder)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(selectedFolderFilter == folder ? Color.blue : Color.gray.opacity(0.15))
                                .foregroundColor(selectedFolderFilter == folder ? .white : .primary)
                                .cornerRadius(20)
                                .onTapGesture {
                                    withAnimation {
                                        selectedFolderFilter = folder
                                    }
                                }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                
                Divider()
                
                // List of Notes
                List {
                    Section(header: 
                        HStack {
                            Text("Danh sách ghi chú (\(filteredNotes.count))")
                                .font(.caption)
                                .fontWeight(.bold)
                            Spacer()
                            if !notes.isEmpty {
                                Button(action: {
                                    isConfirmingDeleteAll = true
                                }) {
                                    Text("Xóa tất cả")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    ) {
                        if filteredNotes.isEmpty {
                            HStack {
                                Spacer()
                                Text("Không có ghi chú nào ở thư mục này")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                                    .padding()
                                Spacer()
                            }
                        } else {
                            ForEach(filteredNotes) { note in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(note.content)
                                        .font(.body)
                                        .padding(.vertical, 2)
                                    
                                    HStack {
                                        // Folder badge
                                        Text(note.folderName)
                                            .font(.system(size: 10, weight: .bold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.blue.opacity(0.15))
                                            .foregroundColor(.blue)
                                            .cornerRadius(6)
                                        
                                        // Tags list
                                        if !note.tags.isEmpty {
                                            ForEach(note.tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }, id: \.self) { tag in
                                                if !tag.isEmpty {
                                                    Text("#\(tag)")
                                                        .font(.system(size: 10, weight: .medium))
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 3)
                                                        .background(Color.gray.opacity(0.12))
                                                        .foregroundColor(.secondary)
                                                        .cornerRadius(6)
                                                }
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Text(note.createdAt)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .onDelete(perform: deleteNotes)
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Sổ tay AI")
            .onAppear(perform: loadNotes)
            .alert("Xác nhận xóa", isPresented: $isConfirmingDeleteAll) {
                Button("Hủy", role: .cancel) { }
                Button("Xóa hết", role: .destructive) {
                    deleteAllNotes()
                }
            } message: {
                Text("Bạn có chắc chắn muốn xóa toàn bộ ghi chú không? Hành động này không thể hoàn tác.")
            }
            
            // AI processing loading overlay
            if isProcessingAI {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text(aiStatusText)
                        .foregroundColor(.white)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(30)
                .background(Color.black.opacity(0.75))
                .cornerRadius(16)
                .padding(40)
            }
        }
    }
    
    private func loadNotes() {
        notes = LocalDatabase.shared.fetchAllNotes()
    }
    
    private func cleanupNoteText() {
        let rawText = newNoteText
        isProcessingAI = true
        aiStatusText = "AI đang định dạng và chuẩn hóa..."
        
        Task {
            let cleaned = await chatState.cleanUpNoteText(rawText: rawText)
            DispatchQueue.main.async {
                self.newNoteText = cleaned
                self.isProcessingAI = false
            }
        }
    }
    
    private func saveNoteWithAI() {
        let rawText = newNoteText
        isProcessingAI = true
        aiStatusText = "AI đang phân loại và gắn nhãn..."
        
        Task {
            let (folder, tagsList) = await chatState.classifyAndTagNoteText(rawText: rawText)
            let tagsString = tagsList.joined(separator: ", ")
            
            DispatchQueue.main.async {
                LocalDatabase.shared.insertNote(content: rawText, folderName: folder, tags: tagsString)
                self.newNoteText = ""
                self.isProcessingAI = false
                self.loadNotes()
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }
    
    private func deleteNotes(at offsets: IndexSet) {
        for index in offsets {
            let note = filteredNotes[index]
            LocalDatabase.shared.deleteNote(id: note.id)
        }
        loadNotes()
    }
    
    private func deleteAllNotes() {
        for note in notes {
            LocalDatabase.shared.deleteNote(id: note.id)
        }
        loadNotes()
    }
}
