import os
import torch
from transformers import AutoModel, AutoTokenizer

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
    
    # Sử dụng AutoConfig để thiết lập torchscript=True (một số phiên bản transformers không hỗ trợ truyền trực tiếp vào AutoModel)
    from transformers import AutoConfig
    config = AutoConfig.from_pretrained(model_name)
    config.torchscript = True
    
    model = AutoModel.from_pretrained(model_name, config=config)
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
