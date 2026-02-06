# Configuration
NXNAME := Nyxian
NXVERSION := 0.8.6
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

rootful: SCHEME := NyxianForJB
rootful: ARCH := iphoneos-arm
rootful: JB_PATH := /
rootful: compile pseudo-sign package-deb clean

# Dependencies
# Addressing: https://www.reddit.com/r/osdev/comments/1qknfa1/comment/o1b0gsm (Only workflows can and will use LazySetup)
Nyxian/LindChain/LLVM.xcframework:
	cd LLVM-On-iOS; $(MAKE)
	mv LLVM-On-iOS/LLVM.xcframework Nyxian/LindChain/LLVM.xcframework

Nyxian/LindChain/Clang.xcframework: Nyxian/LindChain/LLVM.xcframework
	mv LLVM-On-iOS/Clang.xcframework Nyxian/LindChain/Clang.xcframework

# Addressing: https://www.reddit.com/r/osdev/comments/1qknfa1/comment/o1b0gsm (Totally forgot to address libroot.a)
Nyxian/LindChain/JBSupport/libroot.a:
	cd libroot; $(MAKE)
	mv libroot/libroot_dyn_iphoneos-arm64.a Nyxian/LindChain/JBSupport/libroot.a
	mv libroot/src/libroot.h Nyxian/LindChain/JBSupport/libroot.h

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
compile: Nyxian/LindChain/JBSupport/tshelper Nyxian/LindChain/JBSupport/libroot.a Nyxian/LindChain/LLVM.xcframework Nyxian/LindChain/Clang.xcframework
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
	ldid -Sent/nyxianforjb.xml build/Nyxian.xcarchive/Products/Applications/NyxianForJB.app
	ldid -Sent/tshelper.xml build/Nyxian.xcarchive/Products/Applications/NyxianForJB.app/tshelper

package:
	cp -r  build/Nyxian.xcarchive/Products/Applications Payload
	zip -r Nyxian.ipa ./Payload

package-deb:
	mkdir -p .package$(JB_PATH)
	cp -r  build/Nyxian.xcarchive/Products/Applications .package$(JB_PATH)/Applications
	find . -type f -name ".DS_Store" -delete
	mkdir -p .package/DEBIAN
	echo "Package: $(NXBUNDLE)\nName: $(NXNAME)\nVersion: $(NXVERSION)\nArchitecture: $(ARCH)\nDescription: Full fledged Xcode-like IDE for iOS\nDepends: clang, lld | ld64\nIcon: https://raw.githubusercontent.com/ProjectNyxian/Nyxian/main/preview.png\nMaintainer: cr4zyengineer\nAuthor: cr4zyengineer\nSection: Utilities\nTag: role::hacker" > .package/DEBIAN/control
	dpkg-deb -b .package nyxian_$(NXVERSION)_$(ARCH).deb

clean:
	rm -rf Payload
	rm -rf build
	rm -rf .package
	rm -rf tmp
	-rm -rf *.zip

clean-artifacts:
	-rm *.ipa
	-rm *.deb

clean-all: clean clean-artifacts
	rm -rf Nyxian/LindChain/LLVM.xcframework
	rm -rf Nyxian/LindChain/Clang.xcframework
	-rm -rf Nyxian/LindChain/JBSupport/libroot*
	-rm Nyxian/LindChain/JBSupport/tshelper
	cd libroot; make clean; git reset --hard
	cd LLVM-On-iOS; make clean-all; git reset --hard
	cd TrollStore; make clean; git reset --hard
