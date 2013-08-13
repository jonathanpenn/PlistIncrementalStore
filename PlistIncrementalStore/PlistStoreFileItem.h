#import <Foundation/Foundation.h>

@class PlistStoreFileWatcher;

@interface PlistStoreFileItem : NSObject

@property (nonatomic, strong) NSData *content;
@property (nonatomic, readonly) BOOL contentIsLoaded;
@property (nonatomic, readonly) NSURL *URL;
@property (nonatomic, readonly) NSString *storageIdentifier;
@property (nonatomic, readonly) PlistStoreFileWatcher *storeFileWatcher;

/// Constructs a PlistStorageItem representing a file with the storage identifier in the file watcher's URL.
+ (instancetype)itemForStorageIdentifier:(NSString *)storageIdentifier inStoreFileWatcher:(PlistStoreFileWatcher *)storage;

/// Constructs a PlistStorageItem representing the file at the given URL.
+ (instancetype)itemForURL:(NSURL *)url withStoreFileWatcher:(PlistStoreFileWatcher *)storage;

/// Attempts to load the content of the item's URL.
- (BOOL)loadContent:(NSError **)error;

/// Attempts to write the content of the item's URL.
- (BOOL)writeContent:(NSError **)error;

/// Attempts to remove the underlying item's file at the URL.
- (BOOL)removeFile:(NSError **)error;

@end
