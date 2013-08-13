#import <Foundation/Foundation.h>

@interface PlistIncrementalStoreCoder : NSObject

- (NSData *)encodeObject:(NSObject *)object forEntity:(NSEntityDescription *)entity error:(NSError **)error;
- (NSDictionary *)decodeData:(NSData *)data forEntity:(NSEntityDescription *)entity error:(NSError **)error;

@end
