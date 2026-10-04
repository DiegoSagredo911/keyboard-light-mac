//
//  AppController.m
//  keyboard light mac
//

#import "AppController.h"
#import "KeyboardController.h"
#import "AudioAnalyzer.h"
#import "AudioCaptureEngine.h"
#import "TypingSpeedometerEngine.h"

@interface AppController () {
    NSStatusItem *_statusItem;
    NSPopover *_popover;
    NSViewController *_popoverVC;
    
    // UI Elements
    NSButton *_toggleButton;
    NSTextField *_statusLabel;
    NSPopUpButton *_sourcePopup;
    NSPopUpButton *_modePopup;
    
    NSSlider *_sensitivitySlider;
    NSTextField *_sensitivityLabel;
    
    NSSlider *_flashDurationSlider;
    NSTextField *_flashDurationLabel;
    
    NSSlider *_minBrightnessSlider;
    NSTextField *_minBrightnessLabel;
    
    NSSlider *_maxBrightnessSlider;
    NSTextField *_maxBrightnessLabel;
    
    NSLevelIndicator *_levelIndicator;
    NSTextField *_meterLabel;
    NSView *_beatIndicatorDot;
    
    NSArray<AudioDeviceInfo *> *_devices;
    BOOL _isTypingMode;
}
@end

@implementation AppController

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [AudioCaptureEngine sharedEngine].delegate = self;
    [TypingSpeedometerEngine sharedEngine].delegate = self;
    _isTypingMode = NO;
    
    // Check if keyboard backlight is accessible
    if (![KeyboardController sharedController].isAvailable) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Teclado retroiluminado no detectado";
        alert.informativeText = @"No se detectó un teclado con retroiluminación compatible en este Mac.";
        alert.alertStyle = NSAlertStyleWarning;
        [alert runModal];
    } else {
        // Apagado automático inicial
        [[KeyboardController sharedController] turnOff];
    }
    
    [self setupStatusItem];
    [self setupPopover];
    
    // Auto-start capture on launch
    [self startCapture];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [[AudioCaptureEngine sharedEngine] stop];
    [[TypingSpeedometerEngine sharedEngine] stop];
    [[KeyboardController sharedController] restoreOriginalBrightness];
}

#pragma mark - Menu Bar & Popover Setup

- (void)setupStatusItem {
    _statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    NSStatusBarButton *button = _statusItem.button;
    if (button) {
        button.title = @"⌨️⚡️";
        button.target = self;
        button.action = @selector(togglePopover:);
    }
}

- (void)setupPopover {
    _popover = [[NSPopover alloc] init];
    _popover.behavior = NSPopoverBehaviorTransient;
    _popover.animates = YES;
    
    _popoverVC = [[NSViewController alloc] init];
    NSView *containerView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 320, 580)];
    _popoverVC.view = containerView;
    _popover.contentViewController = _popoverVC;
    
    [self buildUIInView:containerView];
}

- (void)togglePopover:(id)sender {
    if (_popover.isShown) {
        [_popover performClose:sender];
    } else {
        if (_statusItem.button) {
            [self refreshDevices];
            [_popover showRelativeToRect:_statusItem.button.bounds ofView:_statusItem.button preferredEdge:NSRectEdgeMinY];
            [NSApp activateIgnoringOtherApps:YES];
        }
    }
}

#pragma mark - UI Building

