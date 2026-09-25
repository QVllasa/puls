#include "CSystem.h"

// Private, aber seit Jahren stabile IOKit-Funktionen (IOHIDEventSystemClient).
typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDServiceClient *IOHIDServiceClientRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;

extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
extern CFArrayRef IOHIDEventSystemClientCopyServices(IOHIDEventSystemClientRef client);
extern IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef service, int64_t type, int32_t options, int64_t timestamp);
extern CFTypeRef IOHIDServiceClientCopyProperty(IOHIDServiceClientRef service, CFStringRef property);
extern double IOHIDEventGetFloatValue(IOHIDEventRef event, int32_t field);

#define kIOHIDEventTypeTemperature 15
#define IOHIDEventFieldBase(type) ((type) << 16)

static IOHIDEventSystemClientRef sharedClient(void) {
    static IOHIDEventSystemClientRef client = NULL;
    if (client) return client;
    client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    if (!client) return NULL;

    int page = 0xff00, usage = 5; // AppleVendor / TemperatureSensor
    CFNumberRef pageNum = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &page);
    CFNumberRef usageNum = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &usage);
    const void *keys[] = { CFSTR("PrimaryUsagePage"), CFSTR("PrimaryUsage") };
    const void *values[] = { pageNum, usageNum };
    CFDictionaryRef match = CFDictionaryCreate(kCFAllocatorDefault, keys, values, 2,
                                               &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    IOHIDEventSystemClientSetMatching(client, match);
    CFRelease(match);
    CFRelease(pageNum);
    CFRelease(usageNum);
    return client;
}

CFDictionaryRef hid_copy_temperatures(void) {
    IOHIDEventSystemClientRef client = sharedClient();
    if (!client) return NULL;

    CFArrayRef services = IOHIDEventSystemClientCopyServices(client);
    if (!services) return NULL;

    CFMutableDictionaryRef result = CFDictionaryCreateMutable(kCFAllocatorDefault, 0,
                                                              &kCFTypeDictionaryKeyCallBacks,
                                                              &kCFTypeDictionaryValueCallBacks);
    CFIndex count = CFArrayGetCount(services);
    for (CFIndex i = 0; i < count; i++) {
        IOHIDServiceClientRef service = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(services, i);
        CFTypeRef name = IOHIDServiceClientCopyProperty(service, CFSTR("Product"));
        if (!name) continue;
        if (CFGetTypeID(name) != CFStringGetTypeID()) { CFRelease(name); continue; }

        IOHIDEventRef event = IOHIDServiceClientCopyEvent(service, kIOHIDEventTypeTemperature, 0, 0);
        if (event) {
            double value = IOHIDEventGetFloatValue(event, IOHIDEventFieldBase(kIOHIDEventTypeTemperature));
            if (value > -40 && value < 150) {
                CFNumberRef num = CFNumberCreate(kCFAllocatorDefault, kCFNumberDoubleType, &value);
                CFDictionarySetValue(result, name, num);
                CFRelease(num);
            }
            CFRelease(event);
        }
        CFRelease(name);
    }
    CFRelease(services);
    return result;
}
