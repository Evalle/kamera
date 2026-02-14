.PHONY: build run clean generate test

# Generate Xcode project using XcodeGen
generate:
	xcodegen generate

# Build the app via xcodebuild
build: generate
	xcodebuild -project Kamera.xcodeproj -scheme Kamera -configuration Debug build

# Build release
release: generate
	xcodebuild -project Kamera.xcodeproj -scheme Kamera -configuration Release build

# Run tests
test: generate
	xcodebuild -project Kamera.xcodeproj -scheme KameraTests -configuration Debug test

# Clean build artifacts
clean:
	xcodebuild -project Kamera.xcodeproj -scheme Kamera clean 2>/dev/null || true
	rm -rf .build DerivedData

# Resolve SPM dependencies
resolve:
	swift package resolve
