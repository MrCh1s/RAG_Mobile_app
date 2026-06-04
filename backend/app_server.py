import sys
import io

# Ép hệ thống xuất chữ tiếng Việt (UTF-8) trên Terminal của Windows để không bị lỗi Unicode
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

import json
import math
import time
from fastapi import FastAPI
from fastapi.responses import HTMLResponse, StreamingResponse
import uvicorn
import openai
from langchain_ollama import OllamaEmbeddings
from sqlite_notes import NoteManager
import os
from pydantic import BaseModel
from typing import Optional, List
from langchain_text_splitters import RecursiveCharacterTextSplitter

app = FastAPI()

# Tính đường dẫn tuyệt đối thư mục gốc của dự án
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))


# Hàm tính độ tương đồng bằng Cosine
def cosine_similarity(v1, v2):
    dot_product = sum(a * b for a, b in zip(v1, v2))
    norm_v1 = math.sqrt(sum(a * a for a in v1))
    norm_v2 = math.sqrt(sum(b * b for b in v2))
    if norm_v1 == 0 or norm_v2 == 0: return 0.0
    return dot_product / (norm_v1 * norm_v2)

print("\n[Máy Chủ] Đang khởi động lõi AI ngầm trên PC...")
embeddings = OllamaEmbeddings(model="bge-m3", base_url="http://localhost:11434")

# Chuyển sang dùng Ollama làm engine tạm thời vì MLC-LLM đang lỗi thư viện trên Windows
engine = openai.OpenAI(
    base_url="http://localhost:11434/v1",
    api_key="ollama"
)

