/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab

 This file is part of Nyxian.

 Licensed under the emexLabs Public Source License, version 1.1
 (EPSL 1.1).

 Private use and modification are permitted under the license.
 Redistribution of source or binaries, modified or unmodified,
 requires prior written permission from emexLabs.

 External deployment is subject to the source-availability
 requirements and other conditions of the license.

 Provided "AS IS", without warranty, to the extent permitted by law.

 See LICENSE for the full license terms.
*/

#import <UI/NXVolumeButtonMonitor.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <stdatomic.h>
#import <unistd.h>

typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;

typedef void (*IOHIDEventSystemClientEventCallback)(void *target, void *refcon, void *sender, IOHIDEventRef event);

extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern void IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef matching);
extern void IOHIDEventSystemClientRegisterEventCallback(IOHIDEventSystemClientRef client, IOHIDEventSystemClientEventCallback callback, void *target, void *refcon);
extern void IOHIDEventSystemClientScheduleWithDispatchQueue(IOHIDEventSystemClientRef client, dispatch_queue_t queue);

extern uint32_t IOHIDEventGetType(IOHIDEventRef event);
extern CFIndex IOHIDEventGetIntegerValue(IOHIDEventRef event, uint32_t field);

#define kIOHIDEventTypeKeyboard         3
#define IOHIDEventFieldBase(type)       ((type) << 16)
#define kNXFieldUsagePage               (IOHIDEventFieldBase(kIOHIDEventTypeKeyboard) | 0)
#define kNXFieldUsage                   (IOHIDEventFieldBase(kIOHIDEventTypeKeyboard) | 1)
#define kNXFieldDown                    (IOHIDEventFieldBase(kIOHIDEventTypeKeyboard) | 2)

#define kHIDPage_Consumer               0x0C
#define kHIDUsage_Csmr_VolumeIncrement  0xE9
#define kHIDUsage_Csmr_VolumeDecrement  0xEA

#define kNXPinEpsilon                   0.01f

static atomic_bool gArmed;
static atomic_bool gUpHeld, gDownHeld;
static atomic_bool gSawUp, gSawDown;
static atomic_int gSeenAny;

static UIWindow *NXKeyWindow(void)
{
    for(UIScene *scene in UIApplication.sharedApplication.connectedScenes)
    {
        if(![scene isKindOfClass:UIWindowScene.class])
        {
            continue;
        }
        for(UIWindow *w in ((UIWindowScene *)scene).windows)
        {
            if(w.isKeyWindow)
            {
                return w;
            }
        }
    }
    return nil;
}

static UISlider *NXFindSlider(UIView *view)
{
    for(UIView *sub in view.subviews)
    {
        if([sub isKindOfClass:UISlider.class])
        {
            return (UISlider *)sub;
        }
        UISlider *s = NXFindSlider(sub);
        if(s)
        {
            return s;
        }
    }
    return nil;
}

static void NXSetVolume(UISlider *slider,
                        float value)
{
    [slider setValue:value animated:NO];
    [slider sendActionsForControlEvents:UIControlEventValueChanged];
}

@interface NXVolumeButtonMonitor ()

@property (nonatomic, strong) MPVolumeView *volumeView;
@property (nonatomic, weak) UISlider *slider;
@property (nonatomic) float pinned;
@property (nonatomic) BOOL pinInstalled;
@property (atomic, copy) void (^eventHandler)(NSInteger button, NSString *kind);

+ (instancetype)shared;

@end

static bool gChordFired = false;
static bool gUpConsumed = false;
static bool gDnConsumed = false;
 
static void NXHIDCallback(void *target,
                          void *refcon,
                          void *sender,
                          IOHIDEventRef event)
{
    atomic_fetch_add(&gSeenAny, 1);
    
    if(event == NULL || IOHIDEventGetType(event) != kIOHIDEventTypeKeyboard)
    {
        return;
    }
    if(IOHIDEventGetIntegerValue(event, kNXFieldUsagePage) != kHIDPage_Consumer)
    {
        return;
    }
    
    CFIndex usage = IOHIDEventGetIntegerValue(event, kNXFieldUsage);
    if(usage != kHIDUsage_Csmr_VolumeIncrement && usage != kHIDUsage_Csmr_VolumeDecrement)
    {
        return;
    }
    
    if(!atomic_load(&gArmed))
    {
        return;
    }
    
    BOOL up = (usage == kHIDUsage_Csmr_VolumeIncrement);
    BOOL down = (IOHIDEventGetIntegerValue(event, kNXFieldDown) != 0);
    
    if(up)
    {
        atomic_store(&gUpHeld, down);
        if(down)
        {
            atomic_store(&gSawUp, true);
        }
    }
    else
    {
        atomic_store(&gDownHeld, down);
        if(down)
        {
            atomic_store(&gSawDown, true);
        }
    }
    
    void (^handler)(NSInteger button, NSString *kind) = NXVolumeButtonMonitor.shared.eventHandler;
    
    if(down)
    {
        if(atomic_load(&gUpHeld) && atomic_load(&gDownHeld) && !gChordFired)
        {
            gChordFired = true;
            gUpConsumed = true;
            gDnConsumed = true;
            
            if(handler)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    handler(0, @"select");
                });
            }
        }
        return;
    }
    
    BOOL consumed = up ? gUpConsumed : gDnConsumed;
    if(up)
    {
        gUpConsumed = false;
    }
    else
    {
        gDnConsumed = false;
    }
    
    if(!atomic_load(&gUpHeld) && !atomic_load(&gDownHeld))
    {
        gChordFired = false;
    }
    
    if(consumed)
    {
        return;
    }
    
    if(handler)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            handler(up ? 1 : 2, @"tap");
        });
    }
}

