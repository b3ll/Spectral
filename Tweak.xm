//
//  Tweak.xm
//  Spectral
//
//  Created by Adam Bell on 2014-01-02.
//  Copyright (c) 2014 Adam Bell. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>

#import "PrivateHeaders.h"
#import "SBBlurryArtworkView.h"

#include <dlfcn.h>

#define PREFERENCES_PATH @"/User/Library/Preferences/ca.adambell.spectral.plist"
#define PREFERENCES_CHANGED_NOTIFICATION "ca.adambell.spectral.preferences-changed"
#define PREFERENCES_ENABLED_KEY @"spectralEnabled"

%group NowPlayingArtView

static SBBlurryArtworkView *_blurryArtworkView = nil;

static NSDictionary *_preferences = nil;

// Some apps are weird and set the now playing info a billion times a second... this tries to avoid that
static NSData *_artworkData;

%hook NowPlayingArtPluginController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    [[%c(SBUIController) sharedInstance] updateLockscreenArtwork];
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    [[%c(SBUIController) sharedInstance] updateLockscreenArtwork];
}
%end

%hook SBUIController
- (id)init {
    SBUIController *controller = %orig;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(currentSongChanged:)
                                                 name:@"SBMediaNowPlayingChangedNotification"
                                               object:nil];

    _blurryArtworkView = [[SBBlurryArtworkView alloc] initWithFrame:CGRectZero];

    return controller;
}

%new
- (void)updateLockscreenArtwork {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^(){
        SBMediaController *mediaController = [%c(SBMediaController) sharedInstance];

        //TODO: Try to limit the number of times this needs to be run because it's expensive
        NSData *artworkData = [[mediaController _nowPlayingInfo] valueForKey:@"artworkData"];
        if (artworkData == _artworkData) {
            return;
        }
        _artworkData = artworkData;

        UIImage *artwork = mediaController.artwork;
        self.lockscreenArtworkImage = artwork;
    }];
}

%new
- (void)currentSongChanged:(NSNotification *)notification {
    [self updateLockscreenArtwork];
}

%new
- (void)blurryArtworkPreferencesChanged {
    NSDictionary *prefs = [[NSDictionary alloc] initWithContentsOfFile:PREFERENCES_PATH];
    BOOL enabled = [[prefs valueForKey:PREFERENCES_ENABLED_KEY] boolValue];

    _blurryArtworkView.hidden = !enabled;
}

%new
- (void)setLockscreenArtworkImage:(UIImage *)artworkImage {
    _blurryArtworkView.artworkImage = artworkImage;
}

%new
- (SBBlurryArtworkView *)blurryArtworkView {
    return _blurryArtworkView;
}

// Fix for the original lockscreen wallpaper not showing when locked and paused
- (void)cleanUpOnFrontLocked {
    %orig;

    SBMediaController *mediaController = [%c(SBMediaController) sharedInstance];
    if (!mediaController.isPlaying) {
        self.lockscreenArtworkImage = nil;
    }
}

%end

%hook _NowPlayingArtView

- (void)layoutSubviews {
    %orig;

    _blurryArtworkView.frame = [UIScreen mainScreen].bounds;

// Hack to find the SBLockScreenScrollView and use it as a reference point
// ...don't ever use this in shipping code :P

    SBLockScreenScrollView *scrollView = nil;
    UIView *superview = self.superview;
    Class SBLockScreenScrollViewClass = %c(SBLockScreenScrollView);
    while (scrollView == nil) {
        for (UIView *subview in superview.subviews) {
            if ([subview isKindOfClass:SBLockScreenScrollViewClass])
                scrollView = (SBLockScreenScrollView *)subview;
        }

        superview = superview.superview;
        if (superview == nil)
            break;
    }

    if (_blurryArtworkView.superview != nil)
        [_blurryArtworkView removeFromSuperview];
    if (scrollView != nil)
        [scrollView.superview insertSubview:_blurryArtworkView belowSubview:scrollView];
}

%end

%end

static void PreferencesChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    _preferences = [[NSDictionary alloc] initWithContentsOfFile:PREFERENCES_PATH];

    [[%c(SBUIController) sharedInstance] blurryArtworkPreferencesChanged];
}

%ctor {
    dlopen("/System/Library/SpringBoardPlugins/NowPlayingArtLockScreen.lockbundle/NowPlayingArtLockScreen", 2);

    _preferences = [[NSDictionary alloc] initWithContentsOfFile:PREFERENCES_PATH];
    if (_preferences == nil) {
        _preferences = @{ PREFERENCES_ENABLED_KEY : @(YES) };
        [_preferences writeToFile:PREFERENCES_PATH atomically:YES];
    }

    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, PreferencesChangedCallback, CFSTR(PREFERENCES_CHANGED_NOTIFICATION), NULL, CFNotificationSuspensionBehaviorCoalesce);

    %init(NowPlayingArtView);
}
