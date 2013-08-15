#import "PlistIncrementalStore.h"
#import "PlistIncrementalStoreCoder.h"
#import "PlistStoreFileItem.h"

NSString * const PlistIncrementalStoreType = @"PlistIncrementalStore";
NSString * const PlistIncrementalStoreConfigureDebugEnabled = @"PlistIncrementalStoreConfigureDebugEnabled";

@implementation PlistIncrementalStore {
    BOOL _debugLog;
}

#pragma mark - Setup

- (void)dealloc {
    [NSFileCoordinator removeFilePresenter:self.storeFileWatcher];
}

/// This is called by the NSPersistentStoreCoordinator when setting up the stores.
- (id)initWithPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator
                       configurationName:(NSString *)name
                                     URL:(NSURL *)url
                                 options:(NSDictionary *)options {

    self = [super initWithPersistentStoreCoordinator:coordinator configurationName:name URL:url options:options];
    if (self) {
        _storeFileWatcher = [[PlistStoreFileWatcher alloc] initWithURL:url];
        _storeFileWatcher.delegate = self;
        [NSFileCoordinator addFilePresenter:_storeFileWatcher];

        _entityCoder = [[PlistIncrementalStoreCoder alloc] init];

        NSNumber *debugEnabled = options[PlistIncrementalStoreConfigureDebugEnabled];
        if (debugEnabled != nil && debugEnabled.boolValue) {
            _debugLog = YES;
        }
    }
    return self;
}


#pragma mark - NSIncrementalStore Subclass Methods

- (BOOL)loadMetadata:(NSError **)error {
    // This store is pretty forgiving because keys it doesn't know about are
    // ignored so there is no "schema" to check that we are compatible with
    // at this point.
    [self setMetadata:@{
       NSStoreUUIDKey: @"1",
       NSStoreTypeKey: PlistIncrementalStoreType
     }];
    return [self.storeFileWatcher createDirectoryIfNotThereError:error];
}

- (id)executeRequest:(NSPersistentStoreRequest *)request
         withContext:(NSManagedObjectContext *)context
               error:(NSError **)error {

    NSString *errorMessage = nil;

    switch (request.requestType) {
        case NSFetchRequestType:
            return [self _executeFetchRequest:(NSFetchRequest *)request
                                  withContext:context
                                        error:error];
            break;

        case NSSaveRequestType:
            return [self _executeSaveRequest:(NSSaveChangesRequest *)request
                                 withContext:context
                                       error:error];
            break;

        default:
            errorMessage = [NSString stringWithFormat:@"Unknown request type %d", request.requestType];
            *error = [NSError errorWithDomain:@"PlistIncrementalStore"
                                         code:PlistIncrementalStoreUnsupportedRequestType
                                     userInfo:@{NSLocalizedDescriptionKey:errorMessage}];
            return nil;
    }
}

- (NSIncrementalStoreNode *)newValuesForObjectWithID:(NSManagedObjectID *)objectID
                                         withContext:(NSManagedObjectContext *)context
                                               error:(NSError **)error {

    PlistStoreFileItem *item = [self _newItemForObjectID:objectID];
    if (![item loadContent:error]) return nil;
    NSDictionary *values = [self.entityCoder decodeData:item.content forEntity:objectID.entity error:error];
    if (!values) return nil;
    return [[NSIncrementalStoreNode alloc] initWithObjectID:objectID withValues:values version:0];
}

- (id)newValueForRelationship:(NSRelationshipDescription *)relationship
              forObjectWithID:(NSManagedObjectID *)objectID
                  withContext:(NSManagedObjectContext *)context
                        error:(NSError **)error {

    NSAssert(false, @"Relationships are not supported in PlistIncrementalStore");
    return nil;
}

- (NSArray *)obtainPermanentIDsForObjects:(NSArray *)objects
                                    error:(NSError **)error {

    NSMutableArray *ids = [NSMutableArray array];

    for (NSManagedObject *object in objects) {
        NSString *referenceObject = [[NSProcessInfo processInfo] globallyUniqueString];
        [ids addObject:[self newObjectIDForEntity:object.entity referenceObject:referenceObject]];
    }
    return ids;
}


