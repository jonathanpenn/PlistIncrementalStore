#import "ApplicationDataTestCase.h"
#import "PlistIncrementalStoreCoder.h"

@implementation ApplicationDataTestCase

#pragma mark - Helper Methods

- (CoreDataStack *)coreData
{
    if (!_coreData) {
        _coreData = [[CoreDataStack alloc] init];
        [_coreData setup];
    }
    return _coreData;
}

- (void)clearOutAndCreateDirectory
{
    NSURL *url = self.coreData.URL;
    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSEnumerator *enumerator = [fileManager enumeratorAtURL:url includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:nil];
    for (NSURL *fileURL in enumerator) {
        [fileManager removeItemAtURL:fileURL error:nil];
    }
}

- (NSURL *)generateJournalEntryFileWithContent:(NSString *)content
{
    NSURL *base = self.coreData.URL;
    NSString *name = [NSString stringWithFormat:@"JournalEntry;%@.txt", [[NSProcessInfo processInfo] globallyUniqueString]];
    NSURL *fileURL = [base URLByAppendingPathComponent:name];

    [self updateContent:content atURL:fileURL];

    return fileURL;
}

- (void)updateContent:(NSString *)content atURL:(NSURL *)fileURL
{
    NSError *error = nil;
    NSDictionary *dict = @{@"content": content, @"timestamp": [NSDate date]};
    PlistIncrementalStoreCoder *coder = [[PlistIncrementalStoreCoder alloc] init];
    NSData *data = [coder encodeObject:dict forEntity:[NSEntityDescription entityForName:@"JournalEntry" inManagedObjectContext:self.coreData.context] error:nil];

    XCTAssertNotNil(data, @"Unable to reserialize plist file, %@, %@, %@", fileURL, error, error.userInfo);

    XCTAssertTrue([data writeToURL:fileURL options:NSDataWritingAtomic error:nil],
                 @"Could not generate journal entry to %@: %@, %@", fileURL, error, error.userInfo);
}

@end
