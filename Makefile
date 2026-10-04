CC = clang
CFLAGS = -O3 -fobjc-arc
FRAMEWORKS = -framework Cocoa \
             -framework AVFoundation \
             -framework AudioToolbox \
             -framework CoreAudio \
             -framework CoreGraphics \
             -framework CoreMedia \
             -framework ScreenCaptureKit \
             -F /System/Library/PrivateFrameworks -framework CoreBrightness

SOURCES = src/main.m \
          src/KeyboardController.m \
          src/AudioAnalyzer.m \
          src/AudioCaptureEngine.m \
          src/TypingSpeedometerEngine.m \
          src/AppController.m

TARGET = build/keyboard-light
APP = "build/Keyboard Light.app"

all: $(TARGET) app

$(TARGET): $(SOURCES)
	@mkdir -p build
	$(CC) $(CFLAGS) $(FRAMEWORKS) $(SOURCES) -o $(TARGET)

app: $(TARGET)
	@mkdir -p $(APP)/Contents/MacOS
	@mkdir -p $(APP)/Contents/Resources
	@cp $(TARGET) $(APP)/Contents/MacOS/keyboard-light
	@cp Info.plist $(APP)/Contents/Info.plist
	@if [ -f "assets/AppIcon.icns" ]; then cp assets/AppIcon.icns $(APP)/Contents/Resources/AppIcon.icns; fi
	@codesign --force --deep --sign - $(APP) 2>/dev/null || true

run: $(TARGET)
	./$(TARGET)

run-cli: $(TARGET)
	./$(TARGET) --cli --source mic --sensitivity 1.6

installer: app
	./create_installer.sh

clean:
	rm -rf build

.PHONY: all app run run-cli installer clean