# Template Front-end giao diện giống iMessage dành riêng cho iPhone Safari
HTML_UI = """
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sổ Tay AI Offline</title>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg-color: #f8fafc;
            --panel-bg: #ffffff;
            --text-primary: #0f172a;
            --text-secondary: #475569;
            --accent-color: #4f46e5;
            --accent-hover: #4338ca;
            --border-color: #e2e8f0;
            --tag-bg: #e0e7ff;
            --tag-text: #3730a3;
            --success-color: #10b981;
            --error-color: #ef4444;
            --shadow: 0 10px 15px -3px rgba(0,0,0,0.05), 0 4px 6px -4px rgba(0,0,0,0.05);
        }
        * { box-sizing: border-box; font-family: 'Plus Jakarta Sans', sans-serif; }
        body { margin: 0; padding: 0; background-color: var(--bg-color); color: var(--text-primary); display: flex; flex-direction: column; height: 100vh; }
        .app-container { display: flex; flex: 1; overflow: hidden; height: calc(100vh - 60px); }
        .header { background: var(--panel-bg); padding: 15px 30px; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid var(--border-color); box-shadow: 0 1px 3px rgba(0,0,0,0.02); }
        .header h1 { margin: 0; font-size: 20px; font-weight: 700; color: var(--accent-color); }
        
        /* Layout split */
        .pane { flex: 1; display: flex; flex-direction: column; overflow: hidden; background: var(--panel-bg); margin: 15px; border-radius: 16px; border: 1px solid var(--border-color); box-shadow: var(--shadow); }
        .pane-header { padding: 15px 20px; border-bottom: 1px solid var(--border-color); font-weight: 600; display: flex; justify-content: space-between; align-items: center; font-size: 16px; }
        
        /* Chat Pane */
        .chat-container { flex: 1; overflow-y: auto; padding: 20px; display: flex; flex-direction: column; gap: 12px; background: #fafafa; }
        .bubble { max-width: 80%; padding: 12px 18px; border-radius: 16px; font-size: 15px; line-height: 1.5; word-wrap: break-word; animation: fadeIn 0.2s ease-out; }
        .user-bubble { align-self: flex-end; background-color: var(--accent-color); color: white; border-bottom-right-radius: 4px; }
        .bot-bubble { align-self: flex-start; background-color: #f1f5f9; color: var(--text-primary); border-bottom-left-radius: 4px; border: 1px solid var(--border-color); }
        .input-area { padding: 15px 20px; display: flex; gap: 10px; border-top: 1px solid var(--border-color); }
        .input-area input { flex: 1; padding: 12px 20px; border: 1px solid var(--border-color); border-radius: 30px; font-size: 15px; outline: none; transition: border 0.2s; }
        .input-area input:focus { border-color: var(--accent-color); }
        
        /* Button styles */
        .btn { background: var(--accent-color); color: white; border: none; padding: 10px 20px; border-radius: 20px; font-weight: 600; font-size: 14px; cursor: pointer; transition: all 0.2s; display: inline-flex; align-items: center; gap: 6px; }
        .btn:hover { background: var(--accent-hover); transform: translateY(-1px); }
        .btn-secondary { background: #f1f5f9; color: var(--text-primary); border: 1px solid var(--border-color); }
        .btn-secondary:hover { background: #e2e8f0; }
        .btn-danger { background: var(--error-color); }
        .btn-danger:hover { background: #dc2626; }
        .btn:disabled { opacity: 0.5; cursor: not-allowed; transform: none; }
        
        /* Notes Pane */
        .note-editor-section { padding: 20px; border-bottom: 1px solid var(--border-color); display: flex; flex-direction: column; gap: 12px; }
        .note-editor-section textarea { width: 100%; height: 100px; padding: 12px; border: 1px solid var(--border-color); border-radius: 12px; font-size: 14px; outline: none; resize: none; transition: border 0.2s; }
        .note-editor-section textarea:focus { border-color: var(--accent-color); }
        .editor-actions { display: flex; justify-content: flex-end; gap: 10px; }
        
        .notes-list-section { flex: 1; overflow-y: auto; padding: 20px; }
        .notes-group { margin-bottom: 20px; }
        .group-title { font-weight: 700; font-size: 14px; text-transform: uppercase; color: var(--text-secondary); margin-bottom: 10px; display: flex; align-items: center; gap: 8px; }
        .note-card { background: #f8fafc; border: 1px solid var(--border-color); border-radius: 12px; padding: 15px; margin-bottom: 10px; position: relative; transition: all 0.2s; }
        .note-card:hover { transform: translateY(-1px); box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05); }
        .note-content { font-size: 14px; line-height: 1.5; color: var(--text-primary); margin-bottom: 10px; white-space: pre-wrap; }
        .note-meta { display: flex; align-items: center; justify-content: space-between; font-size: 12px; color: var(--text-secondary); }
        .tags-container { display: flex; gap: 6px; flex-wrap: wrap; }
        .tag-badge { background: var(--tag-bg); color: var(--tag-text); padding: 2px 8px; border-radius: 12px; font-weight: 500; font-size: 11px; }
        .delete-btn { color: var(--error-color); cursor: pointer; border: none; background: none; font-size: 12px; font-weight: 600; }
        .delete-btn:hover { text-decoration: underline; }
        
        /* Spinner */
        .spinner { width: 16px; height: 16px; border: 2px solid rgba(255,255,255,0.3); border-top-color: white; border-radius: 50%; animation: spin 0.8s linear infinite; display: inline-block; }
        .spinner-dark { border-color: rgba(0,0,0,0.1); border-top-color: var(--accent-color); }
        
        @keyframes spin { to { transform: rotate(360deg); } }
        @keyframes fadeIn { from { opacity: 0; transform: translateY(5px); } to { opacity: 1; transform: translateY(0); } }
        
        /* Filter Bar */
        .filter-bar { display: flex; gap: 8px; overflow-x: auto; padding-bottom: 10px; margin-bottom: 15px; }
        .filter-chip { padding: 6px 14px; border-radius: 20px; border: 1px solid var(--border-color); font-size: 12px; font-weight: 600; cursor: pointer; background: var(--panel-bg); white-space: nowrap; transition: all 0.2s; }
        .filter-chip.active { background: var(--accent-color); color: white; border-color: var(--accent-color); }
        
        @media(max-width: 900px) {
            .app-container { flex-direction: column; overflow-y: auto; height: auto; }
            .pane { height: 500px; }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>Sổ Tay Trợ Lý AI Cá Nhân</h1>
        <div style="font-size: 13px; color: var(--text-secondary); font-weight: 500;">
            Offline Engine: <strong>Qwen2.5-1.5B</strong>
        </div>
    </div>
    
    <div class="app-container">
        <!-- Chat Pane -->
        <div class="pane">
            <div class="pane-header">
                <span>Tra Cứu Sổ Tay Bằng AI</span>
                <button class="btn btn-secondary" onclick="clearChat()">Xóa Lịch Sử</button>
            </div>
            
            <div class="chat-container" id="chat">
                <div class="bubble bot-bubble">Xin chào Sếp! Tôi là AI quản lý sổ tay. Mọi thông tin ghi chú sẽ được tôi học và trả lời chính xác dựa theo sổ tay của Sếp!</div>
            </div>
            
            <div class="input-area">
                <input type="text" id="msg" placeholder="Nhập câu hỏi tra cứu ghi chú..." onkeypress="if(event.key === 'Enter') sendQuery()">
                <button class="btn" onclick="sendQuery()" id="sendBtn">Tra Cứu</button>
            </div>
        </div>
        
        <!-- Notes Pane -->
        <div class="pane">
            <div class="pane-header">Quản Lý Ghi Chú</div>
            
            <!-- Editor -->
            <div class="note-editor-section">
                <textarea id="noteInput" placeholder="Nhập ghi chú thô vào đây (ví dụ: 'mua bia voi bim bim luc 6h chieu')..."></textarea>
                <div class="editor-actions">
                    <button class="btn btn-secondary" onclick="cleanupNote()" id="cleanupBtn">
                        <span id="cleanupSpinner" class="spinner spinner-dark" style="display:none;"></span>
                        Clean Up (AI)
                    </button>
                    <button class="btn" onclick="saveNote()" id="saveBtn">
                        <span id="saveSpinner" class="spinner" style="display:none;"></span>
                        Lưu Ghi Chú
                    </button>
                </div>
            </div>
            
            <!-- List -->
            <div class="notes-list-section">
                <!-- Filter bar -->
                <div class="filter-bar" id="folderFilters">
                    <div class="filter-chip active" onclick="filterFolder('all')" id="filter-all">Tất cả</div>
                </div>
                
                <div id="notesContainer">
                    <div style="text-align: center; color: var(--text-secondary); margin-top: 50px;">Đang tải ghi chú...</div>
                </div>
            </div>
        </div>
    </div>

    <script>
        let allNotes = [];
        let activeFolder = 'all';

        // Load notes on startup
        document.addEventListener('DOMContentLoaded', () => {
            fetchNotes();
        });

        async function fetchNotes() {
            try {
                const res = await fetch('/notes');
                allNotes = await res.json();
                renderNotes();
                renderFilters();
            } catch (e) {
                console.error('Error fetching notes:', e);
                document.getElementById('notesContainer').innerHTML = `<div style="text-align: center; color: var(--error-color);">Lỗi tải ghi chú từ máy chủ.</div>`;
            }
        }

        function renderFilters() {
            const folders = new Set(allNotes.map(n => n.folder_name).filter(Boolean));
            const filterBar = document.getElementById('folderFilters');
            filterBar.innerHTML = `<div class="filter-chip ${activeFolder === 'all' ? 'active' : ''}" onclick="filterFolder('all')" id="filter-all">Tất cả</div>`;
            
            folders.forEach(folder => {
                const activeClass = activeFolder === folder ? 'active' : '';
                filterBar.innerHTML += `<div class="filter-chip ${activeClass}" onclick="filterFolder('${folder}')">${folder}</div>`;
            });
        }

        function filterFolder(folder) {
            activeFolder = folder;
            const chips = document.querySelectorAll('.filter-chip');
            chips.forEach(c => c.classList.remove('active'));
            event.target.classList.add('active');
            renderNotes();
        }

        function renderNotes() {
            const container = document.getElementById('notesContainer');
            container.innerHTML = '';
            
            const filtered = activeFolder === 'all' 
                ? allNotes 
                : allNotes.filter(n => n.folder_name === activeFolder);
                
            if (filtered.length === 0) {
                container.innerHTML = `<div style="text-align: center; color: var(--text-secondary); margin-top: 50px;">Không có ghi chú nào.</div>`;
                return;
            }

            // Group by folder
            const groups = {};
            filtered.forEach(note => {
                const folder = note.folder_name || 'Chưa phân loại';
                if (!groups[folder]) groups[folder] = [];
                groups[folder].push(note);
            });

            for (const [folder, notes] of Object.entries(groups)) {
                let groupHtml = `
                    <div class="notes-group">
                        <div class="group-title">
                            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"></path></svg>
                            ${folder} (${notes.length})
                        </div>
                `;
                
                notes.forEach(note => {
                    const tagChips = (note.tags || '').split(',')
                        .map(t => t.trim())
                        .filter(t => t.length > 0)
                        .map(t => `<span class="tag-badge">${t}</span>`)
                        .join('');
                        
                    groupHtml += `
                        <div class="note-card">
                            <div class="note-content">${note.content}</div>
                            <div class="note-meta">
                                <div class="tags-container">${tagChips}</div>
                                <button class="delete-btn" onclick="deleteNote('${note.note_id}')">Xóa</button>
                            </div>
                        </div>
                    `;
                });
                
                groupHtml += `</div>`;
                container.innerHTML += groupHtml;
            }
        }

        async function cleanupNote() {
            const input = document.getElementById('noteInput');
            const text = input.value.trim();
            if (!text) return;
            
            const btn = document.getElementById('cleanupBtn');
            const spinner = document.getElementById('cleanupSpinner');
            
            btn.disabled = true;
            spinner.style.display = 'inline-block';
            
            try {
                const res = await fetch('/notes/cleanup', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ content: text })
                });
                const data = await res.json();
                input.value = data.cleaned_content;
            } catch(e) {
                alert('Lỗi khi dọn dẹp ghi chú bằng AI');
            } finally {
                btn.disabled = false;
                spinner.style.display = 'none';
            }
        }

        async function saveNote() {
            const input = document.getElementById('noteInput');
            const text = input.value.trim();
            if (!text) return;
            
            const btn = document.getElementById('saveBtn');
            const spinner = document.getElementById('saveSpinner');
            
            btn.disabled = true;
            spinner.style.display = 'inline-block';
            
            try {
                const res = await fetch('/notes/create', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ content: text, clean_up: false })
                });
                if (res.ok) {
                    input.value = '';
                    await fetchNotes();
                } else {
                    alert('Lỗi lưu ghi chú');
                }
            } catch(e) {
                alert('Mất kết nối máy chủ');
            } finally {
                btn.disabled = false;
                spinner.style.display = 'none';
            }
        }

        async function deleteNote(noteId) {
            if (!confirm('Bạn có chắc chắn muốn xóa ghi chú này?')) return;
            try {
                const res = await fetch(`/notes/${noteId}`, { method: 'DELETE' });
                if (res.ok) {
                    await fetchNotes();
                } else {
                    alert('Lỗi xóa ghi chú');
                }
            } catch(e) {
                alert('Mất kết nối máy chủ');
            }
        }

        async function sendQuery() {
            const input = document.getElementById('msg');
            const btn = document.getElementById('sendBtn');
            const question = input.value.trim();
            if(!question) return;
            
            const chat = document.getElementById('chat');
            chat.innerHTML += `<div class="bubble user-bubble">${question}</div>`;
            input.value = '';
            btn.disabled = true;
            
            const botId = 'bot-' + Date.now();
            chat.innerHTML += `
            <div style="align-self: flex-start;">
                <div class="bubble bot-bubble" id="${botId}">Đang truy vấn cơ sở dữ liệu và xử lý ngữ cảnh...</div>
            </div>`;
            chat.scrollTop = chat.scrollHeight;

            try {
                const response = await fetch('/chat_stream?q=' + encodeURIComponent(question));
                const reader = response.body.getReader();
                const decoder = new TextDecoder("utf-8");
                let botDiv = document.getElementById(botId);
                botDiv.innerText = ""; 

                while (true) {
                    const { done, value } = await reader.read();
                    if (done) break;
                    botDiv.innerText += decoder.decode(value, {stream: true});
                    chat.scrollTop = chat.scrollHeight;
                }
            } catch(e) {
                document.getElementById(botId).innerText = "Mất kết nối với AI Engine!";
            }
            btn.disabled = false;
        }

        function clearChat() {
            document.getElementById('chat').innerHTML = `<div class="bubble bot-bubble">Đã xóa cuộc hội thoại. Hãy đặt câu hỏi mới để bắt đầu tra cứu!</div>`;
        }
    </script>
</body>
</html>
"""

