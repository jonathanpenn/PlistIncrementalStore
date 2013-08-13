#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface JournalEntry : NSManagedObject

@property (nonatomic, copy) NSString *content;
@property (nonatomic, strong) NSDate *timestamp;

@end
