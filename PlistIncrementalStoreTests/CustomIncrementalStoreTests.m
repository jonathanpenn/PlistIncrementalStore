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
    XCTAssertEqual((int)[contents count], 0, @"Expecting empty contents at start");
}

- (void)testAddingAFileShowsUpInList {
    [self generateJournalEntryFileWithContent:@"Hello world"];
    NSArray *entries = [self.coreData dumpContents];
    XCTAssertEqual((int)[entries count], 1, @"Expecting one file");
    NSString *content = [entries[0] content];
    NSRange foundRange = [content rangeOfString:@"Hello world"];

    XCTAssertTrue(foundRange.location != NSNotFound, @"Could not find Hello world in %@", content);
}

- (void)testCountResultType {
    // generate a few journal entries
    [self generateJournalEntryFileWithContent:@"Entry 1"];
    [self generateJournalEntryFileWithContent:@"Entry 2"];
    [self generateJournalEntryFileWithContent:@"Entry 3"];
    [self generateJournalEntryFileWithContent:@"Entry 4"];
    // execute a fetch request to count them
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"JournalEntry"];
    fetchRequest.resultType = NSCountResultType;
    NSError *error;
    NSArray *countArray = [self.coreData.context executeFetchRequest:fetchRequest error:&error];
    XCTAssertNotNil(countArray, @"Could not retrieve count: %@", error);
    NSNumber *count = [countArray firstObject];
    XCTAssertEqualObjects(count, @4, @"Count should be 4");
}

- (void)testCountWithPredicate {
    // generate a few journal entries
    [self generateJournalEntryFileWithContent:@"An Entry 1"];
    [self generateJournalEntryFileWithContent:@"Not an Entry 2"];
    [self generateJournalEntryFileWithContent:@"An Entry 3"];
    [self generateJournalEntryFileWithContent:@"Another Entry 4"];
    // execute a fetch request to count them
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"JournalEntry"];
    fetchRequest.resultType = NSCountResultType;
    // add a predicate to match things starting with 'a'
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"content beginswith[c] 'a'"];
    NSError *error;
    NSArray *countArray = [self.coreData.context executeFetchRequest:fetchRequest error:&error];
    XCTAssertNotNil(countArray, @"Could not retrieve count: %@", error);
    NSNumber *count = [countArray firstObject];
    XCTAssertEqualObjects(count, @3, @"Count should be 3");
}

- (void)testCountWithNonMatchingPredicate {
    // generate a few journal entries
    [self generateJournalEntryFileWithContent:@"An Entry 1"];
    [self generateJournalEntryFileWithContent:@"Not an Entry 2"];
    [self generateJournalEntryFileWithContent:@"An Entry 3"];
    [self generateJournalEntryFileWithContent:@"Another Entry 4"];
    // execute a fetch request to count them
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"JournalEntry"];
    fetchRequest.resultType = NSCountResultType;
    // add a predicate to match things starting with 'x'
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"content beginswith[c] 'x'"];
    NSError *error;
    NSArray *countArray = [self.coreData.context executeFetchRequest:fetchRequest error:&error];
    XCTAssertNotNil(countArray, @"Could not retrieve count: %@", error);
    NSNumber *count = [countArray firstObject];
    XCTAssertEqualObjects(count, @0, @"Count should be 0");
}

- (void)testUpdatingAFileAndRefreshingObjectSeesChanges {
    NSURL *entryURL = [self generateJournalEntryFileWithContent:@"Hello world"];
    JournalEntry *entry = [self.coreData dumpContents][0];

    XCTAssertEqualObjects(entry.content, @"Hello world", @"Expected starting content: %@", entry.content);

    [self updateContent:@"Another" atURL:entryURL];

    XCTAssertEqualObjects(entry.content, @"Hello world", @"Before refresh, expected same content: %@", entry.content);
    
    [self.coreData.context refreshObject:entry mergeChanges:YES];

    XCTAssertEqualObjects(entry.content, @"Another", @"Expected reloaded content: %@", entry.content);
}

- (void)testUpdatingAFileAndThenTryingToWriteADirtyEntry {
    NSError *error = nil;
    NSURL *entryURL = [self generateJournalEntryFileWithContent:@"Hello world"];
    JournalEntry *entry = [self.coreData dumpContents][0];

    XCTAssertEqualObjects(entry.content, @"Hello world", @"Expected starting content: %@", entry.content);

    [self updateContent:@"Another" atURL:entryURL];

    entry.content = @"Smush";
    XCTAssertTrue([self.coreData save:&error], @"Could not save document %@", error);

    [self.coreData.context refreshObject:entry mergeChanges:YES];

    XCTAssertEqualObjects(entry.content, @"Smush", @"Expected original file content content: %@", entry.content);
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

    XCTAssertEqual(notificationCount, 2, @"Supposed to notify twice: %d", notificationCount);

    NSArray *entries = [self.coreData dumpContents];

    XCTAssertEqualObjects(((JournalEntry *)entries[0]).content, @"Ping another!");
    XCTAssertEqualObjects(((JournalEntry *)entries[1]).content, @"Ping me!");

    [[NSNotificationCenter defaultCenter] removeObserver:observer];
}


@end
