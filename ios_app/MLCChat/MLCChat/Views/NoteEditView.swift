import SwiftUI

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
