#import <SenTestingKit/SenTestingKit.h>
#import "PlistStoreFileItem.h"
#import "PlistStoreFileWatcher.h"

@interface PlistStorageItemTests : SenTestCase
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

    STAssertEqualObjects(self.fileURL, item.URL, nil);
    STAssertEqualObjects(@"storageidentifier", item.storageIdentifier, nil);
}

- (void)testSetsURLAndStorageIdentifierFromStorageIdentifier {
    PlistStoreFileWatcher *watcher = [[PlistStoreFileWatcher alloc] initWithURL:self.rootURL];
    PlistStoreFileItem *item = [PlistStoreFileItem itemForStorageIdentifier:@"storageidentifier" inStoreFileWatcher:watcher];

    STAssertEqualObjects(self.fileURL, item.URL, nil);
    STAssertEqualObjects(@"storageidentifier", item.storageIdentifier, nil);
}

- (void)testWritingAndLoadingFromDisk {
    NSError *error = nil;
    PlistStoreFileItem *item = [PlistStoreFileItem itemForURL:self.fileURL withStoreFileWatcher:nil];

    char str[] = "data";
    item.content = [NSData dataWithBytes:str length:strlen(str)];

    STAssertTrue([item writeContent:&error], @"%@\n%@", error.localizedDescription, error);

    item = [PlistStoreFileItem itemForURL:self.fileURL withStoreFileWatcher:nil];

    STAssertFalse(item.contentIsLoaded, nil);
    STAssertTrue([item loadContent:&error], @"%@\n%@", error.localizedDescription, error);
    STAssertTrue(item.contentIsLoaded, nil);

    STAssertEqualObjects([NSData dataWithBytes:str length:strlen(str)], item.content, nil);
}


@end