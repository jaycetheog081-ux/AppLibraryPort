#import "AppLibrary12ViewController.h"
#import <objc/message.h>
#import <objc/runtime.h>

@interface LSApplicationProxy : NSObject
- (NSString *)localizedName;
- (NSString *)applicationIdentifier;
@end

static id AppLibrary12GetWorkspace(void) {
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if (!workspaceClass) {
        return nil;
    }

    SEL selector = NSSelectorFromString(@"defaultWorkspace");
    if (![workspaceClass respondsToSelector:selector]) {
        return nil;
    }

    return ((id (*)(id, SEL))objc_msgSend)(workspaceClass, selector);
}

@interface AppLibrary12ViewController () <
    UITableViewDataSource,
    UITableViewDelegate,
    UISearchBarDelegate
>

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIButton *closeButton;

@property (nonatomic, strong) NSArray<LSApplicationProxy *> *applications;
@property (nonatomic, strong) NSArray<LSApplicationProxy *> *filteredApplications;

@end

@implementation AppLibrary12ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.applications = @[];
    self.filteredApplications = @[];

    [self buildInterface];
    [self loadApplications];
}

- (void)buildInterface {
    self.view.backgroundColor = [UIColor colorWithWhite:0.04 alpha:0.97];

    UIBlurEffect *blur =
        [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];

    UIVisualEffectView *blurView =
        [[UIVisualEffectView alloc] initWithEffect:blur];

    blurView.frame = self.view.bounds;
    blurView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    [self.view addSubview:blurView];

    UIView *content = blurView.contentView;

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = @"App Library";
    self.titleLabel.font =
        [UIFont systemFontOfSize:34 weight:UIFontWeightBold];
    self.titleLabel.textColor = UIColor.whiteColor;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:self.titleLabel];

    self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.closeButton setTitle:@"Done" forState:UIControlStateNormal];
    self.closeButton.titleLabel.font =
        [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
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
    self.searchBar.delegate = self;
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:self.searchBar];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero
                                                  style:UITableViewStylePlain];
    self.tableView.backgroundColor = UIColor.clearColor;
    self.tableView.separatorColor =
        [UIColor colorWithWhite:1.0 alpha:0.12];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.keyboardDismissMode =
        UIScrollViewKeyboardDismissModeOnDrag;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;

    [self.tableView registerClass:UITableViewCell.class
           forCellReuseIdentifier:@"ApplicationCell"];

    [content addSubview:self.tableView];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;

    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.topAnchor constraintEqualToAnchor:safe.topAnchor
                                                  constant:18],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor
                                                       constant:22],

        [self.closeButton.centerYAnchor
            constraintEqualToAnchor:self.titleLabel.centerYAnchor],
        [self.closeButton.trailingAnchor
            constraintEqualToAnchor:safe.trailingAnchor constant:-22],

        [self.searchBar.topAnchor
            constraintEqualToAnchor:self.titleLabel.bottomAnchor
                           constant:14],
        [self.searchBar.leadingAnchor
            constraintEqualToAnchor:safe.leadingAnchor constant:12],
        [self.searchBar.trailingAnchor
            constraintEqualToAnchor:safe.trailingAnchor constant:-12],

        [self.tableView.topAnchor
            constraintEqualToAnchor:self.searchBar.bottomAnchor
                           constant:8],
        [self.tableView.leadingAnchor
            constraintEqualToAnchor:safe.leadingAnchor],
        [self.tableView.trailingAnchor
            constraintEqualToAnchor:safe.trailingAnchor],
        [self.tableView.bottomAnchor
            constraintEqualToAnchor:safe.bottomAnchor]
    ]];
}

- (void)loadApplications {
    id workspace = AppLibrary12GetWorkspace();

    if (!workspace) {
        self.applications = @[];
        self.filteredApplications = @[];
        [self.tableView reloadData];
        return;
    }

    SEL installedSelector =
        NSSelectorFromString(@"allInstalledApplications");

    if (![workspace respondsToSelector:installedSelector]) {
        return;
    }

    NSArray *installed =
        ((id (*)(id, SEL))objc_msgSend)(workspace, installedSelector);

    if (![installed isKindOfClass:NSArray.class]) {
        installed = @[];
    }

    NSMutableArray *validApplications = [NSMutableArray array];

    for (id application in installed) {
        if (![application respondsToSelector:@selector(localizedName)] ||
            ![application respondsToSelector:@selector(applicationIdentifier)]) {
            continue;
        }

        NSString *name = [application localizedName];
        NSString *bundleID = [application applicationIdentifier];

        if (name.length && bundleID.length) {
            [validApplications addObject:application];
        }
    }

    [validApplications sortUsingComparator:^NSComparisonResult(
        LSApplicationProxy *a,
        LSApplicationProxy *b
    ) {
        return [[a localizedName] localizedCaseInsensitiveCompare:
                [b localizedName]];
    }];

    self.applications = validApplications;
    self.filteredApplications = validApplications;

    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
    return self.filteredApplications.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:@"ApplicationCell"
                                        forIndexPath:indexPath];

    LSApplicationProxy *application =
        self.filteredApplications[indexPath.row];

    cell.textLabel.text = [application localizedName];
    cell.textLabel.textColor = UIColor.whiteColor;
    cell.backgroundColor = UIColor.clearColor;
    cell.contentView.backgroundColor = UIColor.clearColor;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    return cell;
}

- (void)tableView:(UITableView *)tableView
 didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    LSApplicationProxy *application =
        self.filteredApplications[indexPath.row];

    NSString *bundleID = [application applicationIdentifier];

    if (!bundleID.length) {
        return;
    }

    id workspace = AppLibrary12GetWorkspace();
    SEL openSelector =
        NSSelectorFromString(@"openApplicationWithBundleID:");

    if (workspace && [workspace respondsToSelector:openSelector]) {
        ((BOOL (*)(id, SEL, id))objc_msgSend)(
            workspace,
            openSelector,
            bundleID
        );

        [self closeLibrary];
    }
}

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
                return [[application localizedName]
                    rangeOfString:searchText
                          options:NSCaseInsensitiveSearch].location != NSNotFound;
            }];

        self.filteredApplications =
            [self.applications filteredArrayUsingPredicate:predicate];
    }

    [self.tableView reloadData];
}

- (void)closeLibrary {
    self.view.window.hidden = YES;
}

- (BOOL)prefersStatusBarHidden {
    return NO;
}

@end
