#import "AppLibrary12ViewController.h"
#import <objc/message.h>
#import <objc/runtime.h>

@interface LSApplicationProxy : NSObject
- (NSString *)localizedName;
- (NSString *)applicationIdentifier;
- (NSData *)iconDataForVariant:(NSInteger)variant;
- (NSDate *)installDate;
- (NSDate *)lastUsedDate;
@end

static char AppLibrary12ApplicationKey;

static id AppLibrary12GetWorkspace(void) {
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");

    if (!workspaceClass) return nil;

    SEL selector = NSSelectorFromString(@"defaultWorkspace");

    if (![workspaceClass respondsToSelector:selector]) return nil;

    return ((id (*)(id, SEL))objc_msgSend)(workspaceClass, selector);
}

@interface AppLibrary12ViewController () <UISearchBarDelegate>

@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *closeButton;

@property (nonatomic, strong) NSArray<LSApplicationProxy *> *applications;
@property (nonatomic, strong) NSArray<LSApplicationProxy *> *filteredApplications;
@property (nonatomic, strong) NSDictionary<NSString *, NSArray<LSApplicationProxy *> *> *categories;

@property (nonatomic, assign) NSInteger columnCount;

@end

@implementation AppLibrary12ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.applications = @[];
    self.filteredApplications = @[];
    self.categories = @{};

    [self buildInterface];
    [self loadApplications];
}

#pragma mark - Interface

- (void)buildInterface {
    self.view.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];

    UIBlurEffect *blur;

    if (@available(iOS 13.0, *)) {
        blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark];
    } else {
        blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    }

    UIVisualEffectView *backgroundBlur =
        [[UIVisualEffectView alloc] initWithEffect:blur];

    backgroundBlur.frame = self.view.bounds;
    backgroundBlur.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;

    [self.view addSubview:backgroundBlur];

    UIView *content = backgroundBlur.contentView;

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = @"App Library";
    self.titleLabel.font =
        [UIFont systemFontOfSize:32 weight:UIFontWeightBold];
    self.titleLabel.textColor = UIColor.whiteColor;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    [content addSubview:self.titleLabel];

    self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.closeButton setTitle:@"Done" forState:UIControlStateNormal];
    self.closeButton.titleLabel.font =
        [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [self.closeButton setTitleColor:UIColor.whiteColor
                           forState:UIControlStateNormal];
    self.closeButton.translatesAutoresizingMaskIntoConstraints = NO;

    [self.closeButton addTarget:self
                         action:@selector(closeLibrary)
               forControlEvents:UIControlEventTouchUpInside];

    [content addSubview:self.closeButton];

    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.placeholder = @"Search";
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.translucent = YES;
    self.searchBar.delegate = self;
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;

    [content addSubview:self.searchBar];

    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.backgroundColor = UIColor.clearColor;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.keyboardDismissMode =
        UIScrollViewKeyboardDismissModeOnDrag;

    [content addSubview:self.scrollView];

    self.contentStack = [[UIStackView alloc] init];
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = 14;
    self.contentStack.alignment = UIStackViewAlignmentFill;
    self.contentStack.distribution = UIStackViewDistributionFill;
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;

    [self.scrollView addSubview:self.contentStack];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;

    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.topAnchor
            constraintEqualToAnchor:safe.topAnchor constant:14],

        [self.titleLabel.leadingAnchor
            constraintEqualToAnchor:safe.leadingAnchor constant:22],

        [self.closeButton.centerYAnchor
            constraintEqualToAnchor:self.titleLabel.centerYAnchor],

        [self.closeButton.trailingAnchor
            constraintEqualToAnchor:safe.trailingAnchor constant:-22],

        [self.searchBar.topAnchor
            constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:8],

        [self.searchBar.leadingAnchor
            constraintEqualToAnchor:safe.leadingAnchor constant:12],

        [self.searchBar.trailingAnchor
            constraintEqualToAnchor:safe.trailingAnchor constant:-12],

        [self.scrollView.topAnchor
            constraintEqualToAnchor:self.searchBar.bottomAnchor constant:4],

        [self.scrollView.leadingAnchor
            constraintEqualToAnchor:safe.leadingAnchor constant:12],

        [self.scrollView.trailingAnchor
            constraintEqualToAnchor:safe.trailingAnchor constant:-12],

        [self.scrollView.bottomAnchor
            constraintEqualToAnchor:safe.bottomAnchor],

        [self.contentStack.topAnchor
            constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],

        [self.contentStack.leadingAnchor
            constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor],

        [self.contentStack.trailingAnchor
            constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor],

        [self.contentStack.bottomAnchor
            constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor],

        [self.contentStack.widthAnchor
            constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor]
    ]];

    [self updateColumnCount];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    NSInteger oldColumnCount = self.columnCount;
    [self updateColumnCount];

    if (oldColumnCount != self.columnCount) {
        [self rebuildContent];
    }
}

