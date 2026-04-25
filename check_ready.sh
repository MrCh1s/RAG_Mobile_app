#!/bin/bash
# Getting Started Script
# Run this to check if you're ready to build

echo "=========================================="
echo "iOS Qwen2.5-1.5B-Instruct Build Check"
echo "=========================================="
echo

# Check OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "✓ Running on macOS"
else
    echo "⚠ Not running on macOS"
    echo "  You need macOS to build this project"
    exit 1
fi

echo

# Check Xcode
echo "Checking Xcode..."
if command -v xcode-select &> /dev/null; then
    xcode_version=$(xcode-select --version)
    echo "✓ Xcode found: $xcode_version"
else
    echo "✗ Xcode not found"
    echo "  Install with: xcode-select --install"
    exit 1
fi

echo

# Check Python
echo "Checking Python..."
if command -v python3 &> /dev/null; then
    python_version=$(python3 --version)
    echo "✓ Python found: $python_version"
else
    echo "✗ Python not found"
    echo "  Install from: https://www.python.org/downloads/"
    exit 1
fi

echo

# Check Rust
echo "Checking Rust..."
if command -v rustup &> /dev/null; then
    rust_version=$(rustc --version)
    echo "✓ Rust found: $rust_version"
else
    echo "✗ Rust not found"
    echo "  Install with: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    exit 1
fi

echo

# Check MLC-LLM
echo "Checking MLC-LLM..."
if python3 -c "import mlc_llm" 2>/dev/null; then
    mlc_version=$(python3 -c "import mlc_llm; print(mlc_llm.__version__)" 2>/dev/null)
    echo "✓ MLC-LLM found: version $mlc_version"
else
    echo "✗ MLC-LLM not installed"
    echo "  Install with: pip install mlc-llm tvm"
    exit 1
fi

echo

# Check model files
echo "Checking model files..."
if [ -d "Qwen2.5-1.5B-Instruct" ]; then
    model_size=$(du -sh Qwen2.5-1.5B-Instruct | cut -f1)
    echo "✓ Model directory found: $model_size"
    
    # Check essential files
    required_files=("config.json" "tokenizer.json" "model.safetensors")
    all_found=true
    for file in "${required_files[@]}"; do
        if [ ! -f "Qwen2.5-1.5B-Instruct/$file" ]; then
            echo "  ✗ Missing: $file"
            all_found=false
        fi
    done
    
    if [ "$all_found" = true ]; then
        echo "  ✓ All required files present"
    fi
else
    echo "✗ Model directory not found"
    exit 1
fi

echo

# Check project files
echo "Checking project files..."
if [ -f "ios_app/MLCChat/MLCChat.xcodeproj/project.pbxproj" ]; then
    echo "✓ Xcode project found"
else
    echo "✗ Xcode project not found"
    exit 1
fi

if [ -f "build_ios.sh" ]; then
    echo "✓ Build script found"
else
    echo "✗ Build script not found"
    exit 1
fi

if [ -f ".github/workflows/ios_build.yml" ]; then
    echo "✓ CI/CD workflow found"
else
    echo "⚠ CI/CD workflow not found (not critical)"
fi

echo

# Check documentation
echo "Checking documentation..."
docs=("README.md" "QUICK_START.md" "iOS_BUILD_GUIDE.md" "MODEL_CONFIG.md")
missing_docs=0
for doc in "${docs[@]}"; do
    if [ -f "$doc" ]; then
        echo "✓ $doc"
    else
        echo "✗ $doc missing"
        missing_docs=$((missing_docs + 1))
    fi
done

echo

# Summary
echo "=========================================="
echo "✓ ALL CHECKS PASSED"
echo "=========================================="
echo

echo "You're ready to build! Next steps:"
echo "1. Run: bash build_ios.sh"
echo "2. Wait for build to complete (30-60 minutes)"
echo "3. Install on iPhone using Xcode or AltStore"
echo

echo "For detailed instructions, read:"
echo "- QUICK_START.md (5 minutes)"
echo "- iOS_BUILD_GUIDE.md (detailed)"
echo "- INDEX.md (documentation index)"
echo

echo "Build option A: bash build_ios.sh"
echo "Build option B: Open ios_app/MLCChat/MLCChat.xcodeproj in Xcode"
echo "Build option C: Push to GitHub for automated CI/CD build"
echo
