#import <UIKit/UIKit.h>
#import "AppLibrary12ViewController.h"

static UIWindow *AppLibrary12Window;
static UIScreenEdgePanGestureRecognizer *AppLibrary12Gesture;

@interface SpringBoard : UIApplication
@end

static void AppLibrary12ShowLibrary(void) {
    if (AppLibrary12Window) {
        AppLibrary12Window.hidden = NO;
        [AppLibrary12Window makeKeyAndVisible];
        return;
    }

    UIWindow *window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    window.windowLevel = UIWindowLevelAlert + 1;
    window.backgroundColor = [UIColor clearColor];

    AppLibrary12ViewController *controller =
        [[AppLibrary12ViewController alloc] init];

    window.rootViewController = controller;
    AppLibrary12Window = window;

    [window makeKeyAndVisible];
}

@interface AppLibrary12GestureTarget : NSObject
- (void)handleGesture:(UIScreenEdgePanGestureRecognizer *)gesture;
@end

@implementation AppLibrary12GestureTarget

- (void)handleGesture:(UIScreenEdgePanGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateEnded) {
        CGPoint translation = [gesture translationInView:gesture.view];

        if (translation.x < -35.0) {
            AppLibrary12ShowLibrary();
        }
    }
}

@end

static AppLibrary12GestureTarget *AppLibrary12Target;

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        UIWindow *window = UIApplication.sharedApplication.keyWindow;

        if (!window || AppLibrary12Gesture) {
            return;
        }

        AppLibrary12Target = [[AppLibrary12GestureTarget alloc] init];

        AppLibrary12Gesture =
            [[UIScreenEdgePanGestureRecognizer alloc]
             initWithTarget:AppLibrary12Target
             action:@selector(handleGesture:)];

        AppLibrary12Gesture.edges = UIRectEdgeRight;
        [window addGestureRecognizer:AppLibrary12Gesture];
    });
}

%end