#pragma mark - Request Helper Methods

- (id)_executeFetchRequest:(NSFetchRequest *)request
               withContext:(NSManagedObjectContext *)context
                     error:(NSError **)error {

    if (request.resultType != NSManagedObjectResultType &&
        request.resultType != NSManagedObjectIDResultType) {

        if (error != NULL) {
            NSString *message = [NSString stringWithFormat:@"Unsupported result type for request %@", request];
            *error = [NSError errorWithDomain:@"PlistIncrementalStore"
                                         code:PlistIncrementalStoreUnsupportedResultType
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }
        return nil;
    }

    NSMutableArray *results = [NSMutableArray array];

    // Yes, we're iterating over ALL the files in the directory, but we have to every time. We have to load every file to get it's contents to know how to filter and sort the results before handing the results back. Very inefficient for a large number of files as it is.
    BOOL success = [self.storeFileWatcher enumerateFileItems:^(PlistStoreFileItem *item, BOOL *stop) {
        NSError *error = nil;
        NSManagedObjectID *objectID = [self _newObjectIDFromStorageItem:item error:&error];

        if (!objectID) {
            if (_debugLog) {
                NSLog(@"Unable to build object id for item at \"%@\". It's possible that the filename is mangled. (%@)", item.URL.path, error.localizedDescription);
            }
            return;
        }

        NSManagedObject *object = [context existingObjectWithID:objectID error:&error];
        if (!object) {
            if (_debugLog) {
                NSLog(@"Unable to load object for item at \"%@\". It's possible that the file was written as empty before writing the contents as a separate step. (%@)", item.URL.path, error.localizedDescription);
            }
            return;
        }

        if (!request.predicate || [request.predicate evaluateWithObject:object]) {
            [results addObject:object];
        }
    } error:error];

    if (!success) { return nil; }

    [results sortUsingDescriptors:request.sortDescriptors];

    if (request.resultType == NSManagedObjectIDResultType) {
        return [results valueForKeyPath:@"objectID"];
    } else {
        return results;
    }
}

- (id)_executeSaveRequest:(NSSaveChangesRequest *)request
              withContext:(NSManagedObjectContext *)context
                    error:(NSError **)error {

    if (![self _storeObjects:request.insertedObjects withContext:context error:error] ||
        ![self _storeObjects:request.updatedObjects withContext:context error:error] ||
        ![self _removeObjects:request.deletedObjects withContext:context error:error]) {

        return nil;
    } else {
        return @[];
    }
}


- (BOOL)_storeObjects:(NSSet *)objects
          withContext:(NSManagedObjectContext *)context
                error:(NSError **)error {

    if (objects == nil) return YES;

    for (NSManagedObject *object in objects) {
        NSData *encoded = [self.entityCoder encodeObject:object forEntity:object.entity error:error];
        if (!encoded) return NO;

        PlistStoreFileItem *item = [self _newItemForObjectID:object.objectID];
        item.content = encoded;
        if (![item writeContent:error]) return NO;
    }
    return YES;
}

- (BOOL)_removeObjects:(NSSet *)objects
           withContext:(NSManagedObjectContext *)context
                 error:(NSError **)error {

    if (objects == nil) return YES;

    for (NSManagedObject *object in objects) {
        PlistStoreFileItem *item = [self _newItemForObjectID:object.objectID];
        if (![item removeFile:error]) return NO;
    }
    return YES;
}


#pragma mark - PlsitStoreFileWatcher Callbacks

- (void)plistStoreFileWatcher:(PlistStoreFileWatcher *)storage didSeeChangedStorageItem:(PlistStoreFileItem *)item {

    NSError *error = nil;
    NSManagedObjectID *objectID = [self _newObjectIDFromStorageItem:item error:&error];

    if (!objectID) {
        if (_debugLog) {
            NSLog(@"Unable to interpret filename of changed plist file.\n%@", error);
        }
        return;
    }

    [self.contextToNotify performBlock:^{
        // We're using refreshObject:mergeChanges: instead of mergeChangesFromContextDidSaveNotification: because the latter blows up with an exception if the object can't be loaded. This is because it's possible for some apps that create files (ahem, Finder) will write a zero length file that triggers this event. Then the app writes the contents of the file which triggers another event.
        // I decided to try to force the reloading here with existingObjectWithID:error: so that we can handle and ignore any problem Core Data has loading the object.

        // Forceably turn any object in the context with this ID back into a fault.
        [self.contextToNotify refreshObject:[self.contextToNotify objectWithID:objectID] mergeChanges:NO];

        // Force a reload of the object into this context.
        NSError *error = nil;
        NSManagedObject *object = [self.contextToNotify existingObjectWithID:objectID error:&error];

        if (!object && _debugLog) {
            NSLog(@"Unable to load object for item at \"%@\". It's possible that the file was written as empty before writing the contents as a separate step. (%@)", item.URL.path, error.localizedDescription);
            return;
        }

        // We have to post a notification that an object was updated so anyone listening will get the memo.
        NSNotification *note = [NSNotification notificationWithName:NSManagedObjectContextDidSaveNotification
                                                             object:nil
                                                           userInfo:@{NSUpdatedObjectsKey: @[object]}];
        [self.contextToNotify mergeChangesFromContextDidSaveNotification:note];
    }];
}

- (void)plistStoreFileWatcher:(PlistStoreFileWatcher *)storage didSeeRemovedStorageItem:(PlistStoreFileItem *)item {

    NSError *error = nil;
    NSManagedObjectID *objectID = [self _newObjectIDFromStorageItem:item error:&error];

    if (!objectID) {
        if (_debugLog) {
            NSLog(@"Unable to interpret filename of changed plist file.\n%@", error);
        }
        return;
    }

    [self.contextToNotify performBlock:^{
        NSManagedObject *object = [self.contextToNotify objectWithID:objectID];
        NSNotification *note = [NSNotification notificationWithName:NSManagedObjectContextDidSaveNotification
                                                             object:nil
                                                           userInfo:@{NSDeletedObjectsKey: @[object]}];
        [self.contextToNotify mergeChangesFromContextDidSaveNotification:note];
    }];
}


#pragma mark - NSManagedObjectID/PlistStoreFileItem Conversions

- (PlistStoreFileItem *)_newItemForObjectID:(NSManagedObjectID *)objectID {
    // referenceObjectForObjectID: is a method on NSIncrementalStore superclass.
    // Core Data manages the conversion to/from reference objects.
    NSString *referenceObject = [[self referenceObjectForObjectID:objectID] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *storageIdentifier = [NSString stringWithFormat:@"%@;%@", objectID.entity.name, referenceObject];
    return [PlistStoreFileItem itemForStorageIdentifier:storageIdentifier
                                     inStoreFileWatcher:self.storeFileWatcher];
}

- (NSManagedObjectID *)_newObjectIDFromStorageItem:(PlistStoreFileItem *)item
                                             error:(NSError **)error {

    NSArray *parts = [item.storageIdentifier componentsSeparatedByString:@";"];
    if ([parts count] != 2) {
        if (error != NULL) {
            NSString *description = [NSString stringWithFormat:@"Invalid store filename: %@", item.URL];
            *error = [NSError errorWithDomain:@"PlistIncrementalStore"
                                         code:PlistIncrementalStoreInvalidFileName
                                     userInfo:@{NSLocalizedDescriptionKey: description}];
        }
        return nil;
    }

    NSString *entityName = parts[0];
    NSEntityDescription *entity = self.persistentStoreCoordinator.managedObjectModel.entitiesByName[entityName];

    if (!entity) {
        if (error != NULL) {
            NSString *description = [NSString stringWithFormat:@"Could not find entity for %@", item.URL];
            *error = [NSError errorWithDomain:@"PlistIncrementalStore"
                                         code:PlistIncrementalStoreEntityDoesNotExist
                                     userInfo:@{NSLocalizedDescriptionKey: description}];
        }
        return nil;
    }

    NSString *referenceObject = [parts[1] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

    return [self newObjectIDForEntity:entity referenceObject:referenceObject];
}


@end

