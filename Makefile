APP_NAME := Lightweight
PACKAGE_DIR := LightweightChat
EXECUTABLE := LightweightChat
BUNDLE := $(APP_NAME).app
BUNDLE_IDENTIFIER := org.peterc.lightweight
CONFIGURATION ?= release
# Swift 6.4's default swiftbuild engine stamps the deployment target as the SDK
# version, which makes macOS use legacy controls. The native engine preserves it.
SWIFT_BUILD_FLAGS ?= --build-system native
SIGNING_IDENTITY ?= Apple Development
DISTRIBUTION_SIGNING_IDENTITY ?= Developer ID Application
DIST_DIR := dist
DIST_BUNDLE := $(DIST_DIR)/$(BUNDLE)
DIST_ARCH_FLAGS := --arch arm64 --arch x86_64
INFO_PLIST := $(PACKAGE_DIR)/Resources/Info.plist
CURRENT_VERSION := $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" $(INFO_PLIST))
CURRENT_BUILD := $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleVersion" $(INFO_PLIST))
DMG := $(DIST_DIR)/$(APP_NAME)-$(CURRENT_VERSION).dmg
NOTARY_PROFILE ?= lightweight-notary
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

.PHONY: all build bundle sign verify register run version release-check dist dist-build dist-bundle dist-sign dist-verify dmg notarize release clean

all: register

build:
	swift build $(SWIFT_BUILD_FLAGS) -c $(CONFIGURATION) --package-path $(PACKAGE_DIR)

bundle: build
	mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	cp $(PACKAGE_DIR)/.build/$(CONFIGURATION)/$(EXECUTABLE) $(BUNDLE)/Contents/MacOS/$(EXECUTABLE)
	cp $(PACKAGE_DIR)/Resources/Info.plist $(BUNDLE)/Contents/Info.plist
	cp $(PACKAGE_DIR)/Resources/AppIcon.icns $(BUNDLE)/Contents/Resources/AppIcon.icns
	cp $(PACKAGE_DIR)/Resources/models.json $(BUNDLE)/Contents/Resources/models.json

sign: bundle
	codesign --force --sign "$(SIGNING_IDENTITY)" --identifier $(BUNDLE_IDENTIFIER) $(BUNDLE)

verify: sign
	codesign --verify --deep --strict --verbose=2 $(BUNDLE)

register: verify
	$(LSREGISTER) -f "$(CURDIR)/$(BUNDLE)"

run: register
	open $(BUNDLE)

# Usage: make version VERSION=1.1 BUILD=2
# The public version may stay the same for a rebuilt release, but the build must increase.
version:
	@current_version="$(CURRENT_VERSION)"; current_build="$(CURRENT_BUILD)"; \
	if ! printf '%s\n' "$(VERSION)" | grep -Eq '^[0-9]+(\.[0-9]+){1,2}$$'; then \
		echo "VERSION must look like 1.0 or 1.2.3" >&2; exit 1; \
	fi; \
	if ! printf '%s\n' "$(BUILD)" | grep -Eq '^[0-9]+$$'; then \
		echo "BUILD must be an integer" >&2; exit 1; \
	fi; \
	if ! awk -v new="$(VERSION)" -v old="$$current_version" 'BEGIN { split(new, n, "."); split(old, o, "."); for (i = 1; i <= 3; i++) { nv = n[i] + 0; ov = o[i] + 0; if (nv > ov) exit 0; if (nv < ov) exit 1 } exit 0 }'; then \
		echo "VERSION $(VERSION) must not be lower than $$current_version" >&2; exit 1; \
	fi; \
	if [ "$(BUILD)" -le "$$current_build" ]; then \
		echo "BUILD $(BUILD) must be greater than $$current_build" >&2; exit 1; \
	fi; \
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" $(INFO_PLIST); \
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(BUILD)" $(INFO_PLIST); \
	echo "Version updated: $$current_version ($$current_build) -> $(VERSION) ($(BUILD))"

release-check:
	@version="$(CURRENT_VERSION)"; build="$(CURRENT_BUILD)"; \
	if ! printf '%s\n' "$$version" | grep -Eq '^[0-9]+(\.[0-9]+){1,2}$$'; then \
		echo "Invalid CFBundleShortVersionString: $$version" >&2; exit 1; \
	fi; \
	if ! printf '%s\n' "$$build" | grep -Eq '^[0-9]+$$'; then \
		echo "Invalid CFBundleVersion: $$build (it must be an integer)" >&2; exit 1; \
	fi; \
	echo "Release version: $$version ($$build)"

# Distribution builds stay separate so local builds remain native and quick.
# dist-sign requires a Developer ID Application certificate.
dist: dist-verify

dist-build:
	swift build $(SWIFT_BUILD_FLAGS) -c release $(DIST_ARCH_FLAGS) --package-path $(PACKAGE_DIR)

dist-bundle: dist-build
	mkdir -p $(DIST_BUNDLE)/Contents/MacOS $(DIST_BUNDLE)/Contents/Resources
	bin_dir="$$(swift build $(SWIFT_BUILD_FLAGS) -c release $(DIST_ARCH_FLAGS) --package-path $(PACKAGE_DIR) --show-bin-path)"; \
	cp "$$bin_dir/$(EXECUTABLE)" $(DIST_BUNDLE)/Contents/MacOS/$(EXECUTABLE)
	cp $(PACKAGE_DIR)/Resources/Info.plist $(DIST_BUNDLE)/Contents/Info.plist
	cp $(PACKAGE_DIR)/Resources/AppIcon.icns $(DIST_BUNDLE)/Contents/Resources/AppIcon.icns
	cp $(PACKAGE_DIR)/Resources/models.json $(DIST_BUNDLE)/Contents/Resources/models.json

dist-sign: dist-bundle
	codesign --force --options runtime --timestamp --sign "$(DISTRIBUTION_SIGNING_IDENTITY)" --identifier $(BUNDLE_IDENTIFIER) $(DIST_BUNDLE)

dist-verify: dist-sign
	codesign --verify --deep --strict --verbose=2 $(DIST_BUNDLE)
	lipo $(DIST_BUNDLE)/Contents/MacOS/$(EXECUTABLE) -verify_arch arm64 x86_64

dmg: dist-verify
	dmg_stage="$$(mktemp -d /tmp/lightweight-dmg.XXXXXX)"; \
	trap 'rm -rf "$$dmg_stage"' EXIT; \
	ditto $(DIST_BUNDLE) "$$dmg_stage/$(BUNDLE)"; \
	ln -s /Applications "$$dmg_stage/Applications"; \
	hdiutil create -volname $(APP_NAME) -srcfolder "$$dmg_stage" -ov -format UDZO $(DMG)
	codesign --force --timestamp --sign "$(DISTRIBUTION_SIGNING_IDENTITY)" $(DMG)
	codesign --verify --verbose=2 $(DMG)

notarize: dmg
	xcrun notarytool submit $(DMG) --keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple $(DMG)
	xcrun stapler validate $(DMG)
	spctl --assess --type open --context context:primary-signature --verbose=4 $(DMG)

release: release-check
	$(MAKE) notarize
	shasum -a 256 $(DMG)
	ls -lh $(DMG)

clean:
	swift package --package-path $(PACKAGE_DIR) clean
