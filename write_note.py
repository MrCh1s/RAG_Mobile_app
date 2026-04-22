import json 
from langchain_ollama import OllamaEmbeddings
from langchain_text_splitters import RecursiveCharacterTextSplitter


embeddings = OllamaEmbeddings(
    model = "bge-m3",
    base_url = "http://localhost:11434"
)

text_splitter = RecursiveCharacterTextSplitter(chunk_size=500, chunk_overlap=50)

def save_note_with_metadata(db_cursor, folder_name, note_id, context_user):
    chunks = text_splitter.split_text(context_user)
    for chunk in chunks:
        vector = embeddings.embed_query(chunk)
        db_cursor.execute('''
            INSERT INTO notes (folder_name, note_id, chunk_context, embedding) 
            VALUES (?, ?, ?, ?)
        ''', (folder_name, note_id, chunk, json.dumps(vector)))
    
    db_cursor.connection.commit()
    print(f"✅ Đã lưu {len(chunks)} phân đoạn chữ nhỏ vào Database (Thư mục: [{folder_name}] - Tệp: {note_id})!")

if __name__ == "__main__":
    from sqlite_notes import NoteManager
    
    # Khởi tạo DB
    db = NoteManager()
    
    # 10 ghi chú về việc nhà cửa để test
    notes_nha_cua = [
        "Lịch đổ rác: Thứ 2, Thứ 4, Thứ 6 hàng tuần lúc 18h00 tại sảnh tầng 1.",
        "Mật khẩu wifi điều hoà phòng khách là DHPK1234, wifi tivi là TV4567.",
        "Quy trình giặt đồ: Quần áo màu giặt riêng, ngâm nước xả 15 phút. Nước giặt để ở ngăn trái máy giặt.",
        "Tủ lạnh ngăn mát để rau củ, cất thịt cá sống ở ngăn đông. Hạn sử dụng sữa tươi là 7 ngày sau khi mở nắp.",
        "Lọc nước ở vòi bếp bằng hệ thống RO cần thay 6 tháng 1 lần. Mua lõi lọc mã số 1, 2, 3.",
        "Lau nhà bằng nước lau sàn Sunlight, pha 1 nắp nước lau sàn với nửa xô nước. Lau từ phòng ngủ ra phòng khách.",
        "Luyện thói quen: Nhớ tắt bình nóng lạnh sau khi tắm xong và rút phích cắm bàn ủi để tiết kiệm điện.",
        "Mật khẩu két sắt mini dưới gầm giường phòng ngủ master là 0928.",
        "Hộp dụng cụ sửa chữa nhà cửa: Cờ lê, mỏ lết, búa, tua vít để ở ngăn kéo dưới cùng tủ tivi.",
        "Mã số hộp mở khóa điện ngoài hành lang là 4455, chìa khoá nhà dự phòng gửi bác Nam hàng xóm."
    ]
    
    # Vòng lặp chạy qua 10 ghi chú và đem đi Nhúng vector + lưu Database
    for i, noi_dung in enumerate(notes_nha_cua):
        save_note_with_metadata(
            db_cursor=db.cursor, 
            folder_name="Nhà cửa", 
            note_id=f"Note_Home_{i+1}", 
            context_user=noi_dung
        )
    print("\n🎉 Đã nhập xong hoàn tất 10 ghi chú nhà cửa!")