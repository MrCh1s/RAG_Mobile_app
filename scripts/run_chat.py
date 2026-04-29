import sys
import os
from mlc_llm import MLCEngine

print("============== QWEN 2.5 (1.5B) - MLC LLM ==============")

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))

engine = MLCEngine(
    model=os.path.join(BASE_DIR, "models", "mlc_models", "Qwen2.5-1.5B-Instruct-q4f16_1-MLC"),
    model_lib=os.path.join(BASE_DIR, "models", "mlc_models", "Qwen2.5-1.5B-Instruct-q4f16_1-MLC", "Qwen2.5-1.5B-Instruct-q4f16_1-MLC-cpu.dll"),
    mode="interactive",
    device="cpu", # Hệ thống sử dụng CPU
)

print("Mô hình đã sẵn sàng! (Gõ '/exit' để thoát màn hình chat)")
print("-" * 55)

history = []

while True:
    try:
        user_input = input("\nBạn: ")
        if user_input.strip() == "":
            continue
        if user_input.strip() == "/exit":
            break
            
        history.append({"role": "user", "content": user_input})
        
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
print("\nĐã thoát thành công!")