- (void)buildUIInView:(NSView *)view {
    CGFloat y = 525;
    
    // App Icon
    NSImageView *iconView = [[NSImageView alloc] initWithFrame:NSMakeRect(16, y - 4, 38, 38)];
    NSString *iconPath = [[NSBundle mainBundle] pathForResource:@"AppIcon" ofType:@"icns"];
    if (!iconPath) {
        iconPath = @"assets/AppIcon.png";
    }
    if (iconPath) {
        iconView.image = [[NSImage alloc] initWithContentsOfFile:iconPath];
    }
    iconView.imageScaling = NSImageScaleProportionallyUpOrDown;
    iconView.wantsLayer = YES;
    iconView.layer.cornerRadius = 8.0;
    iconView.layer.masksToBounds = YES;
    [view addSubview:iconView];
    
    // Header Title
    NSTextField *title = [[NSTextField alloc] initWithFrame:NSMakeRect(62, y + 8, 242, 22)];
    title.stringValue = @"Keyboard Light Mac";
    title.font = [NSFont boldSystemFontOfSize:15];
    title.bezeled = NO;
    title.drawsBackground = NO;
    title.editable = NO;
    title.selectable = NO;
    [view addSubview:title];
    
    // Subtitle / Status
    _statusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(62, y - 10, 242, 18)];
    _statusLabel.stringValue = @"🟢 Activo (Sincronizando)";
    _statusLabel.font = [NSFont systemFontOfSize:11];
    _statusLabel.textColor = [NSColor secondaryLabelColor];
    _statusLabel.bezeled = NO;
    _statusLabel.drawsBackground = NO;
    _statusLabel.editable = NO;
    _statusLabel.selectable = NO;
    [view addSubview:_statusLabel];
    y -= 36;
    
    // Start / Stop Toggle Button
    _toggleButton = [[NSButton alloc] initWithFrame:NSMakeRect(16, y, 288, 30)];
    _toggleButton.title = @"Detener Iluminación";
    _toggleButton.bezelStyle = NSBezelStyleRounded;
    _toggleButton.target = self;
    _toggleButton.action = @selector(toggleAction:);
    [view addSubview:_toggleButton];
    y -= 36;
    
    // Separator 1
    NSBox *sep1 = [[NSBox alloc] initWithFrame:NSMakeRect(16, y, 288, 1)];
    sep1.boxType = NSBoxSeparator;
    [view addSubview:sep1];
    y -= 26;
    
    // Mode Source Label & Popup
    NSTextField *srcLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(16, y, 110, 20)];
    srcLabel.stringValue = @"Fuente:";
    srcLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    srcLabel.bezeled = NO;
    srcLabel.drawsBackground = NO;
    srcLabel.editable = NO;
    [view addSubview:srcLabel];
    
    _sourcePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(130, y - 2, 174, 24) pullsDown:NO];
    _sourcePopup.target = self;
    _sourcePopup.action = @selector(sourceChanged:);
    [view addSubview:_sourcePopup];
    y -= 30;
    
    // Reaction Mode Label & Popup
    NSTextField *modeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(16, y, 110, 20)];
    modeLabel.stringValue = @"Modo reactivo:";
    modeLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    modeLabel.bezeled = NO;
    modeLabel.drawsBackground = NO;
    modeLabel.editable = NO;
    [view addSubview:modeLabel];
    
    _modePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(130, y - 2, 174, 24) pullsDown:NO];
    _modePopup.target = self;
    _modePopup.action = @selector(modeChanged:);
    [view addSubview:_modePopup];
    y -= 32;
    
    // Separator 2
    NSBox *sep2 = [[NSBox alloc] initWithFrame:NSMakeRect(16, y, 288, 1)];
    sep2.boxType = NSBoxSeparator;
    [view addSubview:sep2];
    y -= 24;
    
    // Sensitivity / WPM Slider
    _sensitivityLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(16, y, 288, 18)];
    _sensitivityLabel.stringValue = [NSString stringWithFormat:@"Sensibilidad: %.1fx", [AudioAnalyzer sharedAnalyzer].sensitivity];
    _sensitivityLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    _sensitivityLabel.bezeled = NO;
    _sensitivityLabel.drawsBackground = NO;
    _sensitivityLabel.editable = NO;
    [view addSubview:_sensitivityLabel];
    y -= 22;
    
    _sensitivitySlider = [[NSSlider alloc] initWithFrame:NSMakeRect(16, y, 288, 20)];
    _sensitivitySlider.minValue = 0.2;
    _sensitivitySlider.maxValue = 4.0;
    _sensitivitySlider.floatValue = [AudioAnalyzer sharedAnalyzer].sensitivity;
    _sensitivitySlider.target = self;
    _sensitivitySlider.action = @selector(sensitivityChanged:);
    [view addSubview:_sensitivitySlider];
    y -= 28;
    
    // Flash Duration Slider
    _flashDurationLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(16, y, 288, 18)];
    _flashDurationLabel.stringValue = [NSString stringWithFormat:@"Velocidad de Flash (Strobe): %.0f ms", [AudioAnalyzer sharedAnalyzer].flashDuration * 1000.0];
    _flashDurationLabel.font = [NSFont systemFontOfSize:11];
    _flashDurationLabel.textColor = [NSColor secondaryLabelColor];
    _flashDurationLabel.bezeled = NO;
    _flashDurationLabel.drawsBackground = NO;
    _flashDurationLabel.editable = NO;
    [view addSubview:_flashDurationLabel];
    y -= 20;
    
    _flashDurationSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(16, y, 288, 18)];
    _flashDurationSlider.minValue = 20.0;
    _flashDurationSlider.maxValue = 100.0;
    _flashDurationSlider.floatValue = (float)([AudioAnalyzer sharedAnalyzer].flashDuration * 1000.0);
    _flashDurationSlider.target = self;
    _flashDurationSlider.action = @selector(flashDurationChanged:);
    [view addSubview:_flashDurationSlider];
    y -= 26;
    
    // Min Brightness Slider
    _minBrightnessLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(16, y, 288, 18)];
    _minBrightnessLabel.stringValue = [NSString stringWithFormat:@"Brillo Mínimo (Reposo): %.0f%%", [AudioAnalyzer sharedAnalyzer].minBrightness * 100.0];
    _minBrightnessLabel.font = [NSFont systemFontOfSize:11];
    _minBrightnessLabel.textColor = [NSColor secondaryLabelColor];
    _minBrightnessLabel.bezeled = NO;
    _minBrightnessLabel.drawsBackground = NO;
    _minBrightnessLabel.editable = NO;
    [view addSubview:_minBrightnessLabel];
    y -= 20;
    
    _minBrightnessSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(16, y, 288, 18)];
    _minBrightnessSlider.minValue = 0.0;
    _minBrightnessSlider.maxValue = 0.5;
    _minBrightnessSlider.floatValue = [AudioAnalyzer sharedAnalyzer].minBrightness;
    _minBrightnessSlider.target = self;
    _minBrightnessSlider.action = @selector(minBrightnessChanged:);
    [view addSubview:_minBrightnessSlider];
    y -= 26;
    
    // Max Brightness Slider
    _maxBrightnessLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(16, y, 288, 18)];
    _maxBrightnessLabel.stringValue = [NSString stringWithFormat:@"Brillo Máximo: %.0f%%", [AudioAnalyzer sharedAnalyzer].maxBrightness * 100.0];
    _maxBrightnessLabel.font = [NSFont systemFontOfSize:11];
    _maxBrightnessLabel.textColor = [NSColor secondaryLabelColor];
    _maxBrightnessLabel.bezeled = NO;
    _maxBrightnessLabel.drawsBackground = NO;
    _maxBrightnessLabel.editable = NO;
    [view addSubview:_maxBrightnessLabel];
    y -= 20;
    
    _maxBrightnessSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(16, y, 288, 18)];
    _maxBrightnessSlider.minValue = 0.4;
    _maxBrightnessSlider.maxValue = 1.0;
    _maxBrightnessSlider.floatValue = [AudioAnalyzer sharedAnalyzer].maxBrightness;
    _maxBrightnessSlider.target = self;
    _maxBrightnessSlider.action = @selector(maxBrightnessChanged:);
    [view addSubview:_maxBrightnessSlider];
    y -= 26;
    
    // Live VU / Speedometer Meter & Beat Dot
    _meterLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(16, y, 250, 18)];
    _meterLabel.stringValue = @"Medidor en vivo:";
    _meterLabel.font = [NSFont systemFontOfSize:11];
    _meterLabel.textColor = [NSColor secondaryLabelColor];
    _meterLabel.bezeled = NO;
    _meterLabel.drawsBackground = NO;
    _meterLabel.editable = NO;
    [view addSubview:_meterLabel];
    
    _beatIndicatorDot = [[NSView alloc] initWithFrame:NSMakeRect(284, y + 2, 14, 14)];
    _beatIndicatorDot.wantsLayer = YES;
    _beatIndicatorDot.layer.cornerRadius = 7.0;
    _beatIndicatorDot.layer.backgroundColor = [NSColor lightGrayColor].CGColor;
    [view addSubview:_beatIndicatorDot];
    y -= 22;
    
    _levelIndicator = [[NSLevelIndicator alloc] initWithFrame:NSMakeRect(16, y, 288, 16)];
    _levelIndicator.levelIndicatorStyle = NSLevelIndicatorStyleContinuousCapacity;
    _levelIndicator.minValue = 0.0;
    _levelIndicator.maxValue = 1.0;
    _levelIndicator.warningValue = 0.75;
    _levelIndicator.criticalValue = 0.90;
    _levelIndicator.doubleValue = 0.0;
    [view addSubview:_levelIndicator];
    y -= 30;
    
    // Separator 3
    NSBox *sep3 = [[NSBox alloc] initWithFrame:NSMakeRect(16, y, 288, 1)];
    sep3.boxType = NSBoxSeparator;
    [view addSubview:sep3];
    y -= 32;
    
    // Bottom Buttons
    NSButton *testBtn = [[NSButton alloc] initWithFrame:NSMakeRect(16, y, 136, 26)];
    testBtn.title = @"Probar Strobe ⚡️";
    testBtn.bezelStyle = NSBezelStyleRounded;
    testBtn.target = self;
    testBtn.action = @selector(testPulseAction:);
    [view addSubview:testBtn];
    
    NSButton *quitBtn = [[NSButton alloc] initWithFrame:NSMakeRect(168, y, 136, 26)];
    quitBtn.title = @"Salir";
    quitBtn.bezelStyle = NSBezelStyleRounded;
    quitBtn.target = self;
    quitBtn.action = @selector(quitAction:);
    [view addSubview:quitBtn];
    y -= 28;
    
    // Footer Link: Diego Sagredo -> https://github.com/diegosagredo911
    NSButton *authorLinkBtn = [[NSButton alloc] initWithFrame:NSMakeRect(16, y, 288, 20)];
    authorLinkBtn.bordered = NO;
    authorLinkBtn.buttonType = NSButtonTypeMomentaryPushIn;
    
    NSMutableAttributedString *attrTitle = [[NSMutableAttributedString alloc] initWithString:@"Desarrollado por Diego Sagredo"
                                                                                    attributes:@{
        NSForegroundColorAttributeName: [NSColor secondaryLabelColor],
        NSFontAttributeName: [NSFont systemFontOfSize:11]
    }];
    NSRange nameRange = [attrTitle.string rangeOfString:@"Diego Sagredo"];
    if (nameRange.location != NSNotFound) {
        [attrTitle addAttribute:NSForegroundColorAttributeName value:[NSColor linkColor] range:nameRange];
        [attrTitle addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:nameRange];
    }
    authorLinkBtn.attributedTitle = attrTitle;
    authorLinkBtn.target = self;
    authorLinkBtn.action = @selector(openAuthorGithub:);
    [view addSubview:authorLinkBtn];
    
    [self refreshDevices];
    [self updateModeMenuForCurrentSource];
}

