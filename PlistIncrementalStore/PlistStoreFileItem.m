#import "PlistStoreFileItem.h"
#import "PlistStoreFileWatcher.h"

@implementation PlistStoreFileItem {
    PlistStoreFileWatcher * __weak _storeFileWatcher;
}

@synthesize content=_content;

+ (instancetype)itemForStorageIdentifier:(NSString *)storageIdentifier inStoreFileWatcher:(PlistStoreFileWatcher *)storage {

    return [[self alloc] initWithStorageIdentifier:storageIdentifier withStoreFileWatcher:storage];
}

+ (instancetype)itemForURL:(NSURL *)url withStoreFileWatcher:(PlistStoreFileWatcher *)watcher {
    return [[self alloc] initWithURL:url withStoreFileWatcher:watcher];
}

- (instancetype)initWithURL:(NSURL *)url withStoreFileWatcher:(PlistStoreFileWatcher *)watcher {

    self = [super init];
    if (self) {
        _URL = url;
        _storageIdentifier = [[_URL lastPathComponent] stringByDeletingPathExtension];
        _storeFileWatcher = watcher;
    }
    return self;
}

- (instancetype)initWithStorageIdentifier:(NSString *)storageIdentifier withStoreFileWatcher:(PlistStoreFileWatcher *)watcher {

    NSAssert(watcher != nil, @"Must specify a watch so the full URL can be build from the storage identifier.");

    NSURL *url = [watcher.URL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.txt", storageIdentifier]];
    return [self initWithURL:url withStoreFileWatcher:watcher];
}

- (NSData *)content {
    NSAssert(_content || self.contentIsLoaded, @"Content of this item wasn't set or loaded from disk.");
    return _content;
}

- (void)setContent:(NSData *)content {
    _content = content;
    _contentIsLoaded = YES;
}

- (BOOL)loadContent:(NSError **)error {
    __block NSData *content = nil;

    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:self.storeFileWatcher];
    [coordinator coordinateReadingItemAtURL:self.URL
                                    options:NSFileCoordinatorReadingResolvesSymbolicLink
                                      error:error
                                 byAccessor:^(NSURL *newURL) {
                                     content = [NSData dataWithContentsOfURL:newURL options:NSDataReadingUncached error:error];
                                 }];

    if (!content) return NO;

    _contentIsLoaded = YES;
    _content = content;
    return YES;
}

- (BOOL)writeContent:(NSError **)error {
    __block BOOL success = NO;
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:self.storeFileWatcher];
    [coordinator coordinateWritingItemAtURL:self.URL options:0 error:error byAccessor:^(NSURL *newURL) {
        success = [self.content writeToURL:newURL options:NSDataWritingAtomic error:error];
    }];
    
    if (!success) return NO;
    else return YES;
}

- (BOOL)removeFile:(NSError **)error {
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:self.storeFileWatcher];
    __block BOOL success = NO;
    [coordinator coordinateWritingItemAtURL:self.URL options:NSFileCoordinatorWritingForDeleting error:error byAccessor:^(NSURL *newURL) {
        NSFileManager *manager = [NSFileManager defaultManager];
        if ([manager fileExistsAtPath:newURL.path]) {
            success = [[NSFileManager defaultManager] removeItemAtURL:newURL error:error];
        } else {
            // If file doesn't exist, it must have vanished. Nothing to delete.
            success = YES;
        }
    }];

    if (!success) return NO;
    else return YES;
}

@end