# Mở cổng 8000 phục vụ web
@app.get("/")
def home():
    return HTMLResponse(HTML_UI)

# Đầu não AI nhận lệnh từ Browser
@app.get("/chat_stream")
def chat_stream(q: str):
    
    def generate():
        # Khởi tạo db ngay trong luồng này để tránh lỗi SQLite Thread
        db_request = NoteManager()
        
        print(f"\n--- YÊU CẦU MỚI TỪ IPHONE: '{q}' ---")
        print("[1/3] Đang nhúng câu hỏi và quét Database Vector...")
        start_rag = time.time()
        
        # Bước 1 RAG
        q_vector = embeddings.embed_query(q)
        all_notes = db_request.cursor.execute('SELECT chunk_context, embedding FROM notes WHERE embedding IS NOT NULL').fetchall()
        
        results = []
        for row in all_notes:
            score = cosine_similarity(q_vector, json.loads(row[1]))
            results.append({"content": row[0], "score": score})
            
        results = sorted(results, key=lambda x: x["score"], reverse=True)
        answer = [r for r in results if r["score"] > 0.6]
        
        rag_time = time.time() - start_rag
        print(f"  => Xong! Tìm thấy {len(answer)} mảnh ghép trong {rag_time:.2f} giây.")
        
        if len(answer) == 0:
            yield "=> Hệ thống: Không tìm thấy mảnh dữ liệu trong Sổ tay. Từ chối trả lời."
            return
            
        # Lấy 3 mảnh ráp vào
        tai_lieu = "\n".join([f"- {r['content']}" for r in answer[:3]])
        final_prompt = f"TÀI LIỆU SỔ TAY:\n{tai_lieu}\n\nLệnh của sếp: {q}"
        
        history = [
            {"role": "system", "content": "Bạn là Trợ lý AI cá nhân chuyên tra cứu sổ tay. Nhiệm vụ của bạn là trả lời câu hỏi dựa TRỰC TIẾP và DUY NHẤT vào tài liệu được cung cấp. Trả lời cực kỳ ngắn gọn (1-2 câu), không lặp lại thông tin. Nếu không có thông tin, hãy từ chối trả lời."},
            {"role": "user", "content": final_prompt}
        ]
        
        print("[2/3] Bắt đầu gọi Qwen-1.5B (Đang mồi ngữ cảnh, chờ rặn chữ đầu tiên)...")
        start_llm = time.time()
        first_token_out = False
        token_count = 0
        
        # Bắn chữ từng giọt sang iPhone qua cổng sse stream
        for response in engine.chat.completions.create(
            messages=history,
            model="qwen2.5:latest",
            temperature=0.0, 
            max_tokens=128,
            stream=True,
        ):
            for choice in response.choices:
                if choice.delta.content:
                    if not first_token_out:
                        first_token_out = True
                        ttft = time.time() - start_llm
                        print(f"  => ⏱️ Mất {ttft:.2f} giây để hiểu đề bài và bắt đầu gửi chữ về iPhone!")
                    
                    token_count += 1
                    yield choice.delta.content

        total_llm_time = time.time() - start_llm
        tps = token_count / total_llm_time if total_llm_time > 0 else 0
        print(f"[3/3] Đã gửi nội dung lên iPhone! (Tốc độ đánh máy: {tps:.2f} chữ/giây)")

    return StreamingResponse(generate(), media_type="text/plain")

