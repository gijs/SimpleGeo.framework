default: release

# Create a Universal binary (iOS + Simulator)
release:
	xcodebuild -target SimpleGeo -configuration Release -sdk iphoneos4.2 build
	xcodebuild -target SimpleGeo -configuration Release -sdk iphonesimulator4.2 build
	-lipo -create build/Release-iphoneos/SimpleGeo.framework/SimpleGeo build/Release-iphonesimulator/SimpleGeo.framework/SimpleGeo -output build/Release-iphoneos/SimpleGeo.framework/SimpleGeo

dist: release
	cd build/Release-iphoneos/ && tar zcf ../../SimpleGeo-iOS.tgz SimpleGeo.framework/

clean:
	-rm -rf build
