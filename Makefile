.DEFAULT_GOAL := all

# Configuration
NXNAME := Nyxian
NXVERSION := $(shell awk -F= '/^VERSION/ {gsub(/[ \t]/,"",$$2); print $$2}' Config.xcconfig)
NXBUNDLE := com.cr4zy.nyxian

# Helper
comma := ,
define log_info
	echo "\033[32m\033[1m[*] \033[0m\033[32m$(1)\033[0m"
endef

define log_error
	echo "\033[31m\033[1m[!] \033[0m\033[31m$(1)\033[0m"; exit 1
endef

export PATH := /opt/homebrew/bin:/usr/local/bin:$(PATH)

define ensure_brew
	@if ! command -v brew >/dev/null 2>&1; then \
		printf '\033[33m\033[1m[?]\033[0m\033[33m homebrew not installed. Install now? [y/N] \033[0m'; \
		if [ -t 0 ]; then read ans; else ans=n; fi; \
		case "$$ans" in \
			[yY]|[yY][eE][sS]) \
				printf '\033[32m\033[1m[*]\033[0m\033[32m installing homebrew...\033[0m\n'; \
				/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || { \
					printf '\033[31m\033[1m[!]\033[0m\033[31m homebrew install failed\033[0m\n'; exit 1; }; \
				echo >> /Users/frida/.zprofile \
				echo 'eval "$(/opt/homebrew/bin/brew shellenv zsh)"' >> /Users/frida/.zprofile \
				eval "$(/opt/homebrew/bin/brew shellenv zsh)" \
				command -v brew >/dev/null 2>&1 || { \
					printf '\033[31m\033[1m[!]\033[0m\033[31m brew installed but not in PATH$(comma) open a new shell\033[0m\n'; exit 1; } ;; \
			*) \
				printf '\033[31m\033[1m[!]\033[0m\033[31m homebrew is required$(comma) see https://brew.sh\033[0m\n'; \
				exit 1 ;; \
		esac; \
	fi
endef

define ensure_brew_package
	@if ! brew list --versions $(1) >/dev/null 2>&1; then \
		printf '\033[33m\033[1m[?]\033[0m\033[33m %s not installed. Install via "brew install %s"? [y/N] \033[0m' '$(1)' '$(1)'; \
		if [ -t 0 ]; then read ans; else ans=n; fi; \
		case "$$ans" in \
			[yY]|[yY][eE][sS]) \
				printf '\033[32m\033[1m[*]\033[0m\033[32m installing %s...\033[0m\n' '$(1)'; \
				brew install $(1) || { printf '\033[31m\033[1m[!]\033[0m\033[31m failed to install %s\033[0m\n' '$(1)'; exit 1; } ;; \
			*) \
				printf '\033[31m\033[1m[!]\033[0m\033[31m %s is required\033[0m\n' '$(1)'; \
				exit 1 ;; \
		esac; \
	fi
endef

THEOS ?= $(HOME)/theos
export THEOS
export PATH := $(THEOS)/bin:$(PATH)

define ensure_macos
	@if [ "$$(uname -s)" != "Darwin" ]; then \
		printf '\033[31m\033[1m[!]\033[0m\033[31m this build requires macOS$(comma) detected: %s\033[0m\n' "$$(uname -s)"; \
		exit 1; \
	fi
endef

define ensure_theos
	@if [ ! -d "$(THEOS)" ] || [ ! -f "$(THEOS)/makefiles/common.mk" ]; then \
		printf '\033[33m\033[1m[?]\033[0m\033[33m theos not installed at %s. Run official installer? [y/N] \033[0m' '$(THEOS)'; \
		if [ -t 0 ]; then read ans; else ans=n; fi; \
		case "$$ans" in \
			[yY]|[yY][eE][sS]) \
				printf '\033[32m\033[1m[*]\033[0m\033[32m running theos installer...\033[0m\n'; \
				bash -c "$$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)" || { \
					printf '\033[31m\033[1m[!]\033[0m\033[31m theos installer failed\033[0m\n'; exit 1; }; \
				[ -f "$(THEOS)/makefiles/common.mk" ] || { \
					printf '\033[31m\033[1m[!]\033[0m\033[31m installer ran but %s/makefiles/common.mk missing\033[0m\n' '$(THEOS)'; exit 1; } ;; \
			*) \
				printf '\033[31m\033[1m[!]\033[0m\033[31m theos is required$(comma) see https://theos.dev\033[0m\n'; \
				exit 1 ;; \
		esac; \
	fi
endef

define ensure_xcode
	@if xcode-select -p >/dev/null 2>&1 && [ -d "$$(xcode-select -p)/Platforms/iPhoneOS.platform" ]; then \
		: ; \
	else \
		printf '\033[33m\033[1m[?]\033[0m\033[33m Xcode (full IDE$(comma) not CLT) required. Open App Store? [y/N] \033[0m'; \
		if [ -t 0 ]; then read ans; else ans=n; fi; \
		if [ "$$ans" = "y" ] || [ "$$ans" = "Y" ] || [ "$$ans" = "yes" ]; then \
			open 'macappstores://apps.apple.com/app/xcode/id497799835' 2>/dev/null || \
			open 'https://apps.apple.com/app/xcode/id497799835'; \
			printf '\033[33m\033[1m[i]\033[0m\033[33m after install: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer\033[0m\n'; \
		fi; \
		printf '\033[31m\033[1m[!]\033[0m\033[31m Xcode required$(comma) re-run make after install\033[0m\n'; \
		exit 1; \
	fi
