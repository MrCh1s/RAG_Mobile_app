#!/bin/bash

# iOS MLC Chat Build Helper Script
# This script automates the iOS build process for the Qwen2.5-1.5B-Instruct model

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_APP_DIR="${WORKSPACE_ROOT}/apps/ios_app"
MLC_CHAT_DIR="${IOS_APP_DIR}/MLCChat"
MODEL_NAME="Qwen2.5-1.5B-Instruct"
PLATFORM="${1:-iphoneos}"  # iphoneos or iphonesimulator
ARCH="${2:-arm64}"

echo -e "${GREEN}=== iOS MLC Chat Build Helper ===${NC}"
echo "Workspace: ${WORKSPACE_ROOT}"
echo "Platform: ${PLATFORM}"
echo "Architecture: ${ARCH}"

# Function to print step
print_step() {
    echo -e "\n${YELLOW}[Step] $1${NC}"
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Step 1: Check prerequisites
print_step "Checking prerequisites..."

if ! command -v rustup &> /dev/null; then
    print_error "Rust/rustup not installed"
    echo "Install from: https://www.rust-lang.org/tools/install"
    exit 1
fi
print_success "Rust installed"

if ! command -v cmake &> /dev/null; then
    print_error "CMake not installed"
    exit 1
fi
print_success "CMake installed"

if ! command -v mlc_llm &> /dev/null; then
    print_error "MLC-LLM not installed"
    echo "Install with: pip install mlc-llm"
    exit 1
fi
print_success "MLC-LLM installed"

# Step 2: Add iOS targets to Rust
print_step "Adding iOS Rust targets..."

if [ "$PLATFORM" = "iphonesimulator" ]; then
    if [ "$ARCH" = "arm64" ]; then
        rustup target add aarch64-apple-ios-sim
    else
        rustup target add x86_64-apple-ios
    fi
else
    rustup target add aarch64-apple-ios
fi
print_success "iOS Rust targets added"

# Step 3: Build MLC libraries
print_step "Building MLC-LLM iOS libraries..."

cd "${IOS_APP_DIR}"

if [ "$PLATFORM" = "iphonesimulator" ]; then
    bash prepare_libs.sh --simulator --arch "$ARCH"
else
    bash prepare_libs.sh --arch "$ARCH"
fi

if [ ! -d "${MLC_CHAT_DIR}/dist/lib" ]; then
    mkdir -p "${MLC_CHAT_DIR}/dist/lib"
fi

# Copy libraries to expected location
if [ -d "build/lib" ]; then
    cp build/lib/*.a "${MLC_CHAT_DIR}/dist/lib/" 2>/dev/null || true
fi

print_success "MLC-LLM libraries built"

# Step 4: Package models for iOS
print_step "Packaging models for iOS..."

cd "${WORKSPACE_ROOT}"
mlc_llm package \
    -o "${MLC_CHAT_DIR}" \
    --device iphone \
    2>&1 | grep -E "Generated|ERROR|model"

print_success "Models packaged"

# Step 5: Verify configuration
print_step "Verifying configuration files..."

if [ ! -f "${MLC_CHAT_DIR}/bundle/mlc-app-config.json" ]; then
    print_error "mlc-app-config.json not found"
    exit 1
fi
print_success "mlc-app-config.json found"

# Step 6: Build Xcode project
print_step "Building Xcode project for ${PLATFORM}..."

cd "${MLC_CHAT_DIR}"

SDK="iphoneos"
if [ "$PLATFORM" = "iphonesimulator" ]; then
    SDK="iphonesimulator"
fi

rm -rf build_output

xcodebuild build \
    -project MLCChat.xcodeproj \
    -scheme MLCChat \
    -sdk "${SDK}" \
    -configuration Release \
    -derivedDataPath build_output \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_ENTITLEMENTS="" \
    CODE_SIGNING_IDENTITY=""

print_success "Xcode build completed"

# Step 7: Create IPA
if [ "$PLATFORM" = "iphoneos" ]; then
    print_step "Creating IPA package..."
    
    APP_PATH=$(find build_output -name "*.app" | head -n 1)
    
    if [ -z "$APP_PATH" ]; then
        print_error "Could not find .app bundle"
        exit 1
    fi
    
    rm -rf Payload
    mkdir -p Payload
    cp -r "$APP_PATH" Payload/
    
    ZIP_NAME="MLCChat-${MODEL_NAME}.ipa"
    zip -r -q "${ZIP_NAME}" Payload
    
    IPA_SIZE=$(du -h "${ZIP_NAME}" | cut -f1)
    print_success "IPA created: ${ZIP_NAME} (${IPA_SIZE})"
    
    echo -e "\n${GREEN}=== Build Complete ===${NC}"
    echo "IPA Location: ${MLC_CHAT_DIR}/${ZIP_NAME}"
    echo "Next steps:"
    echo "1. For physical device: Use Xcode to deploy, or use AltStore for sideloading"
    echo "2. For app store: Sign with your certificate and upload to AppStoreConnect"
else
    print_success "Simulator build completed"
    echo -e "\n${GREEN}=== Build Complete ===${NC}"
    echo "To run in simulator:"
    echo "  open -a Simulator"
    echo "  xcodebuild -project ${MLC_CHAT_DIR}/MLCChat.xcodeproj"
fi

print_success "All steps completed successfully!"