- (void)updateColumnCount {
    CGFloat width = self.view.bounds.size.width;

    if (width >= 1000) {
        self.columnCount = 5;
    } else if (width >= 750) {
        self.columnCount = 4;
    } else if (width >= 550) {
        self.columnCount = 3;
    } else {
        self.columnCount = 2;
    }
}

#pragma mark - Application loading

- (void)loadApplications {
    id workspace = AppLibrary12GetWorkspace();

    if (!workspace) return;

    SEL selector = NSSelectorFromString(@"allInstalledApplications");

    if (![workspace respondsToSelector:selector]) return;

    NSArray *installed =
        ((id (*)(id, SEL))objc_msgSend)(workspace, selector);

    if (![installed isKindOfClass:NSArray.class]) return;

    NSMutableArray *valid = [NSMutableArray array];

    for (id application in installed) {
        if (![application respondsToSelector:@selector(localizedName)] ||
            ![application respondsToSelector:@selector(applicationIdentifier)]) {
            continue;
        }

        NSString *name = [application localizedName];
        NSString *bundleID = [application applicationIdentifier];

        if (!name.length || !bundleID.length) continue;

        if ([bundleID hasPrefix:@"com.apple.springboard"]) continue;

        [valid addObject:application];
    }

    [valid sortUsingComparator:^NSComparisonResult(
        LSApplicationProxy *a,
        LSApplicationProxy *b
    ) {
        return [[a localizedName]
            localizedCaseInsensitiveCompare:[b localizedName]];
    }];

    self.applications = valid;
    self.filteredApplications = valid;

    [self buildCategories];
    [self rebuildContent];
}

#pragma mark - Categories

- (NSString *)categoryForApplication:(LSApplicationProxy *)application {
    NSString *name = [[application localizedName] lowercaseString];
    NSString *bundleID =
        [[application applicationIdentifier] lowercaseString];

    NSString *value = [NSString stringWithFormat:@"%@ %@", name, bundleID];

    NSArray *social = @[
        @"facebook", @"instagram", @"twitter", @"threads",
        @"snapchat", @"tiktok", @"discord", @"reddit",
        @"messenger", @"whatsapp", @"telegram", @"social"
    ];

    NSArray *entertainment = @[
        @"music", @"spotify", @"youtube", @"netflix",
        @"hulu", @"tv", @"video", @"podcast",
        @"twitch", @"game", @"entertainment"
    ];

    NSArray *creativity = @[
        @"camera", @"photo", @"photoshop", @"drawing",
        @"procreate", @"editor", @"creative", @"art"
    ];

    NSArray *productivity = @[
        @"notes", @"pages", @"numbers", @"keynote",
        @"document", @"calendar", @"mail", @"office",
        @"drive", @"dropbox", @"productivity"
    ];

    NSArray *utilities = @[
        @"settings", @"calculator", @"clock", @"weather",
        @"files", @"maps", @"compass", @"shortcuts",
        @"utility", @"browser"
    ];

    NSArray *groups = @[
        social,
        entertainment,
        creativity,
        productivity,
        utilities
    ];

    NSArray *names = @[
        @"Social",
        @"Entertainment",
        @"Creativity",
        @"Productivity",
        @"Utilities"
    ];

    for (NSInteger i = 0; i < groups.count; i++) {
        for (NSString *keyword in groups[i]) {
            if ([value containsString:keyword]) {
                return names[i];
            }
        }
    }

    return @"Other";
}

- (void)buildCategories {
    NSMutableDictionary *groups = [NSMutableDictionary dictionary];

    for (LSApplicationProxy *application in self.applications) {
        NSString *category = [self categoryForApplication:application];

        if (!groups[category]) {
            groups[category] = [NSMutableArray array];
        }

        [groups[category] addObject:application];
    }

    self.categories = groups;
}

- (NSArray<NSString *> *)orderedCategoryNames {
    NSArray *preferred = @[
        @"Suggestions",
        @"Recently Added",
        @"Social",
        @"Entertainment",
        @"Creativity",
        @"Productivity",
        @"Utilities",
        @"Other"
    ];

    NSMutableArray *result = [NSMutableArray array];

    for (NSString *name in preferred) {
        if ([name isEqualToString:@"Suggestions"] ||
            [name isEqualToString:@"Recently Added"]) {
            if (self.applications.count > 0) {
                [result addObject:name];
            }
        } else if (self.categories[name].count > 0) {
            [result addObject:name];
        }
    }

    return result;
}