endef

# Dependency Checks
check:
	$(call ensure_macos)
	$(call ensure_xcode)
	$(call ensure_brew)
	$(call ensure_brew_package,pkgconf)
	$(call ensure_brew_package,cmake)
	$(call ensure_brew_package,libarchive)
	$(call ensure_brew_package,dpkg)
	$(call ensure_brew_package,openssl)
	$(call ensure_theos)
	@$(call log_info,all dependencies are installed)

# Targets
all: jailed

jailed: SCHEME := Nyxian
jailed: FILE := Nyxian.ipa
jailed: clean check compile package-app clean

rootless: SCHEME := NyxianForJB
rootless: ARCH := iphoneos-arm64
rootless: JB_PATH := /var/jb/
rootless: clean check compile pseudo-sign package-deb clean

roothide: SCHEME := NyxianForJB
roothide: ARCH := iphoneos-arm64e
roothide: JB_PATH := /
roothide: clean check compile pseudo-sign package-deb clean

rootful: SCHEME := NyxianForJB
rootful: ARCH := iphoneos-arm
rootful: JB_PATH := /
rootful: clean check compile pseudo-sign package-deb clean

trollstore: SCHEME := NyxianForJB
trollstore: FILE := Nyxian.tipa
trollstore: clean check compile pseudo-sign package-app clean

# Dependencies
CoreCompiler/CoreCompilerSupportLibs:
	cd LLVM-On-iOS; $(MAKE)
	rm -rf CoreCompiler/CoreCompilerSupportLibs
	cp -r LLVM-On-iOS/CoreCompilerSupportLibs CoreCompiler/CoreCompilerSupportLibs
	cp -r LLVM-On-iOS/LLVM.xcframework CoreCompiler/CoreCompilerSupportLibs/LLVM.xcframework

# Needed for jailbroken version for permasigned apps
Nyxian/LindChain/JBSupport/tshelper:
	$(MAKE) -C TrollStore pre_build
	$(MAKE) -C TrollStore make_fastPathSign MAKECMDGOALS=
	$(MAKE) -C TrollStore make_roothelper MAKECMDGOALS=
	$(MAKE) -C TrollStore make_trollstore MAKECMDGOALS=
	$(MAKE) -C TrollStore make_trollhelper_embedded MAKECMDGOALS=
	cp TrollStore/RootHelper/.theos/obj/trollstorehelper Nyxian/LindChain/JBSupport/tshelper

# Helper
update-config:
	chmod +x version.sh
	./version.sh

# Methods
compile: Nyxian/LindChain/JBSupport/tshelper CoreCompiler/CoreCompilerSupportLibs
	chmod +x version.sh
	./version.sh
	xcodebuild \
		-project Nyxian.xcodeproj \
		-scheme $(SCHEME) \
		-configuration Release \
		-destination 'generic/platform=iOS' \
		-archivePath build/Nyxian.xcarchive \
		archive \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO

pseudo-sign:
	codesign --sign - --entitlements ent/nyxianforjb.xml --force --timestamp=none build/Nyxian.xcarchive/Products/Applications/NyxianForJB.app

package-app:
	cp -r  build/Nyxian.xcarchive/Products/Applications Payload
	-rm $(FILE)
	zip -r $(FILE) ./Payload

package-deb:
	mkdir -p .package$(JB_PATH)
	cp -r  build/Nyxian.xcarchive/Products/Applications .package$(JB_PATH)/Applications
	find . -type f -name ".DS_Store" -delete
	mkdir -p .package/DEBIAN
	echo "Package: $(NXBUNDLE)\nName: $(NXNAME)\nVersion: $(NXVERSION)\nArchitecture: $(ARCH)\nDescription: Full fledged Xcode-like IDE for iOS\nIcon: https://raw.githubusercontent.com/ProjectNyxian/Nyxian/main/preview.png\nMaintainer: cr4zyengineer\nAuthor: cr4zyengineer\nSection: Utilities\nTag: role::hacker" > .package/DEBIAN/control
	dpkg-deb -b --root-owner-group .package nyxian_$(NXVERSION)_$(ARCH).deb

clean:
	rm -rf Payload
	rm -rf build
	rm -rf .package
	rm -rf tmp
	-rm *.zip

clean-artifacts:
	-rm *.ipa
	-rm *.deb
	-rm *.tipa

clean-all: clean clean-artifacts
	rm -rf CoreCompiler/CoreCompilerSupportLibs
	-rm Nyxian/LindChain/JBSupport/tshelper
	cd LLVM-On-iOS; make clean; git reset --hard
	cd TrollStore; make clean; git reset --hard
