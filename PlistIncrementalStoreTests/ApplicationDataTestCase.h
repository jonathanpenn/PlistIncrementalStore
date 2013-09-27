#import <XCTest/XCTest.h>
#import "CoreDataStack.h"
#import "PlistIncrementalStore.h"
#import "JournalEntry.h"

#define PAUSE(seconds) [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:(seconds)]]

@interface ApplicationDataTestCase : XCTestCase

@property (nonatomic, copy) NSURL *tempURL;
@property (nonatomic, strong) CoreDataStack *coreData;


- (void)clearOutAndCreateDirectory;
- (NSURL *)generateJournalEntryFileWithContent:(NSString *)content;
- (void)updateContent:(NSString *)content atURL:(NSURL *)fileURL;

@end
