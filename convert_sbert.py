import torch
from transformers import AutoModel, AutoTokenizer
import coremltools as ct
from coremltools.converters.mil.mil import Builder as mb
from coremltools.converters.mil.frontend.torch.torch_op_registry import register_torch_op
from coremltools.converters.mil.frontend.torch.ops import _get_inputs

@register_torch_op(override=True)
def new_ones(context, node):
    inputs = _get_inputs(context, node)
    shape = inputs[1]
    if shape.dtype != "int32":
        shape = mb.cast(x=shape, dtype="int32")
    res = mb.fill(shape=shape, value=1.0, name=node.name)
    context.add(res)

model_id = "keepitreal/vietnamese-sbert"

print("Loading model...")
tokenizer = AutoTokenizer.from_pretrained(model_id)
model = AutoModel.from_pretrained(model_id)
model.eval()

class Wrapper(torch.nn.Module):
    def __init__(self, model):
        super().__init__()
        self.model = model
    def forward(self, input_ids, attention_mask):
        # Return pooler output for sentence embeddings
        return self.model(input_ids, attention_mask).pooler_output

wrapper = Wrapper(model)
wrapper.eval()

# Trace the model
print("Tracing model...")
dummy_input = tokenizer("Xin chào Việt Nam", return_tensors="pt")
traced_model = torch.jit.trace(wrapper, (dummy_input['input_ids'], dummy_input['attention_mask']))

# Convert to CoreML
print("Converting to CoreML...")
mlmodel = ct.convert(
    traced_model,
    inputs=[
        ct.TensorType(name="input_ids", shape=(1, ct.RangeDim(1, 128))),
        ct.TensorType(name="attention_mask", shape=(1, ct.RangeDim(1, 128)))
    ],
    outputs=[
        ct.TensorType(name="embeddings")
    ],
    compute_units=ct.ComputeUnit.ALL
)

output_path = "apps/ios_app/MLCChat/MLCChat/VietnameseSBERT.mlpackage"
mlmodel.save(output_path)
print(f"Saved to {output_path}")

# Download and save tokenizer files
import os
import shutil
from huggingface_hub import snapshot_download

print("Downloading tokenizer files...")
tokenizer_path = "apps/ios_app/MLCChat/MLCChat/VietnameseSBERT_Tokenizer"
os.makedirs(tokenizer_path, exist_ok=True)
snapshot_dir = snapshot_download(repo_id=model_id, allow_patterns=["*.json", "*.txt", "*.model"])
for f in os.listdir(snapshot_dir):
    shutil.copy(os.path.join(snapshot_dir, f), tokenizer_path)
print("Tokenizer files saved.")