# --- AI HELPERS FOR CLEANUP & AUTO-CLASSIFICATION ---

def generate_ai_response(messages, max_tokens=256):
    reply = ""
    for response in engine.chat.completions.create(
        messages=messages,
        model="qwen2.5:latest",
        temperature=0.0,
        max_tokens=max_tokens,
        stream=True,
    ):
        for choice in response.choices:
            if choice.delta.content:
                reply += choice.delta.content
    return reply

def clean_up_note(content: str) -> str:
    system_prompt = (
        "Bạn là chuyên gia biên tập. Nhiệm vụ của bạn là chuẩn hóa và sửa lỗi chính tả ghi chú thô của người dùng. "
        "CHÚ Ý: Dựa vào ngữ cảnh tiếng Việt để sửa lỗi gõ vội/teencode (vd: 'onn' = 'ôn', 'hthành' = 'hoàn thành'). KHÔNG dịch các từ gõ sai sang tiếng Anh (vd: tuyệt đối không dịch 'onn' thành 'mở' hay 'on'). "
        "CHỈ in ra nội dung đã sửa dưới dạng 1 đoạn văn duy nhất. "
        "TUYỆT ĐỐI KHÔNG thêm bất kỳ câu giao tiếp nào (ví dụ: không nói 'Đây là...', 'Dưới đây là...'). "
        "KHÔNG sử dụng ký hiệu markdown block."
    )
    prompt = f"Ghi chú thô:\n{content}"
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": prompt}
    ]
    return generate_ai_response(messages, max_tokens=512).strip()

