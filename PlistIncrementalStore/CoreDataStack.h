#import <Foundation/Foundation.h>

@class JournalEntry;

@interface CoreDataStack : NSObject

/// Must be called on initialization to set up the Core Data stack.
- (void)setup;

/// Sets the Core Data properties to nil. Must call -setup to build a new stack.
- (void)reset;

/// Convenience method to save with performBlockAndWait: on the context.
- (BOOL)save:(NSError **)error;

/// Quick and dirty journal entry creation.
- (JournalEntry *)insertEntry;

@property (nonatomic, strong) NSManagedObjectContext *context;
@property (nonatomic, strong) NSPersistentStoreCoordinator *coordinator;
@property (nonatomic, strong) NSManagedObjectModel *model;

@property (nonatomic, readonly) NSURL *URL;

/// Handy debugging method that just dumps an array of all the journal entry objects.
- (NSArray *)dumpContents;

@end
