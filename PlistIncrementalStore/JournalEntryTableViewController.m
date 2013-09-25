#import "JournalEntryTableViewController.h"
#import "CoreDataStack.h"
#import "JournalEntry.h"
#import "PlistIncrementalStoreCoder.h"
#import "PlistStoreFileItem.h"
#import "PlistIncrementalStore.h"

@interface JournalEntryTableViewController ()
<UIAlertViewDelegate, UIActionSheetDelegate, NSFetchedResultsControllerDelegate>

@property (nonatomic, strong) CoreDataStack *coreData;
@property (nonatomic, strong) UISegmentedControl *sortControl;
@property (nonatomic, strong) UISegmentedControl *predicateControl;
@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;

@end


@implementation JournalEntryTableViewController {
    NSDateFormatter *_dateFormatter;
    NSInteger _workerCount;
}

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setUpDateFormatter];
    [self setUpToolbarControls];
    [self setUpRefreshControl];

    self.coreData = [[CoreDataStack alloc] init];
    [self.coreData setup];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateTitle];
}


#pragma Fetched Results Controller Stuff

/// Lazy property to instantiate and perform the first fetch of a fetched results controller.
- (NSFetchedResultsController *)fetchedResultsController {
    if (_fetchedResultsController != nil) return _fetchedResultsController;

    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"JournalEntry"];
    [fetchRequest setSortDescriptors:[self sortDescriptorsForSelectedCriteria]];
    [fetchRequest setPredicate:[self predicateForSelectedCriteria]];

    _fetchedResultsController =
        [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                            managedObjectContext:self.coreData.context
                                              sectionNameKeyPath:nil
                                                       cacheName:nil];
    _fetchedResultsController.delegate = self;

    NSError *error = nil;
    if (![_fetchedResultsController performFetch:&error]) {
        NSLog(@"Error performing fetch: %@, %@", error, [error userInfo]);
    }

    return _fetchedResultsController;
}

/// Resets the fetched results controller by setting the property to nil. The next time the fetchedResultsController property is accessed by one of the table view callbacks, a new controller will be built and perform a fetch for a fresh set of data.
- (void)resetFetchedResultsController {
    _fetchedResultsController.delegate = nil;
    _fetchedResultsController = nil;
}

/// Builds an array of sort descriptors based on the state of the segmented control in the toolbar.
- (NSArray *)sortDescriptorsForSelectedCriteria {
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"timestamp"
                                                           ascending:self.sortControl.selectedSegmentIndex == 0];
    return @[sort];
}

/// Builds an NSPredicate based on the state of the segmented control in the toolbar.
- (NSPredicate *)predicateForSelectedCriteria {
    if (self.predicateControl.selectedSegmentIndex == 0) {
        return nil;
    } else {
        return [NSPredicate predicateWithFormat:@"content beginswith 'a'"];
    }
}


#pragma mark - Actions

- (void)refreshControlTriggered:(id)sender {
    _fetchedResultsController = nil;
    [self.tableView reloadData];
    [self.refreshControl endRefreshing];
    [self updateTitle];
}


- (IBAction)navBarActionButtonPressed:(id)sender {
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Actions" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Create tons of plist files" otherButtonTitles:@"Clear plist directory", nil];
    [sheet showInView:self.view.window];
}

/// Handles the action sheet triggered by the button in the nav bar.
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    switch (buttonIndex) {
        case 0:
            [self createPlistFilesBehindTheScenes];
            break;
        case 1:
            [self clearPlistDirectory];
            break;
        default:
            break;
    }
}

/// Generates dummy journal entries by creating the raw plist files in the data directory. The plist store will notice this and pull them into the core data stack used by the fetched results controller. This will populate the table view.
- (void)createPlistFilesBehindTheScenes {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("net.cocoamanifest.behind-the-queue", DISPATCH_QUEUE_CONCURRENT);
    });

    PlistIncrementalStore *store = (PlistIncrementalStore *)self.coreData.coordinator.persistentStores[0];
    PlistStoreFileWatcher *fileWatcher = store.storeFileWatcher;
    PlistIncrementalStoreCoder *coder = store.entityCoder;

    for (int i = 0; i < 1000; i++) {
        double delayInSeconds = arc4random_uniform(4);
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, queue, ^(void){
            dispatch_async(dispatch_get_main_queue(), ^{ _workerCount++; });

            NSString *uuid = [[NSProcessInfo processInfo] globallyUniqueString];
            NSDate *date = [NSDate dateWithTimeIntervalSinceNow:0-arc4random_uniform(800000)/1000.f];
            NSDictionary *data = @{@"timestamp": date, @"content": uuid};
            NSData *encoded = [coder encodeObject:data forEntity:[NSEntityDescription entityForName:@"JournalEntry" inManagedObjectContext:self.coreData.context] error:nil];
            NSString *identifier = [NSString stringWithFormat:@"JournalEntry;%@", uuid];
            PlistStoreFileItem *item = [PlistStoreFileItem itemForStorageIdentifier:identifier inStoreFileWatcher:fileWatcher];
            item.content = encoded;
            [item writeContent:nil];

            double delayInSeconds = arc4random_uniform(8) + 3;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [item removeFile:nil];
                dispatch_async(dispatch_get_main_queue(), ^{ _workerCount--; });
            });
        });
    }
}

