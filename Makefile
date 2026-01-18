# Makefile - Nyxian

all: compile package

compile:
	xcodebuild -project Nyxian.xcodeproj -scheme Nyxian -configuration Debug -destination 'generic/platform=iOS' -archivePath build/Nyxian.xcarchive archive

package:
	xcodebuild -exportArchive -archivePath build/Nyxian.xcarchive -exportPath build/ipa -exportOptionsPlist ExportOptions.plist

