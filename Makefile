# Makefile - Nyxian

all: compile sign package install clean

compile:
	xcodebuild -project Nyxian.xcodeproj -scheme NyxianForJB -configuration Debug -destination 'generic/platform=iOS' -archivePath build/Nyxian.xcarchive archive

sign:
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