- (NSArray<LSApplicationProxy *> *)applicationsForCategory:(NSString *)category {
    if ([category isEqualToString:@"Suggestions"]) {
        return [self suggestedApplications];
    }

    if ([category isEqualToString:@"Recently Added"]) {
        return [self recentlyAddedApplications];
    }

    return self.categories[category] ?: @[];
}

- (NSArray<LSApplicationProxy *> *)suggestedApplications {
    NSArray *sorted = [self.applications sortedArrayUsingComparator:^NSComparisonResult(
        LSApplicationProxy *a,
        LSApplicationProxy *b
    ) {
        NSDate *dateA = nil;
        NSDate *dateB = nil;

        if ([a respondsToSelector:@selector(lastUsedDate)]) {
            dateA = [a lastUsedDate];
        }

        if ([b respondsToSelector:@selector(lastUsedDate)]) {
            dateB = [b lastUsedDate];
        }

        if (!dateA && !dateB) return NSOrderedSame;
        if (!dateA) return NSOrderedDescending;
        if (!dateB) return NSOrderedAscending;

        return [dateB compare:dateA];
    }];

    return [sorted subarrayWithRange:
        NSMakeRange(0, MIN(4, sorted.count))];
}

- (NSArray<LSApplicationProxy *> *)recentlyAddedApplications {
    NSArray *sorted = [self.applications sortedArrayUsingComparator:^NSComparisonResult(
        LSApplicationProxy *a,
        LSApplicationProxy *b
    ) {
        NSDate *dateA = nil;
        NSDate *dateB = nil;

        if ([a respondsToSelector:@selector(installDate)]) {
            dateA = [a installDate];
        }

        if ([b respondsToSelector:@selector(installDate)]) {
            dateB = [b installDate];
        }

        if (!dateA && !dateB) return NSOrderedSame;
        if (!dateA) return NSOrderedDescending;
        if (!dateB) return NSOrderedAscending;

        return [dateB compare:dateA];
    }];

    return [sorted subarrayWithRange:
        NSMakeRange(0, MIN(4, sorted.count))];
}

#pragma mark - Category cards

- (void)rebuildContent {
    for (UIView *view in self.contentStack.arrangedSubviews) {
        [self.contentStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }

    NSString *query = self.searchBar.text;

    if (query.length > 0) {
        [self buildSearchResults:query];
        return;
    }

    NSArray *names = [self orderedCategoryNames];

    for (NSInteger index = 0; index < names.count;
         index += self.columnCount) {

        UIStackView *row = [[UIStackView alloc] init];
        row.axis = UILayoutConstraintAxisHorizontal;
        row.spacing = 12;
        row.alignment = UIStackViewAlignmentFill;
        row.distribution = UIStackViewDistributionFillEqually;

        NSInteger end = MIN(index + self.columnCount, names.count);

        for (NSInteger i = index; i < end; i++) {
            [row addArrangedSubview:[self categoryCard:names[i]]];
        }

        for (NSInteger i = end; i < index + self.columnCount; i++) {
            [row addArrangedSubview:[[UIView alloc] init]];
        }

        [self.contentStack addArrangedSubview:row];
    }
}

- (UIView *)categoryCard:(NSString *)category {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.13];
    card.layer.cornerRadius = 22;
    card.clipsToBounds = YES;

    UILabel *title = [[UILabel alloc] init];
    title.text = category;
    title.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    title.textColor = UIColor.whiteColor;
    title.translatesAutoresizingMaskIntoConstraints = NO;

    [card addSubview:title];

    UIStackView *icons = [[UIStackView alloc] init];
    icons.axis = UILayoutConstraintAxisVertical;
    icons.spacing = 7;
    icons.distribution = UIStackViewDistributionFillEqually;
    icons.translatesAutoresizingMaskIntoConstraints = NO;

    [card addSubview:icons];

    NSArray *apps = [self applicationsForCategory:category];

    for (NSInteger rowIndex = 0; rowIndex < 2; rowIndex++) {
        UIStackView *iconRow = [[UIStackView alloc] init];
        iconRow.axis = UILayoutConstraintAxisHorizontal;
        iconRow.spacing = 5;
        iconRow.distribution = UIStackViewDistributionFillEqually;

        for (NSInteger column = 0; column < 2; column++) {
            NSInteger appIndex = rowIndex * 2 + column;

            if (appIndex < apps.count) {
                [iconRow addArrangedSubview:
                    [self appIconButton:apps[appIndex]]];
            } else {
                [iconRow addArrangedSubview:[[UIView alloc] init]];
            }
        }

        [icons addArrangedSubview:iconRow];
    }

    UIButton *moreButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [moreButton setTitle:@"•••" forState:UIControlStateNormal];
    [moreButton setTitleColor:
        [UIColor colorWithWhite:1.0 alpha:0.75]
                       forState:UIControlStateNormal];
    moreButton.titleLabel.font =
        [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    moreButton.translatesAutoresizingMaskIntoConstraints = NO;

    objc_setAssociatedObject(
        moreButton,
        &AppLibrary12ApplicationKey,
        category,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );

    [moreButton addTarget:self
                   action:@selector(openCategory:)
         forControlEvents:UIControlEventTouchUpInside];

    [card addSubview:moreButton];

    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:card.topAnchor constant:12],
        [title.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:12],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:moreButton.leadingAnchor constant:-4],

        [moreButton.topAnchor constraintEqualToAnchor:card.topAnchor constant:5],
        [moreButton.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-7],
        [moreButton.widthAnchor constraintEqualToConstant:32],
        [moreButton.heightAnchor constraintEqualToConstant:28],

        [icons.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:9],
        [icons.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:10],
        [icons.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-10],
        [icons.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-10],

        [card.heightAnchor constraintEqualToConstant:145]
    ]];

    return card;
}

