.PHONY: all build release clean package install user-install uninstall

PRODUCT_NAME = terminal-notify
HELPER_NAME = terminal-notify-helper
BUILD_DIR = .build
RELEASE_DIR = $(BUILD_DIR)/release
APP_BUNDLE = $(RELEASE_DIR)/$(HELPER_NAME).app
CLAUDE_ICON = Resources/claude-icon.png

all: build

build:
	swift build

release:
	swift build -c release

clean:
	swift package clean
	rm -rf $(RELEASE_DIR)/*.app

package: release
	@echo "Creating app bundle..."
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(RELEASE_DIR)/$(HELPER_NAME) $(APP_BUNDLE)/Contents/MacOS/
	cp Resources/Info.plist $(APP_BUNDLE)/Contents/
	cp $(CLAUDE_ICON) $(APP_BUNDLE)/Contents/Resources/
	@echo "Signing app bundle..."
	codesign --force --deep --sign - $(APP_BUNDLE)
	@echo "App bundle created at $(APP_BUNDLE)"

install: package
	@echo "Installing $(PRODUCT_NAME) (requires sudo)..."
	sudo mkdir -p /usr/local/bin
	sudo cp $(RELEASE_DIR)/$(PRODUCT_NAME) /usr/local/bin/
	sudo cp -R $(APP_BUNDLE) /Applications/
	@echo "Installed $(PRODUCT_NAME) to /usr/local/bin/"
	@echo "Installed $(HELPER_NAME).app to /Applications/"
	@echo ""
	@echo "To use terminal-notify, first start the helper app:"
	@echo "  open /Applications/$(HELPER_NAME).app"
	@echo ""
	@echo "Then send notifications:"
	@echo "  terminal-notify --message \"Hello, World!\""

user-install: package
	@echo "Installing $(PRODUCT_NAME) to user directories..."
	mkdir -p ~/bin
	mkdir -p ~/Applications
	cp $(RELEASE_DIR)/$(PRODUCT_NAME) ~/bin/
	cp -R $(APP_BUNDLE) ~/Applications/
	@echo "Installed $(PRODUCT_NAME) to ~/bin/"
	@echo "Installed $(HELPER_NAME).app to ~/Applications/"
	@echo ""
	@echo "Add ~/bin to your PATH if not already:"
	@echo "  export PATH=\"\$$HOME/bin:\$$PATH\""
	@echo ""
	@echo "To use terminal-notify, first start the helper app:"
	@echo "  open ~/Applications/$(HELPER_NAME).app"
	@echo ""
	@echo "Then send notifications:"
	@echo "  ~/bin/terminal-notify --message \"Hello, World!\""

uninstall:
	rm -f /usr/local/bin/$(PRODUCT_NAME)
	rm -rf /Applications/$(HELPER_NAME).app
	@echo "Uninstalled $(PRODUCT_NAME)"

codesign: package
	codesign --force --deep --sign - $(APP_BUNDLE)
	codesign --force --sign - $(RELEASE_DIR)/$(PRODUCT_NAME)

run-helper: package
	open $(APP_BUNDLE)

test: build
	swift test

help:
	@echo "terminal-notify build targets:"
	@echo "  make build        - Build debug version"
	@echo "  make release      - Build release version"
	@echo "  make package      - Create .app bundle (with signing)"
	@echo "  make install      - Install to /usr/local/bin and /Applications (requires sudo)"
	@echo "  make user-install - Install to ~/bin and ~/Applications (no sudo)"
	@echo "  make uninstall    - Remove installed files"
	@echo "  make clean        - Clean build artifacts"
	@echo "  make run-helper   - Start the helper app"
