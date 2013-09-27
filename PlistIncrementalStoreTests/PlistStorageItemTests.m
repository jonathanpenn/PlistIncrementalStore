#import <XCTest/XCTest.h>
#import "PlistStoreFileItem.h"
#import "PlistStoreFileWatcher.h"

@interface PlistStorageItemTests : XCTestCase
@property (nonatomic, copy) NSURL *rootURL, *fileURL;
@end

@implementation PlistStorageItemTests

- (void)setUp {
    [super setUp];

    self.rootURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    self.fileURL = [self.rootURL URLByAppendingPathComponent:@"storageidentifier.txt"];
}

- (void)testSetsURLAndStorageIdentifierFromURL {
    PlistStoreFileItem *item = [PlistStoreFileItem itemForURL:self.fileURL withStoreFileWatcher:nil];

    XCTAssertEqualObjects(self.fileURL, item.URL);
    XCTAssertEqualObjects(@"storageidentifier", item.storageIdentifier);
}

- (void)testSetsURLAndStorageIdentifierFromStorageIdentifier {
    PlistStoreFileWatcher *watcher = [[PlistStoreFileWatcher alloc] initWithURL:self.rootURL];
    PlistStoreFileItem *item = [PlistStoreFileItem itemForStorageIdentifier:@"storageidentifier" inStoreFileWatcher:watcher];

    XCTAssertEqualObjects(self.fileURL, item.URL);
    XCTAssertEqualObjects(@"storageidentifier", item.storageIdentifier);
}

- (void)testWritingAndLoadingFromDisk {
    NSError *error = nil;
    PlistStoreFileItem *item = [PlistStoreFileItem itemForURL:self.fileURL withStoreFileWatcher:nil];

    char str[] = "data";
    item.content = [NSData dataWithBytes:str length:strlen(str)];

    XCTAssertTrue([item writeContent:&error], @"%@\n%@", error.localizedDescription, error);

    item = [PlistStoreFileItem itemForURL:self.fileURL withStoreFileWatcher:nil];

    XCTAssertFalse(item.contentIsLoaded);
    XCTAssertTrue([item loadContent:&error], @"%@\n%@", error.localizedDescription, error);
    XCTAssertTrue(item.contentIsLoaded);

    XCTAssertEqualObjects([NSData dataWithBytes:str length:strlen(str)], item.content);
}


@end