/// Directly removes every plist file in the data directory. This will cause our custom store to notice which will notify our fetched results controller and clear out our table view.
- (void)clearPlistDirectory {
    NSURL *url = self.coreData.URL;

    static dispatch_queue_t clearQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        clearQueue = dispatch_queue_create("clear.queue", DISPATCH_QUEUE_CONCURRENT);
    });

    dispatch_async(clearQueue, ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];

        NSEnumerator *enumerator = [fileManager enumeratorAtURL:url
                                     includingPropertiesForKeys:nil
                                                        options:NSDirectoryEnumerationSkipsHiddenFiles
                                                   errorHandler:nil];
        for (NSURL *fileURL in enumerator) {
            [fileManager removeItemAtURL:fileURL error:nil];
        }
    });
}

- (IBAction)navBarAddButtonPressed {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"New Entry" message:nil delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Save", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alert show];
}

/// Alert view handler that will either create a new or edit the selected journal entry, depending on the alert title.
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {

    if (buttonIndex >= 0) {
        NSString *message = [alertView textFieldAtIndex:0].text;

        JournalEntry *entry = nil;

        if ([alertView.title isEqualToString:@"New Entry"]) {
            entry = [self.coreData insertEntry];
        } else {
            entry = [self.fetchedResultsController objectAtIndexPath:[self.tableView indexPathForSelectedRow]];
        }

        entry.content = message;

        NSError *error = nil;
        if (![self.coreData save:&error]) {
            NSLog(@"Could not save new message %@, %@", error, [error userInfo]);
        }
    }

    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
}


#pragma mark - UITableViewDataSource

// Standard Table View Data Source callbacks that feed the table view with the information it needs from the NSFetchedResultsController

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {

    NSArray *sections = [self.fetchedResultsController sections];
    if ([sections count] == 0) return 0;
    id <NSFetchedResultsSectionInfo> sectionInfo = sections[section];
    return [sectionInfo numberOfObjects];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    
    NSArray *sections = [self.fetchedResultsController sections];
    id <NSFetchedResultsSectionInfo> sectionInfo = sections[section];
    return sectionInfo.name;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    
    return index;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    JournalEntry *entry = [self.fetchedResultsController objectAtIndexPath:indexPath];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Edit Entry"
                                                    message:nil
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"Save", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alert textFieldAtIndex:0].text = entry.content;
    [alert show];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {

    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:path];

    JournalEntry *entry = [self.fetchedResultsController objectAtIndexPath:path];

    cell.textLabel.font = [UIFont systemFontOfSize:15];
    cell.textLabel.text = entry.content;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
    cell.detailTextLabel.text = [_dateFormatter stringFromDate:entry.timestamp];
    [cell layoutSubviews];

    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSManagedObject *objectToDelete = [self.fetchedResultsController objectAtIndexPath:indexPath];
        [self.coreData.context deleteObject:objectToDelete];

        NSError* error = nil;
        if (![self.coreData save:&error]) {
            NSLog(@"Unable to remove object: %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleDelete;
}


#pragma mark - NSFetchedResultsController Boilerplate Handlers

// These are boilerplate NSFetchedResultsController handlers pulled right out of Apple's best practices. The fetched results controller watches for any changes to objects matched by the fetch request and calls us back here so we can pass those changed index paths on to the table view to change the cells.

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller
  didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {

    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                          withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                          withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {

    UITableView *tableView = self.tableView;

    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeUpdate:
            [tableView reloadRowsAtIndexPaths:@[indexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:@[indexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:@[newIndexPath]
                             withRowAnimation:UITableViewRowAnimationBottom];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView endUpdates];
    [self updateTitle];
}



#pragma mark - Utility Methods

- (void)setUpDateFormatter {
    _dateFormatter = [[NSDateFormatter alloc] init];
    [_dateFormatter setDateStyle:NSDateFormatterShortStyle];
    [_dateFormatter setTimeStyle:NSDateFormatterLongStyle];
}

/// Adds a pull-to-refresh control to the table view
- (void)setUpRefreshControl {
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self
                       action:@selector(refreshControlTriggered:)
             forControlEvents:UIControlEventAllEvents];
    self.refreshControl = refreshControl;
}

/// Updates the nav bar title to show the number of entries currently in the table view
- (void)updateTitle {
    NSString *title = [NSString stringWithFormat:@"Entries (%d)",
                       [self tableView:nil numberOfRowsInSection:0]];
    self.title = title;
}

/// Creates the toolbar controls
- (void)setUpToolbarControls {
    UIBarButtonItem *spacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];

    self.sortControl = [[UISegmentedControl alloc] initWithItems:@[@" ▲   ", @" ▼   "]];
    self.sortControl.selectedSegmentIndex = 1;
    [self.sortControl addTarget:self action:@selector(criteriaDidChanged) forControlEvents:UIControlEventAllEvents];

    self.predicateControl = [[UISegmentedControl alloc] initWithItems:@[@"All", @"Starts With 'a'"]];
    self.predicateControl.selectedSegmentIndex = 0;
    [self.predicateControl addTarget:self action:@selector(criteriaDidChanged) forControlEvents:UIControlEventAllEvents];

    [self setToolbarItems:@[
     [[UIBarButtonItem alloc] initWithCustomView:self.sortControl],
     spacer,
     [[UIBarButtonItem alloc] initWithCustomView:self.predicateControl]
     ]];
}

/// Triggered by both toolbar segmented controls. Blows away the fetched results controller and builds a new one.
- (void)criteriaDidChanged {
    [self resetFetchedResultsController];
    [self.tableView reloadData];
    [self updateTitle];

    return;
}

@end
