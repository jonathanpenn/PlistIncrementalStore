#import <Foundation/Foundation.h>

@class PlistStoreFileItem;
@class PlistStoreFileWatcher;


@protocol PlistStoreFileWatcherDelegate <NSObject>

/// Called when a file is changed or added. This is called inside an NSFileCoordinator block.
- (void)plistStoreFileWatcher:(PlistStoreFileWatcher *)watcher didSeeChangedStorageItem:(PlistStoreFileItem *)item;

/// Called when a file is deleted. This is called inside an NSFileCoordinator block.
- (void)plistStoreFileWatcher:(PlistStoreFileWatcher *)watcher didSeeRemovedStorageItem:(PlistStoreFileItem *)item;

@end


@interface PlistStoreFileWatcher : NSObject <NSFilePresenter>

@property (nonatomic, readonly) NSURL *URL;
@property (nonatomic, assign) id<PlistStoreFileWatcherDelegate> delegate;

/// Initializes and registers this as a file presenter.
- (instancetype)initWithURL:(NSURL *)URL;

/// Enumerator called for each file item found in the store directory.
typedef void (^PlistStoreFileItemEnumerator)(PlistStoreFileItem *item, BOOL *stop);

/// Enumerates all the files that have proper file extensions in the store directory as items.
- (BOOL)enumerateFileItems:(PlistStoreFileItemEnumerator)itemEnumerator error:(NSError **)error;

/// Does what it says on the tin. If the directory for the plist files doesn't exist, make it!
- (BOOL)createDirectoryIfNotThereError:(NSError **)error;

@end
