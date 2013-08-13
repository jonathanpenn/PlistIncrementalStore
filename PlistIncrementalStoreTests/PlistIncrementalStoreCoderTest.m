#import <SenTestingKit/SenTestingKit.h>
#import "PlistIncrementalStoreCoder.h"
#import "PlistIncrementalStoreErrors.h"

@interface PlistIncrementalStoreCoderTest : SenTestCase
@property (nonatomic, strong) NSManagedObjectModel *model;
@property (nonatomic, strong) NSPersistentStoreCoordinator *coordinator;
@property (nonatomic, strong) NSManagedObjectContext *context;

@property (nonatomic, strong) NSEntityDescription *entityDescription;
@property (nonatomic, strong) PlistIncrementalStoreCoder *entityCoder;

@property (nonatomic, strong) NSAttributeDescription *requiredNameAttribute;
@property (nonatomic, strong) NSAttributeDescription *dateAttribute;
@property (nonatomic, strong) NSAttributeDescription *integerProperty;
@property (nonatomic, strong) NSAttributeDescription *doubleProperty;
@property (nonatomic, strong) NSAttributeDescription *transitentProperty;
@property (nonatomic, strong) NSAttributeDescription *emptyProperty;
@end

@interface PlistIncrementalStoreCoderTestExample : NSManagedObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, copy) NSNumber *integerNumber;
@property (nonatomic, copy) NSNumber *doubleNumber;
@property (nonatomic, copy) NSString *transientString;
@property (nonatomic, copy) NSString *emptyString;
@end
@implementation PlistIncrementalStoreCoderTestExample
@dynamic name, date, integerNumber, doubleNumber, transientString, emptyString;
@end

@implementation PlistIncrementalStoreCoderTest

- (void)setUp {
    [super setUp];
    [self createAttributes];
    // Breaking up the attribute creation from the core data stack creation because the model must be set to immutable when added to a core data stack
}

- (void)createAttributes
{
    self.entityDescription = [[NSEntityDescription alloc] init];
    self.entityDescription.name = @"SomeEntity";
    self.entityDescription.managedObjectClassName = @"PlistIncrementalStoreCoderTestExample";

    self.requiredNameAttribute = [[NSAttributeDescription alloc] init];
    self.requiredNameAttribute.name = @"name";
    self.requiredNameAttribute.attributeType = NSStringAttributeType;

    self.dateAttribute = [[NSAttributeDescription alloc] init];
    self.dateAttribute.name = @"date";
    self.dateAttribute.attributeType = NSDateAttributeType;

    self.integerProperty = [[NSAttributeDescription alloc] init];
    self.integerProperty.name = @"integerNumber";
    self.integerProperty.attributeType = NSInteger32AttributeType;

    self.doubleProperty = [[NSAttributeDescription alloc] init];
    self.doubleProperty.name = @"doubleNumber";
    self.doubleProperty.attributeType = NSDoubleAttributeType;

    self.transitentProperty = [[NSAttributeDescription alloc] init];
    self.transitentProperty.name = @"transientString";
    self.transitentProperty.attributeType = NSStringAttributeType;
    [self.transitentProperty setTransient:YES];

    self.emptyProperty = [[NSAttributeDescription alloc] init];
    self.emptyProperty.name = @"emptyString";
    self.emptyProperty.attributeType = NSStringAttributeType;

    self.entityDescription.properties = @[self.requiredNameAttribute, self.dateAttribute, self.integerProperty, self.doubleProperty, self.transitentProperty, self.emptyProperty];

    self.entityCoder = [[PlistIncrementalStoreCoder alloc] init];
}

- (PlistIncrementalStoreCoderTestExample *)makeExampleObject
{
    PlistIncrementalStoreCoderTestExample *object = [[PlistIncrementalStoreCoderTestExample alloc] initWithEntity:self.entityDescription insertIntoManagedObjectContext:nil];
    object.name = @"Object 1";
    object.date = [NSDate dateWithTimeIntervalSince1970:0];
    object.integerNumber = @2.2; // This will be truncated
    object.doubleNumber = @2.2;
    return object;
}

