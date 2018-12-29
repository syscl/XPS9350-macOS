//
//  pci.m
//  DPCIManager
//
//  Created by PHPdev32 on 10/8/12.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//

#import "PCI.h"
#import "Tables.h"
#define h64tob32(x) (unsigned)(CFSwapInt64HostToBig(x)>>32)
#define strHexDec(x) strtol([x UTF8String], NULL, 16)

#pragma mark Device Class
@implementation pciDevice

@synthesize vendor;
@synthesize device;
@synthesize subVendor;
@synthesize subDevice;
@synthesize pciClassCode;
@synthesize pciClass;
@synthesize pciSubClass;
@synthesize bus;
@synthesize revision;
@synthesize shadowDevice;
@synthesize shadowVendor;
@synthesize vendorString;
@synthesize deviceString;
@synthesize classString;
@synthesize subClassString;

+(long)nameToLong:(NSString *)name{
    if (![name hasPrefix:@"pci"] || [name rangeOfString:@","].location == NSNotFound) return 0;
    NSArray *temp = [[name stringByReplacingOccurrencesOfString:@"pci" withString:@""] componentsSeparatedByString:@","];
    return strHexDec([temp objectAtIndex:1]) << 16 | strHexDec([temp objectAtIndex:0]);
}
+(bool)isPCI:(io_service_t)service{
    return [@"IOPCIDevice" isEqualToString:(__bridge_transfer NSString *)IOObjectCopyClass(service)];
}
+(NSNumber *)grabNumber:(CFStringRef)entry forService:(io_service_t)service{//FIXME: shift bridge
    id number = (__bridge_transfer id)IORegistryEntryCreateCFProperty(service, entry, kCFAllocatorDefault, 0);
    NSNumber *temp = @0;
    if (!number) return temp;
    if ([number isKindOfClass:[NSNumber class]]) return number;
    else if ([number isKindOfClass:[NSData class]])
        temp = @(*(NSInteger *)[number bytes]);
    return temp;
}
+(NSString *)grabString:(CFStringRef)entry forService:(io_service_t)service{
    id string = (__bridge_transfer id)IORegistryEntryCreateCFProperty(service, entry, kCFAllocatorDefault, 0);
    NSString *temp = @"";
    if (!string) return temp;
    if ([string isKindOfClass:[NSString class]]) return string;
    else if ([string isKindOfClass:[NSData class]])
        if (!(temp = [[NSString alloc] initWithData:string encoding:NSUTF8StringEncoding]))
            temp = [[NSString alloc] initWithData:string encoding:NSASCIIStringEncoding];
    return temp;
}
+(NSDictionary *)match:(pciDevice *)pci{
    NSInteger vendor = pci.vendor.integerValue;
    NSInteger device = pci.device.integerValue;
    return @{@kIOPropertyMatchKey:@{@"vendor-id":[NSData dataWithBytes:&vendor length:4], @"device-id":[NSData dataWithBytes:&device length:4]}};
}
+(pciDevice *)create:(io_service_t)service classes:(NSMutableDictionary *)classes vendors:(NSMutableDictionary *)vendors{
    pciDevice *temp = [pciDevice create:service];
    temp.vendorString = [[vendors objectForKey:temp.shadowVendor] name];
    temp.deviceString = [[[vendors objectForKey:temp.shadowVendor] devices] objectForKey:temp.shadowDevice];
    temp.classString = [[classes objectForKey:temp.pciClass] name];
    temp.subClassString = [[[classes objectForKey:temp.pciClass] subClasses] objectForKey:temp.pciSubClass];
    return temp;
}
+(pciDevice *)create:(io_service_t)service{//FIXME: add validator option?
    pciDevice *temp = [pciDevice new];//!!!: agreements are base&compat, sub&compatsub, IOName&name
    @try {
        IORegistryEntryGetRegistryEntryID(service, &temp->_entryID);
        temp.vendor = [self grabNumber:CFSTR("vendor-id") forService:service];
        temp.device = [self grabNumber:CFSTR("device-id") forService:service];
        temp.bus = [[[[pciDevice grabString:CFSTR("pcidebug") forService:service] stringByReplacingOccurrencesOfString:@"(" withString:@":"] componentsSeparatedByString:@":"] valueForKey:@"integerValue"];
        if (![pciDevice isPCI:service]) [NSException raise:@"notpci" format:@"Not a real pci device!"];
        temp.subVendor = [self grabNumber:CFSTR("subsystem-vendor-id") forService:service];
        temp.subDevice = [self grabNumber:CFSTR("subsystem-id") forService:service];
        temp.pciClassCode = [self grabNumber:CFSTR("class-code") forService:service];
        temp.pciClass = @((temp.pciClassCode.integerValue >> 16) &0xFF);
        temp.pciSubClass = @((temp.pciClassCode.integerValue >> 8) &0xFF);
        temp.revision = [self grabNumber:CFSTR("revision-id") forService:service];
        long ids = 0;
        NSString *string = [pciDevice grabString:CFSTR("IOName") forService:service];
        if (string.length) ids = [self nameToLong:string];
        //else [NSException raise:@"noioname" format:@"Missing IOName"];
        if (!ids) {
            string = [pciDevice grabString:CFSTR("name") forService:service];
            if (string.length) ids = [self nameToLong:string];
            //else [NSException raise:@"noioname" format:@"Missing name"];
        }
        temp.shadowVendor = !ids?temp.vendor:@(ids & 0xFFFF);
        temp.shadowDevice = !ids?temp.device:@(ids >> 16);
    }
    @catch (NSException *e) {
        //NSRunCriticalAlertPanel(@"PCI Error", @"%@ 0x%04X%04X", nil, nil, nil, e.reason, temp.vendor.intValue, temp.device.intValue);
        temp.vendor = temp.device = temp.subVendor = temp.subDevice = temp.pciClassCode = temp.pciClass = temp.pciSubClass = temp.revision = temp.shadowVendor = temp.shadowDevice = @0;
        temp.bus = @[temp.vendor, temp.vendor, temp.vendor];
    }
    @finally {
        return temp;
    }
}
-(NSString *)fullClassString{
    return [NSString stringWithFormat:@"%@, %@", classString, subClassString];
}
-(NSString *)lspciString{
    return [NSString stringWithFormat:@"%02lx:%02lx.%01lx %@ [%04lx]: %@ %@ [%04lx:%04lx]%@%@", [[bus objectAtIndex:0] integerValue], [[bus objectAtIndex:1] integerValue], [[bus objectAtIndex:2] integerValue], subClassString, pciClassCode.integerValue>>8, vendorString, deviceString, shadowVendor.integerValue, shadowDevice.integerValue, !revision.integerValue?@"":[NSString stringWithFormat:@" (rev %02lx)", revision.integerValue], !subDevice.integerValue?@"":[NSString stringWithFormat:@" (subsys %04lx:%04lx)", subVendor.integerValue, subDevice.integerValue]];
}
-(NSDictionary *)lspciDictionary{
    NSDictionary *lspci_dict = @{
      // BusNumber:DeviceNumber.FunctionNumber
      @"BDF": [NSString stringWithFormat:@"%02lx:%02lx.%01lx", [[bus objectAtIndex:0] integerValue], [[bus objectAtIndex:1] integerValue], [[bus objectAtIndex:2] integerValue]],
      // Device's Class
      @"Class": @{
              @"ClassName": [NSString stringWithFormat:@"%@", classString],
              @"SubclassName": [NSString stringWithFormat:@"%@", subClassString],
              @"ID": [NSString stringWithFormat:@"%04lx", pciClassCode.integerValue>>8]
      },
      // Device Info
      @"Info": @{
              @"Name": [NSString stringWithFormat:@"%@", deviceString],
              @"Vendor": [NSString stringWithFormat:@"%@", vendorString]
      },
      // Device ID
      @"ID": @{
              @"DeviceID": [NSString stringWithFormat:@"%04lx", shadowDevice.integerValue],
              @"VendorID": [NSString stringWithFormat:@"%04lx", shadowVendor.integerValue]
      },
      // Subsystem ID
      @"SubsysID": @{
              @"DeviceID": [NSString stringWithFormat:@"%04lx", subDevice.integerValue],
              @"VendorID": [NSString stringWithFormat:@"%04lx", subVendor.integerValue]
      },
      // Revision
      @"Rev": [NSString stringWithFormat:@"%02lx", revision.integerValue]
    };
    return lspci_dict;
}
-(long)fullID{
    return device.integerValue<<16 | vendor.integerValue;
}
-(long)fullSubID{
    return subDevice.integerValue<<16 | subVendor.integerValue;
}
-(short)bdf {
    if (self.bus.count > 2)
        return [[self.bus objectAtIndex:0] unsignedCharValue] << 8 | [[self.bus objectAtIndex:1] unsignedCharValue] << 3 | [[self.bus objectAtIndex:2] unsignedCharValue];
    return -1;
}

