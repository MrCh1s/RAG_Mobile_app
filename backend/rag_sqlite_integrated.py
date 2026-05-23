import json
import math
from langchain_ollama import OllamaEmbeddings
from backend.sqlite_notes import NoteManager

# Hàm tính độ tương đồng bằng Cosine (Không dùng numpy cho nhẹ)
def cosine_similarity(v1, v2):
    dot_product = sum(a * b for a, b in zip(v1, v2))
    norm_v1 = math.sqrt(sum(a * a for a in v1))
    norm_v2 = math.sqrt(sum(b * b for b in v2))
    # Tránh chia cho 0
    if norm_v1 == 0 or norm_v2 == 0: return 0.0
    return dot_product / (norm_v1 * norm_v2)

print("Đang khởi tạo Hệ thống...")
# 1. Khởi tạo DB Ghi chú (dùng class trong sqlite_notes.py)
db = NoteManager()

# 2. Khởi tạo Ollama Embeddings để gọi Mô hình bge-m3
embeddings = OllamaEmbeddings(
    model="bge-m3",
    base_url="http://localhost:11434"
)

# === BƯỚC 2: TÌM KIẾM (RETRIEVAL) ===
print("\n--- 2. TÌM KIẾM GHI CHÚ THEO NGHĨA CỦA CÂU HỎI ---")
while True: 
    question = input("Nhap cau hoi: ")
    if question.strip() == "":
        continue
    if question.strip() == "/exit":
        break
    # a. "Số hóa" câu hỏi thành Vector
    q_vector = embeddings.embed_query(question)

    # b. Lấy toàn bộ notes dưới Database lên để đối chiếu (Tìm kiếm Cosine)
    all_notes = db.cursor.execute('SELECT id, folder_name, note_id, chunk_context, embedding, created_at FROM notes WHERE embedding IS NOT NULL').fetchall()

    results = []
    for note_row in all_notes:
        n_id, n_folder, n_note_id, n_chunk_context, n_vector_str, n_created_at = note_row
    
        n_vector = json.loads(n_vector_str)
    
        score = cosine_similarity(q_vector, n_vector)
        results.append({
            "id": n_id,
            "folder": n_folder,
            "note_id": n_note_id,
            "content": n_chunk_context,
            "created_at": n_created_at,
            "score": score
        })

    # Sắp xếp mảng để Ghi chú có điểm cao nhất (khớp nhất) nổi lên đầu
    results = sorted(results, key=lambda x: x["score"], reverse=True)

    # Đặt mốc Threshold lọc rác (Ví dụ: 0.75)
    answer = [r for r in results if r["score"] > 0.6]
    
    if len(answer) == 0:
        print("=> Đáp án không tìm thấy!'\n")
    else:
        print(f"Đã trích xuất thành công {len(answer)} bản ghi chú liên quan. Xử lý ngữ cảnh cho AI LLM...")
        # Lấy ra tối đa 3 ghi chú điểm cao nhất trên vạch an toàn để nhét vào Prompt
        for r in answer[:3]:
            print(f"- [{r['created_at']}] [Chuẩn: {r['score']*100:.2f}%] {r['content']}")
        print("")