def classify_and_tag_note(content: str) -> dict:
    system_prompt = (
        "Bạn là AI chuyên phân loại ghi chú thông minh.\n"
        "Nhiệm vụ: Đọc ghi chú và phân loại vào MỘT trong các Thư mục (Học tập, Công việc, Gia đình, Tài chính, Ý tưởng, Sức khỏe, Khác). "
        "Sau đó tạo ra 1 đến 3 Thẻ (tags) ngắn gọn.\n\n"
        "BẮT BUỘC trả về ĐÚNG định dạng JSON, không giải thích, không dùng markdown.\n"
        "Ví dụ:\n"
        "Input: Mua thịt, cá và rau muống lúc đi làm về\n"
        "Output: {\"folder\": \"Gia đình\", \"tags\": [\"mua sắm\", \"thực phẩm\"]}"
    )
    prompt = f"Input: {content}\nOutput:"
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": prompt}
    ]
    raw_reply = generate_ai_response(messages, max_tokens=128).strip()
    
    try:
        clean_reply = raw_reply
        if "```" in clean_reply:
            if "```json" in clean_reply:
                clean_reply = clean_reply.split("```json")[1].split("```")[0].strip()
            else:
                clean_reply = clean_reply.split("```")[1].split("```")[0].strip()
        data = json.loads(clean_reply)
        folder = data.get("folder", "Khác")
        tags_list = data.get("tags", [])
        if not isinstance(tags_list, list):
            tags_list = [str(tags_list)]
        tags = ", ".join([t.strip() for t in tags_list if t])
        return {"folder": folder, "tags": tags}
    except Exception as e:
        print(f"Lỗi phân tích JSON từ AI: {e}. Raw: {raw_reply}")
        return {"folder": "Khác", "tags": "Ghi chú"}

