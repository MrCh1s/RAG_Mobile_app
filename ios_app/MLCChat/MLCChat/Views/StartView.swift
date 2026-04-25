//
//  DownloadView.swift
//  MLCChat
//
//  Created by Yaxing Cai on 5/11/23.
//

import SwiftUI

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
