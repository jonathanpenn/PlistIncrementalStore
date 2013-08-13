#import <CoreData/CoreData.h>
#import "PlistIncrementalStoreErrors.h"
#import "PlistStoreFileWatcher.h"

@class PlistIncrementalStoreCoder;

/// The plist file database store type.
extern NSString * const PlistIncrementalStoreType;
extern NSString * const PlistIncrementalStoreConfigureDebugEnabled;

/// The PlistIncrementalStore stores simple managed objects to plist files in a given directory. You don't instantiate this directly yourself. This is registered with the Core Data classes by +registerStore and then you specify the PlistIncrementalStoreType when creating an NSPersistentStoreCoordinator.
/// Note that this does not support objects with relationship properties.
@interface PlistIncrementalStore : NSIncrementalStore <PlistStoreFileWatcherDelegate>

/// Set this property to an NSManagedObjectContext that will be notified when plist files backing managed objects change or disappear from disk.
@property (nonatomic, weak) NSManagedObjectContext *contextToNotify;

/// The "file watcher" that wraps the complicated NSFilePresenter/NSFileCoordinator mess necessary to keep an eye on the plist files. This is a public method because it is used by the test data generator in the table view controller.
@property (nonatomic, readonly) PlistStoreFileWatcher *storeFileWatcher;

/// This is responsible for encoding/decoding managed object attributes to their dictionary plist counterparts. This is a public method because it is used by the test data generator in the table view controller.
@property (nonatomic, readonly) PlistIncrementalStoreCoder *entityCoder;

@end