# --- NOTE MANAGER API ENDPOINTS ---

class NoteCreateRequest(BaseModel):
    content: str
    clean_up: Optional[bool] = False

@app.post("/notes/create")
async def create_note(req: NoteCreateRequest):
    print(f"\n[API] Nhận yêu cầu tạo note. Nội dung thô: '{req.content[:50]}...'")
    content = req.content
    if req.clean_up:
        print("[API] Đang gọi AI clean_up...")
        content = clean_up_note(content)
        print(f"[API] Kết quả clean_up: '{content[:50]}...'")
        
    print("[API] Đang gọi AI phân loại & gán tags...")
    ai_meta = classify_and_tag_note(content)
    folder = ai_meta["folder"]
    tags = ai_meta["tags"]
    print(f"[API] Kết quả phân loại: Thư mục={folder}, Tags={tags}")
    
    note_id = f"Note_{int(time.time())}"
    
    text_splitter = RecursiveCharacterTextSplitter(chunk_size=500, chunk_overlap=50)
    chunks = text_splitter.split_text(content)
    
    db = NoteManager()
    for chunk in chunks:
        print(f"[API] Đang sinh embedding cho mảnh: '{chunk[:30]}...'")
        vector = embeddings.embed_query(chunk)
        db.add_chunk(
            folder_name=folder,
            note_id=note_id,
            chunk_context=chunk,
            vector=vector,
            tags=tags
        )
    print(f"[API] Đã lưu note thành công vào database! Chunks count: {len(chunks)}")
    return {
        "status": "success",
        "note_id": note_id,
        "folder": folder,
        "tags": tags,
        "cleaned_content": content,
        "chunks_count": len(chunks)
    }

class NoteCleanupRequest(BaseModel):
    content: str

@app.post("/notes/cleanup")
async def cleanup_note_api(req: NoteCleanupRequest):
    print(f"\n[API] Nhận yêu cầu dọn dẹp ghi chú: '{req.content[:50]}...'")
    cleaned = clean_up_note(req.content)
    print(f"[API] Đã dọn dẹp xong: '{cleaned[:50]}...'")
    return {"cleaned_content": cleaned}

@app.get("/notes")
async def list_notes_api():
    print("\n[API] Nhận yêu cầu lấy danh sách ghi chú...")
    db = NoteManager()
    rows = db.get_all_notes()
    notes_dict = {}
    for r in rows:
        nid = r[2]
        if nid not in notes_dict:
            notes_dict[nid] = {
                "note_id": nid,
                "folder_name": r[1],
                "tags": r[4] or "",
                "chunks": []
            }
        notes_dict[nid]["chunks"].append(r[3])
    
    notes_list = []
    for nid, data in notes_dict.items():
        notes_list.append({
            "note_id": nid,
            "folder_name": data["folder_name"],
            "tags": data["tags"],
            "content": "\n".join(data["chunks"])
        })
    print(f"[API] Trả về danh sách gồm {len(notes_list)} ghi chú.")
    return notes_list

@app.delete("/notes/{note_id}")
def delete_note_api(note_id: str):
    db = NoteManager()
    db.delete_note(note_id)
    return {"status": "success"}

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)