#pragma mark - App icons

- (UIButton *)appIconButton:(LSApplicationProxy *)application {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];

    button.backgroundColor = UIColor.clearColor;
    button.imageView.contentMode = UIViewContentModeScaleAspectFit;
    button.imageView.layer.cornerRadius = 11;
    button.imageView.clipsToBounds = YES;

    NSData *iconData = nil;

    if ([application respondsToSelector:@selector(iconDataForVariant:)]) {
        iconData = [application iconDataForVariant:0];
    }

    UIImage *icon = iconData ? [UIImage imageWithData:iconData] : nil;

    if (!icon) {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(52, 52), NO, 0);

        [[UIColor colorWithWhite:0.35 alpha:1.0] setFill];

        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 52, 52)
                                     cornerRadius:11] fill];

        NSString *letter =
            [[application localizedName] substringToIndex:1];

        NSDictionary *attributes = @{
            NSFontAttributeName:
                [UIFont systemFontOfSize:25 weight:UIFontWeightBold],
            NSForegroundColorAttributeName: UIColor.whiteColor
        };

        CGSize size = [letter sizeWithAttributes:attributes];

        [letter drawAtPoint:CGPointMake(
            (52 - size.width) / 2,
            (52 - size.height) / 2
        ) withAttributes:attributes];

        icon = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }

    [button setImage:icon forState:UIControlStateNormal];

    objc_setAssociatedObject(
        button,
        &AppLibrary12ApplicationKey,
        application,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );

    [button addTarget:self
               action:@selector(launchApplication:)
     forControlEvents:UIControlEventTouchUpInside];

    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button.heightAnchor constraintEqualToConstant:49].active = YES;

    return button;
}

#pragma mark - Search

- (void)searchBar:(UISearchBar *)searchBar
    textDidChange:(NSString *)searchText {

    if (searchText.length == 0) {
        self.filteredApplications = self.applications;
    } else {
        NSPredicate *predicate =
            [NSPredicate predicateWithBlock:^BOOL(
                LSApplicationProxy *application,
                NSDictionary *bindings
            ) {
                NSString *name = [application localizedName] ?: @"";
                NSString *bundleID =
                    [application applicationIdentifier] ?: @"";

                return [name rangeOfString:searchText
                                   options:NSCaseInsensitiveSearch].location != NSNotFound ||
                       [bundleID rangeOfString:searchText
                                       options:NSCaseInsensitiveSearch].location != NSNotFound;
            }];

        self.filteredApplications =
            [self.applications filteredArrayUsingPredicate:predicate];
    }

    [self rebuildContent];
}

