import os
import torch
from transformers import AutoModel, AutoTokenizer, AutoConfig

# Monkeypatch để sửa lỗi "IndexError: tuple index out of range" trong transformers 4.57+ khi JIT Trace
# Lỗi này xảy ra do logic kiểm tra shape trong sdpa_mask không tương thích với bộ dò (tracer) của PyTorch
try:
    import transformers.masking_utils
    def patched_sdpa_mask(*args, **kwargs):
        # Lấy mask và dtype từ positional hoặc keyword arguments để đảm bảo không lỗi signature
        mask = kwargs.get("mask", args[0] if len(args) > 0 else None)
        dtype = kwargs.get("dtype", args[1] if len(args) > 1 else torch.float32)
        if mask is not None:
            if mask.dim() == 2:
                # Tự mở rộng mask từ (batch, seq_len) sang (batch, 1, 1, seq_len)
                mask = mask.unsqueeze(1).unsqueeze(2)
            return mask.to(dtype)
        return None
    transformers.masking_utils.sdpa_mask = patched_sdpa_mask
    print("✓ Đã áp dụng bản vá (patch) cho transformers.masking_utils")
except Exception as e:
    print(f"! Không thể áp dụng bản vá masking: {e}")

def export_to_coreml():
    try:
        import coremltools as ct
    except ImportError:
        print("Lỗi: Không tìm thấy thư viện coremltools. Hãy cài đặt bằng lệnh: pip install coremltools")
        return

    model_name = "keepitreal/vietnamese-sbert"
    output_dir = "Vietnamese_SBERT_CoreML.mlpackage"

    print(f"1. Đang tải Tokenizer và Model: {model_name}...")
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    
    # Sử dụng AutoConfig để thiết lập torchscript=True
    config = AutoConfig.from_pretrained(model_name)
    config.torchscript = True
    
    # Thêm attn_implementation="eager" để ép model dùng cơ chế attention cũ, tránh lỗi khi JIT trace SDPA
    model = AutoModel.from_pretrained(model_name, config=config, attn_implementation="eager")
    model.eval()

    # Tạo một Wrapper class để chỉ trả về tensor duy nhất (last_hidden_state hoặc pooler_output)
    # coremltools hoạt động tốt nhất khi model trả về raw tensor thay vì dictionary.
    class SBERTCoreMLWrapper(torch.nn.Module):
        def __init__(self, base_model):
            super().__init__()
            self.base_model = base_model
            
        def forward(self, input_ids, attention_mask):
            outputs = self.base_model(input_ids=input_ids, attention_mask=attention_mask)
            # Trả về last_hidden_state. Khi torchscript=True, output là tuple, phần tử 0 là last_hidden_state
            return outputs[0]

    wrapped_model = SBERTCoreMLWrapper(model)
    wrapped_model.eval()

    # 2. Tạo input giả (dummy input) để PyTorch dò đường (trace)
    print("2. Đang dò cấu trúc Model (Tracing)...")
    max_seq_length = 128
    dummy_text = "Đây là một câu tiếng Việt mẫu để kiểm tra."
    dummy_input = tokenizer(dummy_text, padding="max_length", max_length=max_seq_length, truncation=True, return_tensors="pt")
    
    traced_model = torch.jit.trace(wrapped_model, (dummy_input["input_ids"], dummy_input["attention_mask"]))

    # 3. Convert sang CoreML
    print("3. Đang chuyển đổi sang định dạng Apple CoreML (.mlpackage)...")
    mlmodel = ct.convert(
        traced_model,
        inputs=[
            ct.TensorType(name="input_ids", shape=(1, max_seq_length), dtype=ct.converters.mil.mil.types.int32),
            ct.TensorType(name="attention_mask", shape=(1, max_seq_length), dtype=ct.converters.mil.mil.types.int32)
        ],
        outputs=[
            ct.TensorType(name="last_hidden_state")
        ],
        compute_units=ct.ComputeUnit.ALL # Cho phép chạy trên NPU/GPU/CPU của iOS
    )

    # 4. Lưu file
    mlmodel.save(output_dir)
    print(f" Thành công! File CoreML đã được lưu tại: {os.path.abspath(output_dir)}")
    print(f" Vui lòng kéo thả thư mục {output_dir} vào dự án Xcode của bạn.")

if __name__ == "__main__":
    export_to_coreml()