+(NSArray *)readIDs{
    FILE *handle = fopen([[NSBundle.mainBundle pathForResource:@"pci" ofType:@"ids"] fileSystemRepresentation], "rb");
    NSMutableDictionary *classes = [NSMutableDictionary dictionary];
    NSMutableDictionary *vendors = [NSMutableDictionary dictionary];
    NSNumber *currentClass;
    NSNumber *currentVendor;
    char buffer[LINE_MAX];
	long device_id, subclass_id;
	char *buf;
	bool class_parse = false;
	while((buf = fgets(buffer, LINE_MAX, handle)) != NULL) {
        if (buf[0] == '#' || strlen(buf) <= 4) continue;
        buf[strlen(buf)-1]='\0';
        if (*buf == 'C') class_parse = true;
        if (class_parse) {
            if (*buf == '\t') {
                buf++;
                if (*buf != '\t') {
                    subclass_id = strtol(buf, NULL, 16);
                    buf += 4;
                    while (*buf == ' ' || *buf == '\t') buf++;
                    [[[classes objectForKey:currentClass] subClasses] setObject:@(buf) forKey:@(subclass_id)];
                }
            }
            else if (*buf == 'C') {
                buf += 2;
                currentClass = @(strtol(buf, NULL, 16));
                buf += 4;
                while (*buf == ' ' || *buf == '\t') buf++;
                [classes setObject:[pciClass create:@(buf)] forKey:currentClass];
            }
        }
        else {
            if (*buf == '\t') {
                buf++;
                if (*buf != '\t') {
                    device_id = strtol(buf, NULL, 16);
                    buf += 4;
                    while (*buf == ' ' || *buf == '\t') buf++;
                    [[[vendors objectForKey:currentVendor] devices] setObject:@(buf) forKey:@(device_id)];
                }
            }
            else if (*buf != '\\') {
                currentVendor = @(strtol(buf, NULL, 16));
                buf += 4;
                while (*buf == ' ' || *buf == '\t') buf++;
                [vendors setObject:[pciVendor create:@(buf)] forKey:currentVendor];
            }
        }
	}
    fclose(handle);
    NSMutableArray *pcis = [NSMutableArray array];
    io_iterator_t itThis;
    if (IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IOPCIDevice"), &itThis) == KERN_SUCCESS) {
        io_service_t service;
        while((service = IOIteratorNext(itThis))){
            pciDevice *pci = [pciDevice create:service classes:classes vendors:vendors];
            if (pci.fullID+pci.fullSubID > 0) [pcis addObject:pci];
            IOObjectRelease(service);
        }
        IOObjectRelease(itThis);
    }
    return [pcis copy];
}
@end

