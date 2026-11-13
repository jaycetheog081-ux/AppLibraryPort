#import <UIKit/UIKit.h>
#import "AppLibrary12ViewController.h"

static UIWindow *AppLibrary12Window;
static AppLibrary12GestureTarget *AppLibrary12Target;
static NSMutableSet<NSValue *> *AppLibrary12AttachedWindows;

@interface SpringBoard : UIApplication
@end

@interface AppLibrary12GestureTarget : NSObject
- (void)handleGesture:(UIScreenEdgePanGestureRecognizer *)gesture;
@end

static void AppLibrary12ShowLibrary(void) {
    if (AppLibrary12Window) {
        AppLibrary12Window.hidden = NO;
        [AppLibrary12Window makeKeyAndVisible];
        return;
    }

    UIWindow *window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];

    window.windowLevel = UIWindowLevelAlert + 1;
    window.backgroundColor = UIColor.clearColor;

    AppLibrary12ViewController *controller =
        [[AppLibrary12ViewController alloc] init];

    window.rootViewController = controller;

    AppLibrary12Window = window;

    [window makeKeyAndVisible];
}

@implementation AppLibrary12GestureTarget

- (void)handleGesture:(UIScreenEdgePanGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateEnded) {
        return;
    }

    CGPoint translation = [gesture translationInView:gesture.view];

    if (translation.x < -35.0) {
        AppLibrary12ShowLibrary();
    }
}

@end

static void AppLibrary12AttachGestureToWindow(UIWindow *window) {
    if (!window || window == AppLibrary12Window) {
        return;
    }

    if (!AppLibrary12AttachedWindows) {
        AppLibrary12AttachedWindows = [NSMutableSet set];
    }

    NSValue *windowKey = [NSValue valueWithNonretainedObject:window];

    if ([AppLibrary12AttachedWindows containsObject:windowKey]) {
        return;
    }

    AppLibrary12Target = AppLibrary12Target ?:
        [[AppLibrary12GestureTarget alloc] init];

    UIScreenEdgePanGestureRecognizer *gesture =
        [[UIScreenEdgePanGestureRecognizer alloc]
            initWithTarget:AppLibrary12Target
            action:@selector(handleGesture:)];

    gesture.edges = UIRectEdgeRight;
    gesture.cancelsTouchesInView = NO;
    gesture.delaysTouchesBegan = NO;

    [window addGestureRecognizer:gesture];

    [AppLibrary12AttachedWindows addObject:windowKey];
}

static void AppLibrary12FindWindows(void) {
    UIApplication *application = UIApplication.sharedApplication;

    for (UIWindow *window in application.windows) {
        AppLibrary12AttachGestureToWindow(window);
    }

    if (application.keyWindow) {
        AppLibrary12AttachGestureToWindow(application.keyWindow);
    }
}

static void AppLibrary12StartWindowMonitoring(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        AppLibrary12FindWindows();

        static NSInteger attempts = 0;

        if (attempts++ < 30) {
            dispatch_after(
                dispatch_time(DISPATCH_TIME_NOW,
                              (int64_t)(1.0 * NSEC_PER_SEC)),
                dispatch_get_main_queue(),
                ^{
                    AppLibrary12FindWindows();
                }
            );
        }
    });
}

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;

    AppLibrary12StartWindowMonitoring();

    [[NSNotificationCenter defaultCenter]
        addObserverForName:UIWindowDidBecomeVisibleNotification
        object:nil
        queue:[NSOperationQueue mainQueue]
        usingBlock:^(NSNotification *notification) {
            if ([notification.object isKindOfClass:UIWindow.class]) {
                AppLibrary12AttachGestureToWindow(notification.object);
            }
        }];
}

%end
