//
//  Tweak.xm
//  BlurredLockscreenArtwork
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

%group NowPlayingArtView

static SBBlurryArtworkView *_blurryArtworkView = nil;

static NSUInteger _uniqueIdentifier = 0;

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

        // Try to limit the number of times this needs to be run because it's expensive
        NSUInteger trackUniqueIdentifier = mediaController.trackUniqueIdentifier;
        if (trackUniqueIdentifier != _uniqueIdentifier || _blurryArtworkView.artworkImage == nil) {
            _uniqueIdentifier = trackUniqueIdentifier;

            UIImage *artwork = mediaController.artwork;
            self.lockscreenArtworkImage = artwork;
        }
    }];
}

%new
- (void)currentSongChanged:(NSNotification *)notification {
    [self updateLockscreenArtwork];
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
    [scrollView.superview insertSubview:_blurryArtworkView belowSubview:scrollView];
}

%end

%end

%ctor {
    dlopen("/System/Library/SpringBoardPlugins/NowPlayingArtLockScreen.lockbundle/NowPlayingArtLockScreen", 2);
    %init(NowPlayingArtView);
}