- (void)refreshDevices {
    [_sourcePopup removeAllItems];
    [_sourcePopup addItemWithTitle:@"🎵 Audio del Sistema (Mac)"];
    [_sourcePopup addItemWithTitle:@"🎤 Micrófono Interno"];
    [_sourcePopup addItemWithTitle:@"🏎 Velocímetro de Escritura (WPM)"];
    
    _devices = [AudioCaptureEngine availableInputDevices];
    for (AudioDeviceInfo *dev in _devices) {
        if (![dev.name containsString:@"Micrófono de MacBook"]) {
            [_sourcePopup addItemWithTitle:[NSString stringWithFormat:@"🎧 %@", dev.name]];
        }
    }
    
    if (_isTypingMode) {
        [_sourcePopup selectItemAtIndex:2];
    } else {
        AudioSourceType curType = [AudioCaptureEngine sharedEngine].sourceType;
        if (curType == AudioSourceTypeSystemAudio) {
            [_sourcePopup selectItemAtIndex:0];
        } else if (curType == AudioSourceTypeMicrophone) {
            [_sourcePopup selectItemAtIndex:1];
        }
    }
}

- (void)updateModeMenuForCurrentSource {
    [_modePopup removeAllItems];
    if (_isTypingMode) {
        [_modePopup addItemWithTitle:@"⚡️ Destello por Tecla (Key Strobe)"];
        [_modePopup addItemWithTitle:@"🏎 Tacómetro Progresivo (WPM Rev)"];
        [_modePopup addItemWithTitle:@"🔥 Turbo Strobe (Alta Velocidad)"];
        [_modePopup selectItemAtIndex:(NSInteger)[TypingSpeedometerEngine sharedEngine].mode];
        
        _sensitivityLabel.stringValue = [NSString stringWithFormat:@"Velocidad Objetivo: %.0f WPM", [TypingSpeedometerEngine sharedEngine].targetMaxWPM];
        _sensitivitySlider.minValue = 30.0;
        _sensitivitySlider.maxValue = 150.0;
        _sensitivitySlider.floatValue = [TypingSpeedometerEngine sharedEngine].targetMaxWPM;
    } else {
        [_modePopup addItemWithTitle:@"⚡️ Estroboscópico (Strobe)"];
        [_modePopup addItemWithTitle:@"🥁 Ritmo (Beat / Bajo)"];
        [_modePopup addItemWithTitle:@"🌊 Volumen Fluido (RMS)"];
        [_modePopup addItemWithTitle:@"💫 Híbrido (Base + Beat)"];
        [_modePopup selectItemAtIndex:(NSInteger)[AudioAnalyzer sharedAnalyzer].mode];
        
        _sensitivityLabel.stringValue = [NSString stringWithFormat:@"Sensibilidad: %.1fx", [AudioAnalyzer sharedAnalyzer].sensitivity];
        _sensitivitySlider.minValue = 0.2;
        _sensitivitySlider.maxValue = 4.0;
        _sensitivitySlider.floatValue = [AudioAnalyzer sharedAnalyzer].sensitivity;
    }
}

