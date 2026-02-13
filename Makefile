.PHONY: build run clean generate test

# Generate Xcode project using XcodeGen
generate:
	xcodegen generate

# Build the app via xcodebuild
build: generate
	xcodebuild -project KubeDash.xcodeproj -scheme KubeDash -configuration Debug build

# Build release
release: generate
	xcodebuild -project KubeDash.xcodeproj -scheme KubeDash -configuration Release build

# Run tests
test: generate
	xcodebuild -project KubeDash.xcodeproj -scheme KubeDashTests -configuration Debug test

# Clean build artifacts
clean:
	xcodebuild -project KubeDash.xcodeproj -scheme KubeDash clean 2>/dev/null || true
	rm -rf .build DerivedData

# Resolve SPM dependencies
resolve:
	swift package resolve
