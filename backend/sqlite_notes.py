import sqlite3
import json
import datetime
import os

DB_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'data', 'notes.db'))

class NoteManager:
    def __init__(self, db_path=DB_PATH):
        self.conn = sqlite3.connect(db_path)
        self.cursor = self.conn.cursor()
        self.create_table()

    def create_table(self):
        # Chú ý: Cấu trúc mới hỗ trợ Thư mục (Metadata)
        self.cursor.execute('''
            CREATE TABLE IF NOT EXISTS notes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                folder_name TEXT,
                tags TEXT,
                note_id TEXT,
                chunk_context TEXT NOT NULL,
                embedding TEXT, 
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        try:
            self.cursor.execute("ALTER TABLE notes ADD COLUMN tags TEXT")
        except sqlite3.OperationalError:
            pass
        self.conn.commit()

    def add_chunk(self, folder_name, note_id, chunk_context, vector=None, tags=None):
        vector_str = json.dumps(vector) if vector else None
        self.cursor.execute('''
            INSERT INTO notes (folder_name, note_id, chunk_context, embedding, tags) 
            VALUES (?, ?, ?, ?, ?)
        ''', (folder_name, note_id, chunk_context, vector_str, tags))
        self.conn.commit()
        return self.cursor.lastrowid

    def get_all_notes(self):
        self.cursor.execute('SELECT id, folder_name, note_id, chunk_context, tags FROM notes')
        return self.cursor.fetchall()
        
    def get_note(self, note_id):
        self.cursor.execute('SELECT * FROM notes WHERE id = ?', (note_id,))
        return self.cursor.fetchone()

    def update_note(self, note_id, new_content):
        self.cursor.execute('UPDATE notes SET content = ? WHERE id = ?', (new_content, note_id))
        self.conn.commit()

    def delete_note(self, note_id):
        # Lưu ý: Xóa dựa theo mã Tệp (note_id) để nó xóa sạch MỌI mảnh (chunks) của file note đó.
        self.cursor.execute('DELETE FROM notes WHERE note_id = ?', (note_id,))
        self.conn.commit()

    def delete_all_notes(self):
        # Xóa sạch sành sanh 100% mọi dữ liệu trong thùng chứa
        self.cursor.execute('DELETE FROM notes')
        self.conn.commit()