#pragma mark ID Classes
@implementation pciVendor
@synthesize name;
@synthesize devices;
+(pciVendor *)create:(NSString *)name{
    pciVendor *temp = [pciVendor new];
    temp.name = name;
    temp.devices = [NSMutableDictionary dictionary];
    return temp;
}
@end

@implementation pciClass
@synthesize name;
@synthesize subClasses;
+(pciClass *)create:(NSString *)name{
    pciClass *temp = [pciClass new];
    temp.name = name;
    temp.subClasses = [NSMutableDictionary dictionary];
    return temp;
}
@end

@implementation efiObject
@synthesize properties;
@synthesize device;
+(efiObject *)create:(pciDevice *)device injecting:(NSDictionary *)properties{
    efiObject *temp = [efiObject new];
    temp.properties = properties;
    temp.device = device;
    return temp;
}
+(NSString *)stringWithArray:(NSArray *)array{
    NSMutableString *str = [NSMutableString stringWithFormat:@"%08x%08x", CFSwapInt32HostToBig(1), h64tob32(array.count)];
    for (efiObject *obj in array) {
        NSMutableString *efi = [NSMutableString stringWithFormat:@"%08x", 0x7fff0400];
        io_service_t service = IOServiceGetMatchingService(kIOMasterPortDefault, (__bridge_retained CFDictionaryRef)[pciDevice match:obj.device]);
        while (true) {
            NSString *property;
            if ((property = [pciDevice grabString:CFSTR("pcidebug") forService:service]) && property.length) {
                NSArray *bus = [[[property stringByReplacingOccurrencesOfString:@"(" withString:@":"] componentsSeparatedByString:@":"] valueForKey:@"integerValue"];
                [efi insertString:[NSString stringWithFormat:@"%08x%02x%02x", 0x01010600, [[bus objectAtIndex:2] intValue], [[bus objectAtIndex:1] intValue]] atIndex:0];
            }
            else if ((property = [pciDevice grabString:CFSTR("name") forService:service]).length) {
                unsigned pnp = 0;
                sscanf(property.UTF8String, "PNP%X", &pnp);
                if (!pnp) {
                    efi = nil;
                    break;
                }
                if (!(property = [pciDevice grabString:CFSTR("_UID") forService:service]).length) property = @"0";
                unsigned uid = property.intValue;
                [efi insertString:[NSString stringWithFormat:@"%08x%04x%04x%08x", 0x02010C00, 0xD041, CFSwapInt16HostToBig(pnp), CFSwapInt32HostToBig(uid)] atIndex:0];
                break;
            }
            io_service_t parent;
            IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent);
            IOObjectRelease(service);
            service = parent;
        }
        IOObjectRelease(service);
        if (!efi) return nil;
        for(NSString *property in obj.properties) {
            NSUInteger i = 0, j = property.length+1;
            [efi appendFormat:@"%08x", h64tob32(4+j*2)];
            const char *prop = property.UTF8String;
            while (i<j) [efi appendFormat:@"%02x00", prop[i++]];
            i = [self NumberSize:[obj.properties objectForKey:property]];//FIXME: other property types
            [efi appendFormat:@"%08x%0*llx", h64tob32(i+4), (int)i*2, CFSwapInt64HostToBig([[obj.properties objectForKey:property] longLongValue])>>(64-i*8)];
        }
        [str appendFormat:@"%08x%08x%@", h64tob32(8+efi.length/2), h64tob32(obj.properties.count), efi];
    }
    return [NSString stringWithFormat:@"%08x%@", h64tob32(4+str.length/2), str];
}
+(int)NumberSize:(NSNumber *)number {
    switch (number.objCType[0]) {
        case 'c':
            return sizeof(char);
        case 'i':
            return sizeof(int);
        case 's':
            return sizeof(short);
        case 'l':
            return sizeof(long);
        case 'q':
            return sizeof(long long);
        case 'f':
            return sizeof(float);
        case 'd':
            return sizeof(double);
        case 'C':
            return sizeof(unsigned char);
        case 'I':
            return sizeof(unsigned int);
        case 'S':
            return sizeof(unsigned short);
        case 'L':
            return sizeof(unsigned long);
        case 'Q':
            return sizeof(unsigned long long);
        default:
            return 0;
    }
}
@end

#pragma mark Formatter
@implementation hexFormatter
+(BOOL)allowsReverseTransformation{
    return false;
}
+(Class)transformedValueClass{
    return [NSString class];
}
-(id)transformedValue:(id)value{
    return [NSString stringWithFormat:@"%04lX", [(NSNumber *)value integerValue]];
}
@end
