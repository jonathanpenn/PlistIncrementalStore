// TODO: annotate these errors

typedef enum {
    /// The encoded type on disk doesn't match the entity's attribute in the model.
    PlistIncrementalStoreWrongEncodedTypeError = 1,

    /// The path for the store is supposed to be a directory.
    PlistIncrementalStoreExistsAndIsNotDirectory = 2,

    /// Means that a filename in the PlistStorage directory is malformed and can't be decomposed into the reference object and entity name.
    PlistIncrementalStoreInvalidFileName = 3,

    /// Only object and object ID result types are supported when fetching.
    PlistIncrementalStoreUnsupportedResultType = 4,

    /// Only fetch and save requests are supported.
    PlistIncrementalStoreUnsupportedRequestType = 5,

    /// The entity described by the filename doesn't exist in the model.
    PlistIncrementalStoreEntityDoesNotExist = 6,
} PlistIncrementalStoreError;