#pragma mark - Actions

- (void)toggleAction:(id)sender {
    BOOL running = _isTypingMode ? [TypingSpeedometerEngine sharedEngine].isRunning : [AudioCaptureEngine sharedEngine].isRunning;
    if (running) {
        [self stopCapture];
    } else {
        [self startCapture];
    }
}

- (void)startCapture {
    if (_isTypingMode) {
        [[AudioCaptureEngine sharedEngine] stop];
        BOOL ok = [[TypingSpeedometerEngine sharedEngine] start];
        if (ok) {
            _statusLabel.stringValue = @"🟢 Activo (Velocímetro de Escritura)";
            _toggleButton.title = @"Detener Velocímetro";
            if (_statusItem.button) _statusItem.button.title = @"⌨️🏎";
        }
    } else {
        [[TypingSpeedometerEngine sharedEngine] stop];
        BOOL ok = [[AudioCaptureEngine sharedEngine] start];
        if (ok) {
            _statusLabel.stringValue = @"🟢 Activo (Sincronizando con música)";
            _toggleButton.title = @"Detener Iluminación";
            if (_statusItem.button) _statusItem.button.title = @"⌨️⚡️";
        }
    }
}

- (void)stopCapture {
    if (_isTypingMode) {
        [[TypingSpeedometerEngine sharedEngine] stop];
    } else {
        [[AudioCaptureEngine sharedEngine] stop];
    }
    _statusLabel.stringValue = @"⚪️ Pausado";
    _toggleButton.title = @"Activar";
    _levelIndicator.doubleValue = 0.0;
    if (_statusItem.button) _statusItem.button.title = @"⌨️💤";
}

