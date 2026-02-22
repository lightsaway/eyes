# Eyes — Break reminder for macOS
# Usage: make [target]

APP_NAME    := Eyes
VERSION     := 0.1.0
BUNDLE      := zig-out/$(APP_NAME).app
BUNDLE_BIN  := $(BUNDLE)/Contents/MacOS/eyes
DMG_NAME    := $(APP_NAME)-$(VERSION).dmg
DMG_PATH    := zig-out/$(DMG_NAME)
INSTALL_DIR := /Applications

# ─── Build ────────────────────────────────────────────────────────

.PHONY: build
build: ## Compile debug binary
	zig build

.PHONY: release
release: ## Compile optimized release binary
	zig build -Doptimize=ReleaseFast

.PHONY: small
small: ## Compile size-optimized binary
	zig build -Doptimize=ReleaseSmall

# ─── Test ─────────────────────────────────────────────────────────

.PHONY: test
test: ## Run unit tests
	zig build test

# ─── Run ──────────────────────────────────────────────────────────

.PHONY: run
run: build ## Build and run (debug)
	zig build run

.PHONY: run-release
run-release: release ## Build and run (release)
	./zig-out/bin/eyes

# ─── Icon ─────────────────────────────────────────────────────────

ICON_SRC    ?= generated-icons/eyes-friendly.jpg
ICONSET     := /tmp/AppIcon.iconset
ICON_OUT    := resources/AppIcon.icns

.PHONY: icon
icon: ## Convert $(ICON_SRC) to AppIcon.icns (set ICON_SRC=path to override)
	@rm -rf $(ICONSET)
	@mkdir -p $(ICONSET)
	@for size in 16 32 128 256 512; do \
		sips -s format png -z $$size $$size "$(ICON_SRC)" --out $(ICONSET)/icon_$${size}x$${size}.png >/dev/null 2>&1; \
		double=$$((size * 2)); \
		sips -s format png -z $$double $$double "$(ICON_SRC)" --out $(ICONSET)/icon_$${size}x$${size}@2x.png >/dev/null 2>&1; \
	done
	@iconutil -c icns $(ICONSET) -o $(ICON_OUT)
	@rm -rf $(ICONSET)
	@echo "Created $(ICON_OUT) from $(ICON_SRC)"

# ─── App Bundle ───────────────────────────────────────────────────

.PHONY: bundle
bundle: release icon ## Create Eyes.app bundle (release)
	@mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	@cp zig-out/bin/eyes $(BUNDLE_BIN)
	@cp resources/Info.plist $(BUNDLE)/Contents/Info.plist
	@test ! -f $(ICON_OUT) || cp $(ICON_OUT) $(BUNDLE)/Contents/Resources/AppIcon.icns
	@echo "Built $(BUNDLE)"

# ─── DMG Installer ───────────────────────────────────────────────

.PHONY: dmg
dmg: bundle ## Create DMG disk image
	@rm -f $(DMG_PATH)
	hdiutil create -volname "$(APP_NAME)" \
		-srcfolder $(BUNDLE) \
		-ov -format UDZO \
		$(DMG_PATH)
	@echo "Created $(DMG_PATH)"

# ─── Install / Uninstall ─────────────────────────────────────────

.PHONY: install
install: bundle ## Install Eyes.app to /Applications
	@rm -rf $(INSTALL_DIR)/$(APP_NAME).app
	@cp -R $(BUNDLE) $(INSTALL_DIR)/$(APP_NAME).app
	@echo "Installed to $(INSTALL_DIR)/$(APP_NAME).app"

.PHONY: uninstall
uninstall: ## Remove Eyes.app from /Applications
	@rm -rf $(INSTALL_DIR)/$(APP_NAME).app
	@echo "Removed $(INSTALL_DIR)/$(APP_NAME).app"

# ─── Clean ────────────────────────────────────────────────────────

.PHONY: clean
clean: ## Remove build artifacts
	@rm -rf zig-out .zig-cache

.PHONY: clean-resources
clean-resources: ## Remove generated resources (AppIcon.icns, etc.)
	@rm -f $(ICON_OUT)
	@echo "Cleaned resources — ready to regenerate"

# ─── Lint / Format ───────────────────────────────────────────────

.PHONY: fmt
fmt: ## Format all Zig source files
	zig fmt src/ build.zig

.PHONY: check
check: ## Check for compilation errors without emitting binary
	zig build -Doptimize=ReleaseFast --summary none 2>&1 || true
	@echo "Check complete"

# ─── Release Workflow ─────────────────────────────────────────────

.PHONY: dist
dist: clean test dmg ## Full release: clean, test, build release bundle + DMG
	@echo "Distribution ready: $(DMG_PATH)"

.PHONY: tag
tag: ## Create a git tag for the current version
	git tag -a v$(VERSION) -m "Release v$(VERSION)"
	@echo "Tagged v$(VERSION) — run 'git push origin v$(VERSION)' to publish"

# ─── Size Info ────────────────────────────────────────────────────

.PHONY: size
size: release ## Show binary size
	@ls -lh zig-out/bin/eyes | awk '{print $$5, $$9}'
	@echo "---"
	@size zig-out/bin/eyes 2>/dev/null || true

# ─── Help ─────────────────────────────────────────────────────────

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
