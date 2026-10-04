//
//  main.m
//  keyboard light mac
//

#import <Cocoa/Cocoa.h>
#import "AppController.h"
#import "KeyboardController.h"
#import "AudioCaptureEngine.h"
#import <signal.h>

static void handleSignal(int sig) {
    fprintf(stderr, "\nCerrando Keyboard Light Mac... Restaurando brillo del teclado.\n");
    [[AudioCaptureEngine sharedEngine] stop];
    [[TypingSpeedometerEngine sharedEngine] stop];
    [[KeyboardController sharedController] restoreOriginalBrightness];
    exit(0);
}

int main(int argc, const char * argv[]) {
    signal(SIGINT, handleSignal);
    signal(SIGTERM, handleSignal);
    
    @autoreleasepool {
        BOOL cliMode = NO;
        NSString *source = @"mic";
        float sensitivity = 1.6f;
        NSInteger mode = 0;
        
        for (int i = 1; i < argc; i++) {
            NSString *arg = [NSString stringWithUTF8String:argv[i]];
            if ([arg isEqualToString:@"--cli"]) {
                cliMode = YES;
            } else if ([arg isEqualToString:@"--source"] && i + 1 < argc) {
                source = [NSString stringWithUTF8String:argv[++i]];
            } else if ([arg isEqualToString:@"--sensitivity"] && i + 1 < argc) {
                sensitivity = atof(argv[++i]);
            } else if ([arg isEqualToString:@"--mode"] && i + 1 < argc) {
                mode = atoi(argv[++i]);
            } else if ([arg isEqualToString:@"--help"] || [arg isEqualToString:@"-h"]) {
                printf("Uso: keyboard-light [opciones]\n\n");
                printf("Opciones:\n");
                printf("  --cli                 Ejecutar en modo consola / terminal sin interfaz grafica\n");
                printf("  --source <system|mic|typing> Fuente: 'system' (musica Mac), 'mic' (microfono) o 'typing' (velocimetro)\n");
                printf("  --sensitivity <float> Factor de sensibilidad (audio: 1.8 | velocimetro: 75 WPM objetivo)\n");
                printf("  --mode <0|1|2|3>      Modo:\n");
                printf("                          Audio:       0=Strobe, 1=Ritmo/Bajo, 2=RMS, 3=Hibrido\n");
                printf("                          Velocimetro: 0=Destello tecla, 1=Tacometro WPM, 2=Turbo Strobe\n");
                printf("  --help, -h            Muestra esta ayuda\n");
                return 0;
            }
        }
        
        NSApplication *app = [NSApplication sharedApplication];
        AppController *controller = [[AppController alloc] init];
        app.delegate = controller;
        
        if (cliMode) {
            [controller startCLIWithSource:source sensitivity:sensitivity mode:mode];
            [[NSRunLoop currentRunLoop] run];
        } else {
            // Accessory app (lives in menu bar without taking dock space)
            [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
            [app run];
        }
    }
    return 0;
}