- (void)sourceChanged:(id)sender {
    NSInteger idx = _sourcePopup.indexOfSelectedItem;
    if (idx == 0) {
        // Audio del Sistema
        _isTypingMode = NO;
        [[TypingSpeedometerEngine sharedEngine] stop];
        [[AudioCaptureEngine sharedEngine] setSourceType:AudioSourceTypeSystemAudio deviceID:0];
    } else if (idx == 1) {
        // Micrófono
        _isTypingMode = NO;
        [[TypingSpeedometerEngine sharedEngine] stop];
        [[AudioCaptureEngine sharedEngine] setSourceType:AudioSourceTypeMicrophone deviceID:0];
    } else if (idx == 2) {
        // Velocímetro de Escritura
        _isTypingMode = YES;
        [[AudioCaptureEngine sharedEngine] stop];
        [self startCapture];
    } else {
        // Dispositivo externo
        _isTypingMode = NO;
        [[TypingSpeedometerEngine sharedEngine] stop];
        NSInteger devIdx = idx - 3;
        if (devIdx >= 0 && devIdx < (NSInteger)_devices.count) {
            AudioDeviceID devID = _devices[devIdx].deviceID;
            [[AudioCaptureEngine sharedEngine] setSourceType:AudioSourceTypeCustomDevice deviceID:devID];
        }
    }
    [self updateModeMenuForCurrentSource];
}

