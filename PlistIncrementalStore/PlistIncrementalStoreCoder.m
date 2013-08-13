#import "PlistIncrementalStoreCoder.h"
#import "PlistIncrementalStoreErrors.h"

@implementation PlistIncrementalStoreCoder

- (NSData *)encodeObject:(NSObject *)object
               forEntity:(NSEntityDescription *)entity
                   error:(NSError **)error {

    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    for (NSString *name in entity.attributesByName) {
        NSAttributeDescription *attr = entity.attributesByName[name];

        // Ignore any attributes that are transient
        if (attr.isTransient) continue;

        // Ignore any keys in the dictionary that are nil
        id value = [object valueForKey:name];
        if (value != nil) dict[name] = value;
    }

    return [NSPropertyListSerialization dataWithPropertyList:dict format:NSPropertyListXMLFormat_v1_0 options:NSPropertyListImmutable error:error];
}

- (NSDictionary *)decodeData:(NSData *)data
                   forEntity:(NSEntityDescription *)entity
                       error:(NSError **)error {

    NSDictionary *values = [NSPropertyListSerialization propertyListWithData:data options:0 format:nil error:error];
    if (!values) return NO;

    NSDictionary *attributesByName = entity.attributesByName;
    for (NSString *key in [values allKeys]) {
        id value = values[key];
        NSAttributeDescription *attribute = attributesByName[key];

        // Ignore any keys in the plist file that we don't have attributes for.
        if (!attribute) continue;

        switch (attribute.attributeType) {
            case NSStringAttributeType:
                if (![self checkValue:value forKey:key ofEntity:entity isKindOfClass:[NSString class] error:error]) return nil;
                break;
            case NSDateAttributeType:
                if (![self checkValue:value forKey:key ofEntity:entity isKindOfClass:[NSDate class] error:error]) return nil;
                break;
            case NSInteger16AttributeType:
            case NSInteger32AttributeType:
            case NSInteger64AttributeType:
            case NSDecimalAttributeType:
            case NSDoubleAttributeType:
            case NSFloatAttributeType:
            case NSBooleanAttributeType:
                if (![self checkValue:value forKey:key ofEntity:entity isKindOfClass:[NSNumber class] error:error]) return nil;
                break;
            case NSUndefinedAttributeType:
                // This is a transient property.
                break;
            default:
                if (error) {
                    *error = [NSError errorWithDomain:@"PlistIncrementalStore" code:PlistIncrementalStoreWrongEncodedTypeError userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Attribute type %d not handled by store", attribute.attributeType]}];
                }
                return nil;
        }
    }

    return values;
}

- (BOOL)checkValue:(id)value
            forKey:(NSString *)key
          ofEntity:(NSEntityDescription *)entity
     isKindOfClass:(Class)expected
             error:(NSError **)error {
    
    if (![value isKindOfClass:expected]) {
        if (error) {
            NSString *description = [NSString stringWithFormat:@"Key \"%@\" not expected to be %@ but is %@ for entity %@", key, NSStringFromClass(expected), NSStringFromClass([value class]), entity];
            *error = [NSError errorWithDomain:@"PlistIncrementalStore" code:PlistIncrementalStoreWrongEncodedTypeError userInfo:@{NSLocalizedDescriptionKey:description}];
        }
        return NO;
    }

    return YES;
}

@end
