#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioServices.h>
#include <IOKit/hid/IOHIDEventSystem.h>
#include <IOKit/hid/IOHIDEventSystemClient.h>
#include <stdio.h>
#include <dlfcn.h>

int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
CFArrayRef IOHIDEventSystemClientCopyServices(IOHIDEventSystemClientRef, int);
typedef struct __IOHIDServiceClient * IOHIDServiceClientRef;
int IOHIDServiceClientSetProperty(IOHIDServiceClientRef, CFStringRef, CFNumberRef);
typedef void* (*clientCreatePointer)(const CFAllocatorRef);
extern "C" void BKSHIDServicesCancelTouchesOnMainDisplay();

struct rawTouch {
    float density;
    float radius;
    float quality;
} lastTouch;

BOOL hasIncreasedByPercent(float percent, float value1, float value2) {

    if (value1 <= 0 || value2 <= 0)
        return NO;
    if (value1 >= value2 + (value2 / percent))
        return YES;
    return NO;
}

void touch_event(void* target, void* refcon, IOHIDServiceRef service, IOHIDEventRef event) {

    if (IOHIDEventGetType(event) == kIOHIDEventTypeDigitizer) {

        //get child events (individual finger)
        NSArray *children = (NSArray *)IOHIDEventGetChildren(event);
        if ([children count] == 1) { //single touch

            struct rawTouch touch;

            touch.density = IOHIDEventGetFloatValue((__IOHIDEvent *)children[0], (IOHIDEventField)kIOHIDEventFieldDigitizerDensity);
            touch.radius = IOHIDEventGetFloatValue((__IOHIDEvent *)children[0], (IOHIDEventField)kIOHIDEventFieldDigitizerMajorRadius);
            touch.quality = IOHIDEventGetFloatValue((__IOHIDEvent *)children[0], (IOHIDEventField)kIOHIDEventFieldDigitizerQuality);

            if (hasIncreasedByPercent(10, touch.density, lastTouch.density) && hasIncreasedByPercent(5, touch.radius, lastTouch.radius) && hasIncreasedByPercent(5, touch.quality, lastTouch.quality)) {
                
                NSLog(@"Force touch");
                BKSHIDServicesCancelTouchesOnMainDisplay();
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            }

            lastTouch = touch;
        }
    }
}

%ctor {

	clientCreatePointer clientCreate;
    void *handle = dlopen(0, 9);
    *(void**)(&clientCreate) = dlsym(handle,"IOHIDEventSystemClientCreate");
    IOHIDEventSystemClientRef ioHIDEventSystem = (__IOHIDEventSystemClient *)clientCreate(kCFAllocatorDefault);
    IOHIDEventSystemClientScheduleWithRunLoop(ioHIDEventSystem, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    IOHIDEventSystemClientRegisterEventCallback(ioHIDEventSystem, (IOHIDEventSystemClientEventCallback)touch_event, NULL, NULL);

}