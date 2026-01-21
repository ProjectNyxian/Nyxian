# Configuration
NXNAME := Nyxian
NXVERSION := 0.8.2
NXBUNDLE := com.cr4zy.nyxian

# Targets
all: jailed

jailed: SCHEME := Nyxian
jailed: compile package clean

rootless: SCHEME := NyxianForJB
rootless: ARCH := iphoneos-arm64
rootless: JB_PATH := /var/jb/
rootless: compile pseudo-sign package-deb clean

roothide: SCHEME := NyxianForJB
roothide: ARCH := iphoneos-arm64e
roothide: JB_PATH := /
roothide: compile pseudo-sign package-deb clean

roothide: SCHEME := NyxianForJB
jbtest+run: compile pseudo-sign package install clean

# Helper
update-config:
	chmod +x version.sh
	./version.sh

# Methods
compile:
	chmod +x version.sh
	./version.sh
	xcodebuild \
		-project Nyxian.xcodeproj \
		-scheme $(SCHEME) \
		-configuration Debug \
		-destination 'generic/platform=iOS' \
		-archivePath build/Nyxian.xcarchive \
		archive \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO

pseudo-sign:
	ldid -Sdebug.xml build/Nyxian.xcarchive/Products/Applications/NyxianForJB.app
	ldid -Stshelper.xml build/Nyxian.xcarchive/Products/Applications/NyxianForJB.app/tshelper

package:
	cp -r  build/Nyxian.xcarchive/Products/Applications Payload
	zip -r Nyxian.ipa ./Payload

package-deb:
	mkdir -p .package$(JB_PATH)
	cp -r  build/Nyxian.xcarchive/Products/Applications .package$(JB_PATH)/Applications
	find . -type f -name ".DS_Store" -delete
	mkdir -p .package/DEBIAN
	echo "Package: $(NXBUNDLE)\nName: $(NXNAME)\nVersion: $(NXVERSION)\nArchitecture: $(ARCH)\nDescription: Full fledged Xcode-like IDE for iOS\nDepends: clang, lld\nIcon: https://raw.githubusercontent.com/fridakitten/FridaCodeManager/main/Blueprint/FridaCodeManager.app/AppIcon.png\nMaintainer: cr4zyengineer\nAuthor: cr4zyengineer\nSection: Utilities\nTag: role::hacker" > .package/DEBIAN/control
	dpkg-deb -b .package nyxian_$(NXVERSION)_$(ARCH).deb

install:
	ideviceinstaller install Nyxian.ipa

clean:
	-rm -rf Payload
	-rm -rf build
	-rm -rf .package

clean-artifacts:
	-rm *.ipa
	-rm *.deb
