#import "CoreDataStack.h"
#import "PlistIncrementalStore.h"
#import "JournalEntry.h"

@implementation CoreDataStack

@synthesize URL=_URL;

- (instancetype)initWithURL:(NSURL *)url {
    self = [super init];
    if (self) {
        _URL = url;
    }
    return self;
}

- (JournalEntry *)insertEntry {
    JournalEntry *entry = [NSEntityDescription insertNewObjectForEntityForName:@"JournalEntry"
                                                        inManagedObjectContext:self.context];
    entry.timestamp = [NSDate date];
    return entry;
}

- (BOOL)save:(NSError **)error {
    __block BOOL success = NO;
    [self.context performBlockAndWait:^{
        success = [self.context save:error];
    }];

    return success;
}

- (NSURL *)URL {
    if (_URL) return _URL;

    NSURL *documentsURL = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask][0];
    _URL = [documentsURL URLByAppendingPathComponent:@"Journal"];
    return _URL;
}

- (NSArray *)dumpContents {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"JournalEntry"];

    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO];
    fetchRequest.sortDescriptors = @[sort];

    NSError *error = nil;

    NSArray *results = [self.context executeFetchRequest:fetchRequest error:&error];

    if (!results) {
        NSLog(@"Could not dump contents: %@, %@", error, error.userInfo);
    }

    return results;
}


#pragma mark - Setup

- (void)reset {
    self.model = nil;
    self.context = nil;
    self.coordinator = nil;
}

- (void)setup {
    NSError *error = nil;

    [self reset];

    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"DataModel" withExtension:@"momd"];
    self.model = [NSManagedObjectModel mergedModelFromBundles:nil];

    NSAssert(self.model != nil, @"Model not found at path %@", modelURL.path);

    [NSPersistentStoreCoordinator registerStoreClass:[PlistIncrementalStore class]
                                        forStoreType:PlistIncrementalStoreType];

    self.coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.model];
    NSDictionary *options = @{PlistIncrementalStoreConfigureDebugEnabled: @YES};
//    NSDictionary *options = nil;
    if (![self.coordinator addPersistentStoreWithType:PlistIncrementalStoreType
                                        configuration:nil
                                                  URL:self.URL
                                              options:options
                                                error:&error]) {

        NSLog(@"Unresolved error %@", error);
        abort();
    }

    self.context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    self.context.persistentStoreCoordinator = self.coordinator;

    self.context.mergePolicy = NSOverwriteMergePolicy;

    PlistIncrementalStore *store = (PlistIncrementalStore *)self.coordinator.persistentStores[0];
    store.contextToNotify = self.context;
}

@end
