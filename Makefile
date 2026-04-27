# Configuration
NXNAME := Nyxian
NXVERSION := $(shell awk -F= '/^VERSION/ {gsub(/[ \t]/,"",$$2); print $$2}' Config.xcconfig)
NXBUNDLE := com.cr4zy.nyxian

# Targets
all: jailed

jailed: SCHEME := Nyxian
jailed: FILE := Nyxian.ipa
jailed: clean compile package-app clean

rootless: SCHEME := NyxianForJB
rootless: ARCH := iphoneos-arm64
rootless: JB_PATH := /var/jb/
rootless: clean compile pseudo-sign package-deb clean

roothide: SCHEME := NyxianForJB
roothide: ARCH := iphoneos-arm64e
roothide: JB_PATH := /
roothide: clean compile pseudo-sign package-deb clean

rootful: SCHEME := NyxianForJB
rootful: ARCH := iphoneos-arm
rootful: JB_PATH := /
rootful: clean compile pseudo-sign package-deb clean

trollstore: SCHEME := NyxianForJB
trollstore: FILE := Nyxian.tipa
trollstore: clean compile pseudo-sign package-app clean

# Dependencies
# Addressing: https://www.reddit.com/r/osdev/comments/1qknfa1/comment/o1b0gsm (Only workflows can and will use LazySetup)
Nyxian/LindChain/CoreCompiler.framework:
	cd LLVM-On-iOS; $(MAKE)
	rm -rf Nyxian/LindChain/CoreCompiler.framework
	cp -r LLVM-On-iOS/CoreCompiler.framework Nyxian/LindChain/CoreCompiler.framework

Nyxian/LindChain/CoreCompilerSupportLibs:
	cd LLVM-On-iOS; $(MAKE)
	rm -rf Nyxian/LindChain/CoreCompilerSupportLibs
	cp -r LLVM-On-iOS/CoreCompilerSupportLibs Nyxian/LindChain/CoreCompilerSupportLibs

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
compile: Nyxian/LindChain/JBSupport/tshelper Nyxian/LindChain/CoreCompiler.framework Nyxian/LindChain/CoreCompilerSupportLibs
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
	rm -rf Nyxian/LindChain/CoreCompiler.framework
	rm -rf Nyxian/LindChain/CoreCompilerSupportLibs
	-rm Nyxian/LindChain/JBSupport/tshelper
	cd LLVM-On-iOS; make clean; git reset --hard
	cd TrollStore; make clean; git reset --hard
