# Makefile - Nyxian

all: jailed

jailed: compile-jailed package
jailbroken: compile-jailbroken pseudo-sign package
jailbroken+run: compile-jailbroken pseudo-sign package install clean

update-config:
	chmod +x version.sh
	./version.sh

compile-jailed: update-config
	xcodebuild -project Nyxian.xcodeproj -scheme Nyxian -configuration Debug -destination 'generic/platform=iOS' -archivePath build/Nyxian.xcarchive archive CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

compile-jailbroken: update-config
	xcodebuild -project Nyxian.xcodeproj -scheme NyxianForJB -configuration Debug -destination 'generic/platform=iOS' -archivePath build/Nyxian.xcarchive archive CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

pseudo-sign:
	ldid -Sdebug.xml build/Nyxian.xcarchive/Products/Applications/NyxianForJB.app
	ldid -Stshelper.xml build/Nyxian.xcarchive/Products/Applications/NyxianForJB.app/tshelper

package:
	cp -r  build/Nyxian.xcarchive/Products/Applications Payload
	zip -r Nyxian.ipa ./Payload

install:
	ideviceinstaller install Nyxian.ipa

clean:
	rm Nyxian.ipa
	rm -rf Payload
	rm -rf build