- (void)buildSearchResults:(NSString *)query {
    UILabel *heading = [[UILabel alloc] init];
    heading.text = @"Search Results";
    heading.font = [UIFont systemFontOfSize:21 weight:UIFontWeightBold];
    heading.textColor = UIColor.whiteColor;

    [self.contentStack addArrangedSubview:heading];

    UIStackView *row = nil;

    for (NSInteger i = 0; i < self.filteredApplications.count; i++) {
        if (i % self.columnCount == 0) {
            row = [[UIStackView alloc] init];
            row.axis = UILayoutConstraintAxisHorizontal;
            row.spacing = 12;
            row.distribution = UIStackViewDistributionFillEqually;

            [self.contentStack addArrangedSubview:row];
        }

        LSApplicationProxy *application = self.filteredApplications[i];

        UIView *item = [[UIView alloc] init];

        UIStackView *itemStack = [[UIStackView alloc] init];
        itemStack.axis = UILayoutConstraintAxisVertical;
        itemStack.alignment = UIStackViewAlignmentCenter;
        itemStack.spacing = 5;
        itemStack.translatesAutoresizingMaskIntoConstraints = NO;

        UIButton *icon = [self appIconButton:application];

        UILabel *name = [[UILabel alloc] init];
        name.text = [application localizedName];
        name.textColor = UIColor.whiteColor;
        name.font = [UIFont systemFontOfSize:12];
        name.textAlignment = NSTextAlignmentCenter;
        name.numberOfLines = 1;

        [itemStack addArrangedSubview:icon];
        [itemStack addArrangedSubview:name];

        [item addSubview:itemStack];

        [NSLayoutConstraint activateConstraints:@[
            [itemStack.topAnchor constraintEqualToAnchor:item.topAnchor constant:8],
            [itemStack.bottomAnchor constraintEqualToAnchor:item.bottomAnchor constant:-8],
            [itemStack.centerXAnchor constraintEqualToAnchor:item.centerXAnchor],
            [itemStack.leadingAnchor constraintGreaterThanOrEqualToAnchor:item.leadingAnchor],
            [itemStack.trailingAnchor constraintLessThanOrEqualToAnchor:item.trailingAnchor]
        ]];

        [row addArrangedSubview:item];
    }

    if (self.filteredApplications.count == 0) {
        UILabel *empty = [[UILabel alloc] init];
        empty.text = @"No Apps Found";
        empty.textColor = [UIColor colorWithWhite:1.0 alpha:0.65];
        empty.font = [UIFont systemFontOfSize:16];
        empty.textAlignment = NSTextAlignmentCenter;

        [self.contentStack addArrangedSubview:empty];
    }

    if (row && self.filteredApplications.count % self.columnCount != 0) {
        while (row.arrangedSubviews.count < self.columnCount) {
            [row addArrangedSubview:[[UIView alloc] init]];
        }
    }
}

#pragma mark - Actions

- (void)launchApplication:(UIButton *)button {
    LSApplicationProxy *application =
        objc_getAssociatedObject(button, &AppLibrary12ApplicationKey);

    if (!application) return;

    NSString *bundleID = [application applicationIdentifier];

    if (!bundleID.length) return;

    id workspace = AppLibrary12GetWorkspace();

    SEL selector =
        NSSelectorFromString(@"openApplicationWithBundleID:");

    if (workspace && [workspace respondsToSelector:selector]) {
        ((BOOL (*)(id, SEL, id))objc_msgSend)(
            workspace,
            selector,
            bundleID
        );

        [self closeLibrary];
    }
}

- (void)openCategory:(UIButton *)button {
    NSString *category =
        objc_getAssociatedObject(button, &AppLibrary12ApplicationKey);

    if (!category.length) return;

    NSArray *applications = [self applicationsForCategory:category];

    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:category
                                            message:nil
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    for (LSApplicationProxy *application in applications) {
        NSString *name = [application localizedName];

        [alert addAction:
            [UIAlertAction actionWithTitle:name
                                     style:UIAlertActionStyleDefault
                                   handler:^(__unused UIAlertAction *action) {
            NSString *bundleID = [application applicationIdentifier];

            id workspace = AppLibrary12GetWorkspace();

            SEL selector =
                NSSelectorFromString(@"openApplicationWithBundleID:");

            if (workspace && [workspace respondsToSelector:selector]) {
                ((BOOL (*)(id, SEL, id))objc_msgSend)(
                    workspace,
                    selector,
                    bundleID
                );

                [self closeLibrary];
            }
        }]];
    }

    [alert addAction:
        [UIAlertAction actionWithTitle:@"Cancel"
                                 style:UIAlertActionStyleCancel
                               handler:nil]];

    UIPopoverPresentationController *popover =
        alert.popoverPresentationController;

    if (popover) {
        popover.sourceView = button;
        popover.sourceRect = button.bounds;
    }

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)closeLibrary {
    self.view.window.hidden = YES;
}

- (BOOL)prefersStatusBarHidden {
    return NO;
}

@end