- (NSDictionary *)rawEncodedDataToDictionary:(NSData *)data
{
    NSError *error = nil;
    NSDictionary *rawEncoded = [NSPropertyListSerialization propertyListWithData:data options:0 format:nil error:&error];
    STAssertNotNil(rawEncoded, @"Error deserializing raw dictionary %@\n%@", error.localizedDescription, error);
    return rawEncoded;
}

- (NSData *)dictionaryToRawEncodedData:(NSDictionary *)dict
{
    NSError *error = nil;
    NSData *rawEncoded = [NSPropertyListSerialization dataWithPropertyList:dict format:NSPropertyListXMLFormat_v1_0 options:0 error:&error];
    STAssertNotNil(rawEncoded, @"Error serializing raw dictionary %@\n%@", error.localizedDescription, error);
    return rawEncoded;
}


#pragma mark - Tests

- (void)testSuccessfulCodingAndDecoding {
    NSError *error = nil;

    PlistIncrementalStoreCoderTestExample *object = [self makeExampleObject];
    object.transientString = @"will be nil";

    NSData *data = [self.entityCoder encodeObject:object forEntity:self.entityDescription error:&error];
    STAssertNotNil(data, @"Expected data but got error %@\n%@", error.localizedDescription, error);

    // Testing the raw encoded dictionary format

    NSDictionary *rawEncoded = [self rawEncodedDataToDictionary:data];
    STAssertEqualObjects((@[@"date", @"doubleNumber", @"integerNumber", @"name"]), [rawEncoded.allKeys sortedArrayUsingSelector:@selector(compare:)], nil);
    STAssertEqualObjects(@"Object 1", rawEncoded[@"name"], nil);
    STAssertEqualObjects([NSDate dateWithTimeIntervalSince1970:0], rawEncoded[@"date"], nil);
    STAssertEqualObjects(@2, rawEncoded[@"integerNumber"], nil);
    STAssertEqualObjects(@2.2, rawEncoded[@"doubleNumber"], nil);


    // Testing the decoding into the incremental store node that Core Data consumes

    NSDictionary *values = [self.entityCoder decodeData:data forEntity:self.entityDescription error:&error];
    STAssertNotNil(values, @"Expected dictionary but got error %@\n%@", error.localizedDescription, error);

    STAssertEqualObjects(@"Object 1", values[@"name"], nil);
    STAssertEqualObjects([NSDate dateWithTimeIntervalSince1970:0], values[@"date"], nil);
    STAssertEqualObjects(@2, values[@"integerNumber"], nil);
    STAssertEqualObjects(@2.2, values[@"doubleNumber"], nil);
    STAssertNil(values[@"transientString"], nil);
    STAssertNil(values[@"emptyString"], nil);
}

- (void)testIgnoresExtraPlistKeys {
    NSError *error = nil;

    NSData *rawEncoded = [self dictionaryToRawEncodedData:@{@"name": @"my name", @"unknwon": @"will be gone"}];

    NSDictionary *values = [self.entityCoder decodeData:rawEncoded forEntity:self.entityDescription error:&error];
    STAssertNotNil(values, @"Expected dictionary but got error %@\n%@", error.localizedDescription, error);

    STAssertEqualObjects(@"my name", values[@"name"], nil);
}

- (void)testHandlingWrongValueType {
    NSError *error = nil;

    NSData *rawEncoded = [self dictionaryToRawEncodedData:@{@"name": @2}];

    NSDictionary *values = [self.entityCoder decodeData:rawEncoded forEntity:self.entityDescription error:&error];
    STAssertNil(values, @"Expected decoding to fail");

    STAssertNotNil(error, @"Expecting an error object");
    STAssertEqualObjects(@"PlistIncrementalStore", error.domain, nil);
    STAssertEquals(PlistIncrementalStoreWrongEncodedTypeError, error.code, nil);
}

@end

