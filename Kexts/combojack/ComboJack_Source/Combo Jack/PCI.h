//
//  pci.h
//  DPCIManager
//
//  Created by PHPdev32 on 10/8/12.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

#import <stdint.h>
#import <Foundation/Foundation.h>

@interface pciDevice : NSObject

@property uint64_t entryID;
@property NSNumber *shadowVendor;
@property NSNumber *shadowDevice;
@property NSNumber *revision;
@property NSArray *bus;
@property NSNumber *vendor;
@property NSNumber *device;
@property NSNumber *subVendor;
@property NSNumber *subDevice;
@property NSNumber *pciClassCode;
@property NSNumber *pciClass;
@property NSNumber *pciSubClass;
@property NSString *vendorString;
@property NSString *deviceString;
@property NSString *classString;
@property NSString *subClassString;
@property (readonly) NSString *fullClassString;
@property (readonly) NSString *lspciString;
@property (readonly) NSDictionary *lspciDictionary;
@property (readonly) long fullID;
@property (readonly) long fullSubID;
@property (readonly) short bdf;

+(long)nameToLong:(NSString *)name;
+(bool)isPCI:(io_service_t)service;
+(NSNumber *)grabNumber:(CFStringRef)entry forService:(io_service_t)service;
+(NSString *)grabString:(CFStringRef)entry forService:(io_service_t)service;
+(NSDictionary *)match:(pciDevice *)pci;
+(pciDevice *)create:(io_service_t)service classes:(NSMutableDictionary *)classes vendors:(NSMutableDictionary *)vendors;
+(pciDevice *)create:(io_service_t)service;
+(NSArray *)readIDs;

@end

@interface pciVendor : NSObject
@property NSString *name;
@property NSMutableDictionary *devices;
+(pciVendor *)create:(NSString *)name;
@end

@interface pciClass : NSObject
@property NSString *name;
@property NSMutableDictionary *subClasses;
+(pciClass *)create:(NSString *)name;
@end

@interface efiObject : NSObject
@property NSDictionary *properties;
@property pciDevice *device;
+(efiObject *)create:(pciDevice *)device injecting:(NSDictionary *)properties;
+(NSString *)stringWithArray:(NSArray *)array;
@end

@interface hexFormatter : NSValueTransformer
+(BOOL)allowsReverseTransformation;
+(Class)transformedValueClass;
-(id)transformedValue:(id)value;
@end
