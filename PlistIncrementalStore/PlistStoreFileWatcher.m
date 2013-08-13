#import "PlistStoreFileWatcher.h"
#import "PlistIncrementalStoreErrors.h"
#import "PlistStoreFileItem.h"

@implementation PlistStoreFileWatcher {
    NSOperationQueue *_operationQueue;
}

- (instancetype)initWithURL:(NSURL *)URL {

    self = [super init];
    if (self) {
        _URL = URL;
    }
    return self;
}


#pragma mark - NSFilePresenter Methods

- (NSURL *)presentedItemURL {
    return self.URL;
}

- (NSOperationQueue *)presentedItemOperationQueue {
    if (!_operationQueue) {
        _operationQueue = [[NSOperationQueue alloc] init];
        _operationQueue.maxConcurrentOperationCount = 1;
    }
    return _operationQueue;
}

- (void)presentedSubitemDidChangeAtURL:(NSURL *)url {
    if (![[url.path pathExtension] isEqualToString:@"txt"]) return;

    NSError *error = nil;
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:self];
    [coordinator coordinateReadingItemAtURL:url options:NSFileCoordinatorReadingResolvesSymbolicLink error:&error byAccessor:^(NSURL *newURL) {

        PlistStoreFileItem *item = [PlistStoreFileItem itemForURL:newURL withStoreFileWatcher:self];
        if ([[NSFileManager defaultManager] fileExistsAtPath:newURL.path]) {
            [self.delegate plistStoreFileWatcher:self didSeeChangedStorageItem:item];
        } else {
            [self.delegate plistStoreFileWatcher:self didSeeRemovedStorageItem:item];
        }

    }];

    if (error) {
        NSLog(@"Error responding to presented subitem: %@, %@", error, [error userInfo]);
    }
}


#pragma mark - Enumerating all the plist files

- (BOOL)enumerateFileItems:(PlistStoreFileItemEnumerator)itemEnumerator error:(NSError **)error {

    __block BOOL sawError = NO;

    void (^accessor)(NSURL *newURL) = ^(NSURL *newURL) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSDirectoryEnumerator *enumerator =
        [fileManager enumeratorAtURL:newURL includingPropertiesForKeys:nil
                             options:NSDirectoryEnumerationSkipsSubdirectoryDescendants | NSDirectoryEnumerationSkipsHiddenFiles
                        errorHandler:^BOOL(NSURL *url, NSError *blockError) {
                            *error = blockError;
                            sawError = YES;
                            return NO;
                        }];


        BOOL stop = NO;

        for (NSURL *fileURL in enumerator) {
            if (![fileURL.path hasSuffix:@".txt"]) continue;

            PlistStoreFileItem *item = [PlistStoreFileItem itemForURL:fileURL withStoreFileWatcher:self];

            itemEnumerator(item, &stop);

            if (stop) return;
        }
    };

    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:self];
    [coordinator coordinateReadingItemAtURL:[self URL]
                                    options:NSFileCoordinatorReadingResolvesSymbolicLink
                                      error:error
                                 byAccessor:accessor];

    if (error && sawError) return NO;
    else return YES;
}


#pragma mark - Creating the directory

- (BOOL)createDirectoryIfNotThereError:(NSError **)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSFileCoordinator *existenceCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:self];

    BOOL __block URLExists = NO;
    BOOL __block URLIsDirectory = NO;

    void (^existenceAccessor)(NSURL *newURL) = ^(NSURL *newURL) {
        URLExists = [fileManager fileExistsAtPath:newURL.path
                                      isDirectory:&URLIsDirectory];
    };
    [existenceCoordinator coordinateReadingItemAtURL:self.URL
                                             options:0
                                               error:error
                                          byAccessor:existenceAccessor];

    if (*error) return NO;

    if (!URLExists) {
        return [self createDirectory:error];
    } else if (!URLIsDirectory) {
        NSString *key = [NSString stringWithFormat:@"The destination for PlistIncrementalStore is not a directory (%@)", self.URL];
        NSString *localizedDescription = NSLocalizedString(key, nil);
        *error = [NSError errorWithDomain:@"PlistIncrementalStore" code:PlistIncrementalStoreExistsAndIsNotDirectory userInfo:@{NSLocalizedDescriptionKey: localizedDescription}];
        return NO;
    }

    return YES;
}

- (BOOL)createDirectory:(NSError **)error {
    NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:self];

    BOOL __block success = NO;

    void (^accessor)(NSURL *newURL)  = ^(NSURL *newURL) {
        success = [[NSFileManager defaultManager] createDirectoryAtURL:newURL
                                           withIntermediateDirectories:YES
                                                            attributes:nil
                                                                 error:error];
    };

    [coordinator coordinateWritingItemAtURL:self.URL
                                    options:NSFileCoordinatorWritingForReplacing
                                      error:error
                                 byAccessor:accessor];

    if (!success || *error) return NO;

    return YES;
}


@end
