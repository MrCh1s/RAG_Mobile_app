import sys
import json
import math
import time
from fastapi import FastAPI
from fastapi.responses import HTMLResponse, StreamingResponse
import uvicorn
from mlc_llm import MLCEngine
from langchain_ollama import OllamaEmbeddings
from sqlite_notes import NoteManager

app = FastAPI()

# Hàm tính độ tương đồng bằng Cosine
def cosine_similarity(v1, v2):
    dot_product = sum(a * b for a, b in zip(v1, v2))
    norm_v1 = math.sqrt(sum(a * a for a in v1))
    norm_v2 = math.sqrt(sum(b * b for b in v2))
    if norm_v1 == 0 or norm_v2 == 0: return 0.0
    return dot_product / (norm_v1 * norm_v2)

print("\n[Máy Chủ] Đang khởi động lõi AI ngầm trên PC...")
embeddings = OllamaEmbeddings(model="bge-m3", base_url="http://localhost:11434")

engine = MLCEngine(
    model="dist/Qwen2.5-1.5B-Instruct-q4f16_1-MLC/",
    model_lib="dist/Qwen2.5-1.5B-Instruct-q4f16_1-MLC/Qwen2.5-1.5B-Instruct-q4f16_1-MLC-cpu.dll",
    mode="interactive",
    device="cpu", # Máy đang kẹt CPU. Sau này nướng lại file DLL thì thay = "vulkan"
)

# Template Front-end giao diện giống iMessage dành riêng cho iPhone Safari
HTML_UI = """
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>Sổ Tay AI Offline</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 0; padding: 0; background-color: #f2f2f7; display: flex; flex-direction: column; height: 100vh; }
        .header { background: #fff; padding: 15px; text-align: center; border-bottom: 2px solid #eaeaea; font-weight: 700; font-size: 18px; color: #1c1c1e;}
        .chat-container { flex: 1; overflow-y: auto; padding: 20px; display: flex; flex-direction: column; gap: 12px; }
        .bubble { max-width: 80%; padding: 12px 18px; border-radius: 20px; font-size: 16px; line-height: 1.5; word-wrap: break-word;}
        .user-bubble { align-self: flex-end; background-color: #007aff; color: white; border-bottom-right-radius: 4px; box-shadow: 0 1px 2px rgba(0,0,0,0.1); }
        .bot-bubble { align-self: flex-start; background-color: #e5e5ea; color: black; border-bottom-left-radius: 4px; box-shadow: 0 1px 2px rgba(0,0,0,0.1); }
        .status-text { font-size: 12px; color: #8e8e93; margin-top: 4px; font-style: italic;}
        .input-area { background: #fff; padding: 15px; display: flex; gap: 10px; border-top: 1px solid #ddd; padding-bottom: max(15px, env(safe-area-inset-bottom));}
        input { flex: 1; padding: 12px 15px; border: 1px solid #c7c7cc; border-radius: 22px; font-size: 16px; outline: none; }
        button { background: #007aff; color: white; border: none; padding: 0 20px; border-radius: 22px; font-weight: 600; font-size:16px; cursor: pointer;}
        button:active { background: #005bb5; }
    </style>
</head>
<body>
    <div class="header">RAG Sổ Tay 1.5B (Máy Chủ)</div>
    
    <div class="chat-container" id="chat">
        <div class="bubble bot-bubble">Xin chào Sếp! Tôi là AI quản lý sổ tay. Sếp hỏi gì đi!</div>
    </div>
    
    <div class="input-area">
        <input type="text" id="msg" placeholder="Nhập câu hỏi tìm sổ tay..." onkeypress="if(event.key === 'Enter') send()">
        <button onclick="send()" id="sendBtn">Gửi</button>
    </div>

    <script>
        async function send() {
            const input = document.getElementById('msg');
            const btn = document.getElementById('sendBtn');
            const question = input.value.trim();
            if(!question) return;
            
            // Hiện tin nhắn của mình
            const chat = document.getElementById('chat');
            chat.innerHTML += `<div class="bubble user-bubble">${question}</div>`;
            input.value = '';
            btn.disabled = true;
            
            // Hiện hiệu ứng chờ (Bọt nước mờ)
            const botId = 'bot-' + Date.now();
            chat.innerHTML += `
            <div style="align-self: flex-start;">
                <div class="bubble bot-bubble" id="${botId}"> Đang vào DB tìm mảnh ghép...</div>
            </div>`;
            chat.scrollTop = chat.scrollHeight;

            try {
                // Gọi tới PC gánh tạ
                const response = await fetch('/chat_stream?q=' + encodeURIComponent(question));
                const reader = response.body.getReader();
                const decoder = new TextDecoder("utf-8");
                let botDiv = document.getElementById(botId);
                botDiv.innerText = ""; 

                // Nhận từng chữ nhỏ giọt
                while (true) {
                    const { done, value } = await reader.read();
                    if (done) break;
                    botDiv.innerText += decoder.decode(value, {stream: true});
                    chat.scrollTop = chat.scrollHeight;
                }
            } catch(e) {
                document.getElementById(botId).innerText = " Mất kết nối WiFi với Desktop PC!";
            }
            btn.disabled = false;
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
            {"role": "system", "content": "Bạn là Trợ lý AI cá nhân. Bạn CHỈ ĐƯỢC phép dùng dữ kiện trong phần TÀI LIỆU SỔ TAY để trả lời cực kỳ ngắn gọn."},
            {"role": "user", "content": final_prompt}
        ]
        
        print("[2/3] Bắt đầu gọi Qwen-1.5B (Đang mồi ngữ cảnh, chờ rặn chữ đầu tiên)...")
        start_llm = time.time()
        first_token_out = False
        token_count = 0
        
        # Bắn chữ từng giọt sang iPhone qua cổng sse stream
        for response in engine.chat.completions.create(
            messages=history,
            model="qwen",
            temperature=0.0, 
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

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