- (void)modeChanged:(id)sender {
    NSInteger idx = _modePopup.indexOfSelectedItem;
    if (_isTypingMode) {
        [TypingSpeedometerEngine sharedEngine].mode = (TypingMode)idx;
    } else {
        [AudioAnalyzer sharedAnalyzer].mode = (AudioReactionMode)idx;
    }
}

- (void)sensitivityChanged:(id)sender {
    if (_isTypingMode) {
        float val = _sensitivitySlider.floatValue;
        [TypingSpeedometerEngine sharedEngine].targetMaxWPM = val;
        _sensitivityLabel.stringValue = [NSString stringWithFormat:@"Velocidad Objetivo: %.0f WPM", val];
    } else {
        float val = _sensitivitySlider.floatValue;
        [AudioAnalyzer sharedAnalyzer].sensitivity = val;
        _sensitivityLabel.stringValue = [NSString stringWithFormat:@"Sensibilidad: %.1fx", val];
    }
}

- (void)flashDurationChanged:(id)sender {
    float ms = _flashDurationSlider.floatValue;
    [AudioAnalyzer sharedAnalyzer].flashDuration = (NSTimeInterval)(ms / 1000.0);
    [TypingSpeedometerEngine sharedEngine].flashDuration = (NSTimeInterval)(ms / 1000.0);
    _flashDurationLabel.stringValue = [NSString stringWithFormat:@"Velocidad de Flash (Strobe): %.0f ms", ms];
}

- (void)minBrightnessChanged:(id)sender {
    float val = _minBrightnessSlider.floatValue;
    [AudioAnalyzer sharedAnalyzer].minBrightness = val;
    _minBrightnessLabel.stringValue = [NSString stringWithFormat:@"Brillo Mínimo (Reposo): %.0f%%", val * 100.0];
}

- (void)maxBrightnessChanged:(id)sender {
    float val = _maxBrightnessSlider.floatValue;
    [AudioAnalyzer sharedAnalyzer].maxBrightness = val;
    _maxBrightnessLabel.stringValue = [NSString stringWithFormat:@"Brillo Máximo: %.0f%%", val * 100.0];
}

- (void)testPulseAction:(id)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        float orig = [KeyboardController sharedController].currentBrightness;
        for (int i = 0; i < 6; i++) {
            [[KeyboardController sharedController] setBrightness:1.0f];
            usleep(35000);
            [[KeyboardController sharedController] setBrightness:0.0f];
            usleep(55000);
        }
        [[KeyboardController sharedController] setBrightness:orig];
    });
}

- (void)quitAction:(id)sender {
    [[AudioCaptureEngine sharedEngine] stop];
    [[TypingSpeedometerEngine sharedEngine] stop];
    [[KeyboardController sharedController] restoreOriginalBrightness];
    [NSApp terminate:nil];
}

- (void)openAuthorGithub:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/diegosagredo911"]];
}

#pragma mark - AudioCaptureEngineDelegate

- (void)audioCaptureDidOutputLevel:(float)level brightness:(float)brightness isBeat:(BOOL)isBeat {
    if (_isTypingMode) return;
    _levelIndicator.doubleValue = level;
    if (isBeat) {
        _beatIndicatorDot.layer.backgroundColor = [NSColor systemOrangeColor].CGColor;
    } else {
        _beatIndicatorDot.layer.backgroundColor = [NSColor systemGrayColor].CGColor;
    }
    _meterLabel.stringValue = [NSString stringWithFormat:@"Nivel audio: %.0f%% | Brillo: %.0f%%", level * 100.0, brightness * 100.0];
}

- (void)audioCaptureDidFailWithError:(NSString *)errorMessage {
    _statusLabel.stringValue = [NSString stringWithFormat:@"⚠️ Error: %@", errorMessage];
}

