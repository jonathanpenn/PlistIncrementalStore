#import "ApplicationDataTestCase.h"

// TODO: rename this to some kind of integration test
@interface CustomIncrementalStoreTests : ApplicationDataTestCase
@end

@implementation CustomIncrementalStoreTests

- (void)setUp {
    [super setUp];
    [self clearOutAndCreateDirectory];
}

- (void)tearDown {
    [super tearDown];
    [self clearOutAndCreateDirectory];
}

- (void)testStartsOutEmpty {
    NSArray *contents = [self.coreData dumpContents];
    STAssertEquals((int)[contents count], 0, @"Expecting empty contents at start");
}

- (void)testAddingAFileShowsUpInList {
    [self generateJournalEntryFileWithContent:@"Hello world"];
    NSArray *entries = [self.coreData dumpContents];
    STAssertEquals((int)[entries count], 1, @"Expecting one file");
    NSString *content = [entries[0] content];
    NSRange foundRange = [content rangeOfString:@"Hello world"];

    STAssertTrue(foundRange.location != NSNotFound, @"Could not find Hello world in %@", content);
}

- (void)testUpdatingAFileAndRefreshingObjectSeesChanges {
    NSURL *entryURL = [self generateJournalEntryFileWithContent:@"Hello world"];
    JournalEntry *entry = [self.coreData dumpContents][0];

    STAssertEqualObjects(entry.content, @"Hello world", @"Expected starting content: %@", entry.content);

    [self updateContent:@"Another" atURL:entryURL];

    STAssertEqualObjects(entry.content, @"Hello world", @"Before refresh, expected same content: %@", entry.content);
    
    [self.coreData.context refreshObject:entry mergeChanges:YES];

    STAssertEqualObjects(entry.content, @"Another", @"Expected reloaded content: %@", entry.content);
}

- (void)testUpdatingAFileAndThenTryingToWriteADirtyEntry {
    NSError *error = nil;
    NSURL *entryURL = [self generateJournalEntryFileWithContent:@"Hello world"];
    JournalEntry *entry = [self.coreData dumpContents][0];

    STAssertEqualObjects(entry.content, @"Hello world", @"Expected starting content: %@", entry.content);

    [self updateContent:@"Another" atURL:entryURL];

    entry.content = @"Smush";
    STAssertTrue([self.coreData save:&error], @"Could not save document %@", error);

    [self.coreData.context refreshObject:entry mergeChanges:YES];

    STAssertEqualObjects(entry.content, @"Smush", @"Expected original file content content: %@", entry.content);
}

- (void)testAddingAFileNotfiesObserver {
    __block int notificationCount = 0;

    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:NSManagedObjectContextObjectsDidChangeNotification object:self.coreData.context queue:nil usingBlock:^(NSNotification *note) {
        notificationCount++;
    }];
    
    [self generateJournalEntryFileWithContent:@"Ping me!"];

    PAUSE(1);

    [self generateJournalEntryFileWithContent:@"Ping another!"];

    PAUSE(3);

    STAssertEquals(notificationCount, 2, @"Supposed to notify twice: %d", notificationCount);

    NSArray *entries = [self.coreData dumpContents];

    STAssertEqualObjects(((JournalEntry *)entries[0]).content, @"Ping another!", nil);
    STAssertEqualObjects(((JournalEntry *)entries[1]).content, @"Ping me!", nil);

    [[NSNotificationCenter defaultCenter] removeObserver:observer];
}


@end
