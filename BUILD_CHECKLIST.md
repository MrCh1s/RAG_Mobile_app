# iOS App Build Checklist

## Pre-Build Phase ✓

### Environment Setup
- [ ] Running on macOS 12.0 or later
- [ ] Xcode 15.0+ installed (`xcode-select --install`)
- [ ] Rust installed (`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)
- [ ] Python 3.8+ installed
- [ ] At least 20GB free disk space
- [ ] iPhone or iPad with iOS 16.0+ (for testing)

### Dependencies Installation
- [ ] MLC-LLM installed: `pip install mlc-llm tvm`
- [ ] Verify: `mlc_llm --version` (should show 0.20+)
- [ ] CMake installed: `brew install cmake`
- [ ] Git installed: `git --version`

### Model Files Verification
- [ ] `Qwen2.5-1.5B-Instruct/config.json` exists (3.5 KB)
- [ ] `Qwen2.5-1.5B-Instruct/model.safetensors` exists (3.1 GB)
- [ ] `Qwen2.5-1.5B-Instruct/tokenizer.json` exists (2.1 MB)
- [ ] `Qwen2.5-1.5B-Instruct/tokenizer_config.json` exists (1.3 KB)
- [ ] `Qwen2.5-1.5B-Instruct/generation_config.json` exists (1.2 KB)
- [ ] Total size: ~3.1 GB

### Project Files Verification
- [ ] `ios_app/MLCChat/mlc-package-config.json` includes Qwen2.5-1.5B-Instruct
- [ ] `.github/workflows/ios_build.yml` is updated
- [ ] `build_ios.sh` is executable: `chmod +x build_ios.sh`
- [ ] `setup_windows.bat` exists (for Windows users)
- [ ] Documentation files present:
  - [ ] `iOS_BUILD_GUIDE.md`
  - [ ] `MODEL_CONFIG.md`
  - [ ] `SUMMARY.md`
  - [ ] `QUICK_START.md`

## Build Phase ✓

### Building on Mac

#### Using Script
- [ ] Run: `bash build_ios.sh`
- [ ] Wait for completion (30-45 minutes on first run)
- [ ] Check for errors in output
- [ ] Verify IPA created: `ls -lh ios_app/MLCChat/MLCChat-Qwen2.5-1.5B.ipa`

#### Manual Build (If Script Fails)
- [ ] Add iOS target: `rustup target add aarch64-apple-ios`
- [ ] Build libraries: `cd ios_app && bash prepare_libs.sh --arch arm64`
- [ ] Package models: `mlc_llm package -o MLCChat --device iphone`
- [ ] Build Xcode: `cd MLCChat && xcodebuild build -project MLCChat.xcodeproj -scheme MLCChat -sdk iphoneos -configuration Release`
- [ ] Create IPA: `mkdir Payload && cp -r build_output/*.app Payload/ && zip -r MLCChat-Qwen2.5-1.5B.ipa Payload`

### Build Verification
- [ ] IPA file size: ~3.2-3.5 GB
- [ ] IPA contains: Payload/MLCChat.app/
- [ ] App executable present: `unzip -l MLCChat-Qwen2.5-1.5B.ipa | grep MLCChat.app`
- [ ] No code signing errors in logs
- [ ] Build completed with: "Build complete!"

## Deployment Phase ✓

### Option 1: Xcode Deployment

#### Setup
- [ ] Connect iPhone via USB
- [ ] Trust this computer on iPhone
- [ ] Xcode recognizes device: `cd ios_app/MLCChat && open MLCChat.xcodeproj`
- [ ] Select device from device menu (not "Any iOS Device")

#### Deployment Steps
- [ ] Select MLCChat scheme
- [ ] Select iOS Device (your iPhone)
- [ ] Product → Run (or Press Play)
- [ ] Wait for app to build and install
- [ ] App appears on iPhone home screen

### Option 2: AltStore Deployment (No Apple Developer Account)

#### Setup
- [ ] Install AltStore on iPhone: https://altstore.io/
- [ ] Verify it's running on iPhone
- [ ] Download IPA: `ios_app/MLCChat/MLCChat-Qwen2.5-1.5B.ipa`

#### Deployment Steps
- [ ] Connect iPhone
- [ ] Open Files app
- [ ] Navigate to Downloads (where IPA is)
- [ ] Long press IPA → Open with AltStore
- [ ] Confirm installation
- [ ] AltStore installs app on iPhone
- [ ] App appears on home screen

### Option 3: GitHub Actions Automated Build

#### Setup
- [ ] Ensure all files are committed
- [ ] Push to `main` or `develop` branch
- [ ] GitHub Actions workflow triggers automatically

#### Deployment Steps
- [ ] Monitor GitHub Actions: https://github.com/YOUR_REPO/actions
- [ ] Wait for workflow to complete (30-60 minutes)
- [ ] Download artifact: "MLCChat-Qwen-Device"
- [ ] Extract IPA from ZIP
- [ ] Use AltStore or Xcode to install

### Option 4: TestFlight Distribution

#### Prerequisites
- [ ] Apple Developer Account ($99/year)
- [ ] App ID created in Apple Developer
- [ ] Valid signing certificate and provisioning profile

#### Deployment Steps
- [ ] Sign IPA with certificate: `codesign -s "CERTIFICATE_ID" MLCChat-Qwen2.5-1.5B.ipa`
- [ ] Upload to AppStoreConnect (Transporter)
- [ ] Send to TestFlight testers
- [ ] Testers install via TestFlight app

## Post-Deployment Testing ✓

### App Launch
- [ ] App launches without crashing
- [ ] No error dialogs on first launch
- [ ] Settings load correctly
- [ ] Device storage shows new app

### Model Loading
- [ ] App successfully loads model (check system settings)
- [ ] Model appears in model list
- [ ] "Qwen2.5-1.5B-Instruct" is selectable
- [ ] Model size shown correctly: ~3.1 GB

### Chat Functionality
- [ ] Can type in input field
- [ ] Send button enables when text entered
- [ ] First message generates response
- [ ] Response appears in chat history
- [ ] Multi-turn conversation works
- [ ] Can reset conversation

### Performance Testing
- [ ] First token appears within 2-4 seconds
- [ ] Tokens generate at reasonable speed (15+ tokens/sec)
- [ ] No app freezing during generation
- [ ] Memory usage stays below 3.5 GB (check Settings > General > iPhone Storage)
- [ ] Battery drain acceptable (~5-10% per hour)

### Stress Testing
- [ ] Send long conversation (20+ messages)
- [ ] Switch apps and return (background handling)
- [ ] Tap multiple buttons quickly (no crashes)
- [ ] Rotate device (orientation handling)
- [ ] Low battery mode works
- [ ] App responds to system notifications

## Device Testing Matrix ✓

Test on these devices if available:

### Minimum (iPhone 13)
- [ ] App installs
- [ ] Model loads
- [ ] Chat functional
- [ ] Speed acceptable (10-15 tokens/sec)

### Recommended (iPhone 14/15)
- [ ] Excellent performance
- [ ] Smooth scrolling
- [ ] Good response time (15-25 tokens/sec)

### Optimal (iPhone 15 Pro / iPad Pro)
- [ ] Peak performance
- [ ] Fastest generation
- [ ] Can use max context window

## Bug Reporting ✓

If issues found, document:

- [ ] iOS version: Settings > General > About > Software Version
- [ ] Device model: Settings > General > About > Model
- [ ] App version: In-app settings
- [ ] Error message: (copy from console)
- [ ] Steps to reproduce: (detailed steps)
- [ ] Screenshots: (if applicable)
- [ ] Console logs: (from Xcode if possible)

## Final Checklist ✓

- [ ] All build steps completed successfully
- [ ] IPA file created and verified
- [ ] App installed on device
- [ ] Chat functionality working
- [ ] Model responds correctly
- [ ] Performance acceptable
- [ ] No critical bugs found
- [ ] Documentation reviewed
- [ ] All tests passed

## Success Criteria ✓

✅ **Build Successful When:**
- App launches on iPhone
- Model loads without errors
- Can send messages and receive responses
- Generation speed > 10 tokens/second
- No crashes during normal use
- Memory stays below 3.5 GB

✅ **Ready for Distribution When:**
- All tests pass on multiple devices
- No critical bugs identified
- Performance meets expectations
- User documentation complete
- Code is optimized

---

## Troubleshooting Quick Reference

| Issue | Quick Fix |
|-------|-----------|
| Build fails | Run: `rm -rf build_output` and retry |
| App won't launch | Clear Xcode cache: `rm -rf ~/Library/Developer/Xcode/DerivedData` |
| Model not loading | Check: `ls ios_app/MLCChat/bundle/mlc-app-config.json` |
| Slow generation | Reduce `prefill_chunk_size` to 32 |
| Out of memory | Reduce `context_window_size` to 512 |
| Device not recognized | Unplug/replug USB and restart Xcode |
| AltStore installation fails | Ensure iOS 14.0+, restart AltStore |

---

**Last Updated:** April 25, 2026  
**Status:** Ready for Production  

All requirements met! You can now build and deploy the iOS Qwen2.5-1.5B-Instruct ChatBox app. 🎉