- (void)audioCapturePermissionNeeded:(NSString *)permissionType {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Permiso Requerido";
    alert.informativeText = [NSString stringWithFormat:@"Para capturar el audio del sistema, macOS requiere que habilites '%@' en Ajustes del Sistema > Privacidad y Seguridad.", permissionType];
    alert.alertStyle = NSAlertStyleInformational;
    [alert addButtonWithTitle:@"Abrir Ajustes"];
    [alert addButtonWithTitle:@"Usar Micrófono"];
    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"]];
    } else {
        [_sourcePopup selectItemAtIndex:1];
        [self sourceChanged:nil];
    }
}

#pragma mark - TypingSpeedometerDelegate

- (void)typingSpeedometerDidUpdateWPM:(float)wpm cps:(float)cps brightness:(float)brightness isKeyStroke:(BOOL)isKeyStroke {
    if (!_isTypingMode) return;
    float norm = [TypingSpeedometerEngine sharedEngine].normalizedSpeed;
    _levelIndicator.doubleValue = norm;
    if (isKeyStroke) {
        _beatIndicatorDot.layer.backgroundColor = [NSColor systemOrangeColor].CGColor;
    } else {
        _beatIndicatorDot.layer.backgroundColor = [NSColor systemGrayColor].CGColor;
    }
    _meterLabel.stringValue = [NSString stringWithFormat:@"Velocímetro: %.0f WPM (%.1f tcl/s) | Brillo: %.0f%%", wpm, cps, brightness * 100.0];
}

- (void)typingSpeedometerPermissionNeeded {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Permiso de Accesibilidad Requerido";
    alert.informativeText = @"Para medir la velocidad de escritura del teclado de forma global en tu Mac, macOS requiere permisos de Accesibilidad en Ajustes del Sistema > Privacidad y Seguridad > Accesibilidad.";
    alert.alertStyle = NSAlertStyleInformational;
    [alert addButtonWithTitle:@"Abrir Ajustes"];
    [alert addButtonWithTitle:@"OK"];
    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]];
    }
}

#pragma mark - CLI Mode Support

- (void)startCLIWithSource:(NSString *)source sensitivity:(float)sensitivity mode:(NSInteger)mode {
    NSLog(@"=== Keyboard Light Mac (Modo Terminal) ===");
    
    if ([source.lowercaseString isEqualToString:@"typing"] || [source.lowercaseString isEqualToString:@"speedometer"] || [source.lowercaseString isEqualToString:@"wpm"]) {
        _isTypingMode = YES;
        [TypingSpeedometerEngine sharedEngine].mode = (TypingMode)mode;
        if (sensitivity > 20.0f) {
            [TypingSpeedometerEngine sharedEngine].targetMaxWPM = sensitivity;
        }
        NSLog(@"Fuente: Velocímetro de Escritura (Teclado / WPM)");
        NSLog(@"Modo: %ld (0=Destello por tecla, 1=Tacómetro WPM, 2=Turbo)", (long)mode);
        NSLog(@"Presiona teclas en tu Mac para probar el velocímetro.");
        [TypingSpeedometerEngine sharedEngine].delegate = self;
        [[TypingSpeedometerEngine sharedEngine] start];
    } else {
        _isTypingMode = NO;
        [AudioAnalyzer sharedAnalyzer].sensitivity = sensitivity;
        [AudioAnalyzer sharedAnalyzer].mode = (AudioReactionMode)mode;
        
        if ([source.lowercaseString isEqualToString:@"system"]) {
            [AudioCaptureEngine sharedEngine].sourceType = AudioSourceTypeSystemAudio;
            NSLog(@"Fuente: Audio del Sistema (Música del Mac)");
        } else {
            [AudioCaptureEngine sharedEngine].sourceType = AudioSourceTypeMicrophone;
            NSLog(@"Fuente: Micrófono");
        }
        
        NSLog(@"Sensibilidad: %.1fx", sensitivity);
        NSLog(@"Modo: %ld (0=Strobe, 1=Beat, 2=RMS, 3=Híbrido)", (long)mode);
        [AudioCaptureEngine sharedEngine].delegate = self;
        [[AudioCaptureEngine sharedEngine] start];
    }
    
    NSLog(@"Apagando teclado para iniciar...");
    NSLog(@"Presiona Ctrl+C para salir.\n");
    [[KeyboardController sharedController] turnOff];
}

@end