@implementation NXVolumeButtonMonitor

+ (instancetype)shared
{
    static NXVolumeButtonMonitor *inst;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        inst = [self new];
    });
    return inst;
}

+ (BOOL)start
{
    static dispatch_once_t once;
    static BOOL ok = NO;
    dispatch_once(&once, ^{
        IOHIDEventSystemClientRef client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
        if(client == NULL)
        {
            NSLog(@"NXVHM: IOHIDEventSystemClientCreate failed");
            return;
        }
        IOHIDEventSystemClientSetMatching(client, NULL);
        dispatch_queue_t q = dispatch_queue_create("org.emexlabs.nyxian.hidmon", DISPATCH_QUEUE_SERIAL);
        IOHIDEventSystemClientRegisterEventCallback(client, NXHIDCallback, NULL, NULL);
        IOHIDEventSystemClientScheduleWithDispatchQueue(client, q);
        ok = YES;
    });
    return ok;
}

- (void)ensurePinInstalled
{
    if(self.pinInstalled)
    {
        return;
    }
    
    dispatch_block_t work = ^{
        if(self.pinInstalled)
        {
            return;
        }
        
        AVAudioSession *s = AVAudioSession.sharedInstance;
        [s setCategory:AVAudioSessionCategoryAmbient withOptions:AVAudioSessionCategoryOptionMixWithOthers error:nil];
        [s setActive:YES error:nil];
        
        self.pinned = s.outputVolume;
        
        MPVolumeView *v = [[MPVolumeView alloc] initWithFrame:CGRectMake(-4000, -4000, 100, 40)];
        v.alpha = 0.01f;
        [NXKeyWindow() addSubview:v];
        self.volumeView = v;
        self.slider = NXFindSlider(v);
        
        [s addObserver:self forKeyPath:@"outputVolume" options:NSKeyValueObservingOptionNew context:NULL];
        
        self.pinInstalled = YES;
    };
    
    if(NSThread.isMainThread)
    {
        work();
    }
    else
    {
        dispatch_sync(dispatch_get_main_queue(), work);
    }
}

- (void)removePin
{
    if(!self.pinInstalled)
    {
        return;
    }
    
    dispatch_block_t work = ^{
        if(!self.pinInstalled)
        {
            return;
        }
        
        AVAudioSession *s = AVAudioSession.sharedInstance;
        @try
        {
            [s removeObserver:self forKeyPath:@"outputVolume"];
        }
        @catch(__unused NSException *e)
        {
            /* handle maybe? */
        }
        
        MPVolumeView *v = self.volumeView;
        self.slider = nil;
        self.volumeView = nil;
        self.pinInstalled = NO;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [v removeFromSuperview]; });
        
        [s setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    };
    
    if(NSThread.isMainThread)
    {
        work();
    }
    else
    {
        dispatch_sync(dispatch_get_main_queue(), work);
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if(![keyPath isEqualToString:@"outputVolume"])
    {
        return;
    }
    if(!atomic_load(&gArmed))
    {
        return;
    }
    
    float v = [change[NSKeyValueChangeNewKey] floatValue];
    if(fabsf(v - self.pinned) < kNXPinEpsilon)
    {
        return;
    }
    
    UISlider *slider = self.slider;
    if(slider)
    {
        float target = self.pinned;
        dispatch_async(dispatch_get_main_queue(), ^{
            NXSetVolume(slider, target);
        });
    }
}

+ (void)armWithHandler:(void (^)(NSInteger button, NSString *kind))handler
{
    NXVolumeButtonMonitor *m = [self shared];
    m.eventHandler = handler;
    
    if(handler)
    {
        [self start];
        [m ensurePinInstalled];
        atomic_store(&gUpHeld, false);
        atomic_store(&gDownHeld, false);
        atomic_store(&gSawUp, false);
        atomic_store(&gSawDown, false);
        atomic_store(&gArmed, true);
    }
    else
    {
        atomic_store(&gArmed, false);
        atomic_store(&gUpHeld, false);
        atomic_store(&gDownHeld, false);
        [m removePin];
    }
}

+ (void)arm
{
    [self start];
    [[self shared] ensurePinInstalled];
    atomic_store(&gUpHeld, false);
    atomic_store(&gDownHeld, false);
    atomic_store(&gSawUp, false);
    atomic_store(&gSawDown, false);
    atomic_store(&gArmed, true);
}

+ (void)disarm
{
    atomic_store(&gArmed, false);
    atomic_store(&gUpHeld, false);
    atomic_store(&gDownHeld, false);
    [[self shared] removePin];
}

+ (BOOL)everReceivedEvent
{
    return atomic_load(&gSeenAny) > 0;
}

+ (NSInteger)scanFor:(double)seconds
{
    [self arm];
    
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while(deadline.timeIntervalSinceNow > 0)
    {
        if(atomic_load(&gUpHeld) && atomic_load(&gDownHeld))
        {
            return 3;
        }
        if(atomic_load(&gSawUp)  && atomic_load(&gSawDown))
        {
            return 3;
        }
        usleep(5000);
    }
    
    if(atomic_load(&gSawDown))
    {
        return 2;
    }
    if(atomic_load(&gSawUp))
    {
        return 1;
    }
    return 0;
}

@end
