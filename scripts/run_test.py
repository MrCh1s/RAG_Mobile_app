import sys
import os
import json
import math
from mlc_llm import MLCEngine
from langchain_ollama import OllamaEmbeddings

# Thêm đường dẫn gốc của dự án
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from backend.sqlite_notes import NoteManager  # noqa: E402

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))

# Hàm tính độ tương đồng bằng Cosine
def cosine_similarity(v1, v2):
    dot_product = sum(a * b for a, b in zip(v1, v2))
    norm_v1 = math.sqrt(sum(a * a for a in v1))
    norm_v2 = math.sqrt(sum(b * b for b in v2))
    if norm_v1 == 0 or norm_v2 == 0: return 0.0
    return dot_product / (norm_v1 * norm_v2)

db = NoteManager()

embeddings = OllamaEmbeddings(
    model="bge-m3",
    base_url="http://localhost:11434"
)

engine = MLCEngine(
    model=os.path.join(BASE_DIR, "models", "mlc_models", "Qwen2.5-1.5B-Instruct-q4f16_1-MLC"),
    model_lib=os.path.join(BASE_DIR, "models", "mlc_models", "Qwen2.5-1.5B-Instruct-q4f16_1-MLC", "Qwen2.5-1.5B-Instruct-q4f16_1-MLC-cpu.dll"),
    mode="interactive",
    device="cpu",
)

history = []

# Kỷ luật AI
system_rule = "Bạn là Trợ lý AI cá nhân. Bạn CHỈ ĐƯỢC phép dùng dữ kiện trong phần TÀI LIỆU SỔ TAY để trả lời. Trả lời cực kỳ ngắn gọn, thân thiện."
history.append({"role": "system", "content": system_rule})

print("\n🚀 HỆ THỐNG SẴN SÀNG! (Gõ '/exit' để thoát)")
print("-" * 60)

while True:
    try:
        user_input = input("\nNhap cau hoi: ")
        if user_input.strip() == "": continue
        if user_input.strip() == "/exit": break
            
        print("   🔍 [Hệ thống đang quét sổ tay bằng Vector...] ", end="")
        q_vector = embeddings.embed_query(user_input)
        
        all_notes = db.cursor.execute('SELECT id, chunk_context, embedding, created_at FROM notes WHERE embedding IS NOT NULL').fetchall()
        
        results = []
        for row in all_notes:
            n_id, n_chunk_context, n_vector_str, n_created_at = row
            n_vector = json.loads(n_vector_str)
            score = cosine_similarity(q_vector, n_vector)
            results.append({
                "content": n_chunk_context,
                "created_at": n_created_at,
                "score": score
            })
            
        results = sorted(results, key=lambda x: x["score"], reverse=True)
        
        # Mốc Threshold = 0.6
        answer = [r for r in results if r["score"] > 0.6]
        
        if len(answer) == 0:
            print("=> Hệ thống: Không tìm thấy dữ liệu liên quan trong Sổ tay. Yêu cầu truy vấn bị từ chối nhằm đảm bảo tính chính xác.")
            continue
            
        print(f"Đã trích xuất thành công {len(answer)} bản ghi chú liên quan. Xử lý ngữ cảnh cho AI LLM...")
        
        # Lấy top 3 tạo ngữ cảnh
        tai_lieu_gom_duoc = "\n".join([f"- {r['content']}" for r in answer[:3]])
        
        final_prompt = f"Đây là TÀI LIỆU SỔ TAY tìm được:\n{tai_lieu_gom_duoc}\n\nCâu hỏi lệnh của Sếp: {user_input}"
        history.append({"role": "user", "content": final_prompt})
        
        print("Qwen2.5: ", end="", flush=True)
        assistant_reply = ""
        
        for response in engine.chat.completions.create(
            messages=history,
            model="qwen",
            temperature=0.0, 
            stream=True,
        ):
            for choice in response.choices:
                text = choice.delta.content or ""
                print(text, end="", flush=True)
                assistant_reply += text
        print()
        
        history.append({"role": "assistant", "content": assistant_reply})
        
    except KeyboardInterrupt:
        break

engine.terminate()
