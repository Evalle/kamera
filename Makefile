.PHONY: build run clean generate test dmg

GIT_VERSION := $(shell git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.1.0")

# Generate Xcode project using XcodeGen
generate:
	xcodegen generate

# Build the app via xcodebuild
build: generate
	xcodebuild -project Kamera.xcodeproj -scheme Kamera -configuration Debug MARKETING_VERSION=$(GIT_VERSION) build

# Build release
release: generate
	xcodebuild -project Kamera.xcodeproj -scheme Kamera -configuration Release MARKETING_VERSION=$(GIT_VERSION) build

# Run tests
test: generate
	xcodebuild -project Kamera.xcodeproj -scheme KameraTests -configuration Debug test

# Clean build artifacts
clean:
	xcodebuild -project Kamera.xcodeproj -scheme Kamera clean 2>/dev/null || true
	rm -rf .build DerivedData

APP_NAME := Kamera
BUILD_DIR := build
DMG_NAME := $(APP_NAME).dmg

# Build release .app into local build/ directory and package as .dmg
dmg: generate
	@echo "Building release..."
	xcodebuild -project $(APP_NAME).xcodeproj -scheme $(APP_NAME) \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR)/DerivedData \
		MARKETING_VERSION=$(GIT_VERSION) \
		build
	@echo "Creating DMG..."
	@rm -f $(BUILD_DIR)/$(DMG_NAME)
	@mkdir -p $(BUILD_DIR)/dmg-staging
	@cp -R $(BUILD_DIR)/DerivedData/Build/Products/Release/$(APP_NAME).app $(BUILD_DIR)/dmg-staging/
	@ln -sf /Applications $(BUILD_DIR)/dmg-staging/Applications
	hdiutil create -volname $(APP_NAME) \
		-srcfolder $(BUILD_DIR)/dmg-staging \
		-ov -format UDZO \
		$(BUILD_DIR)/$(DMG_NAME)
	@rm -rf $(BUILD_DIR)/dmg-staging $(BUILD_DIR)/DerivedData
	@echo "Done: $(BUILD_DIR)/$(DMG_NAME)"

# Resolve SPM dependencies
resolve:
	swift package resolve
