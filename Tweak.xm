//
//  Tweak.xm
//  BlurredLockscreenArtwork
//
//  Created by Adam Bell on 2014-01-02.
//  Copyright (c) 2014 Adam Bell. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

#include <dlfcn.h>

#define VARIANT_LOCKSCREEN 0
#define VARIANT_HOMESCREEN 1

@interface SBWallpaperController : NSObject
+ (instancetype)sharedInstance;

- (void)setLockscreenOnlyWallpaperAlpha:(float)alpha;
- (id)_newWallpaperViewForProcedural:(id)proceduralWallpaper orImage:(UIImage *)image;
- (id)_clearWallpaperView:(id *)wallpaperView;
- (void)_handleWallpaperChangedForVariant:(NSUInteger)variant;
- (void)_updateSeparateWallpaper;
- (void)_reconfigureBlurViewsForVariant:(NSUInteger)variant;
- (void)_updateBlurImagesForVariant:(NSUInteger)variant;
@end

@interface SBFStaticWallpaperView : UIView
- (instancetype)initWithFrame:(CGRect)frame wallpaperImage:(UIImage *)wallpaperImage;
- (UIImageView *)contentView;
- (void)setVariant:(NSUInteger)variant;
@end

@interface SBMediaController : NSObject
+ (instancetype)sharedInstance;

- (id)_nowPlayingInfo;
- (UIImage *)artwork;
- (NSUInteger)trackUniqueIdentifier;
- (BOOL)isPlaying;
@end

@interface SBUIController : NSObject
+ (instancetype)sharedInstance;

- (void)setLockscreenArtworkImage:(UIImage *)artworkImage;
- (void)updateLockscreenArtwork;
@end

%group NowPlayingArtView

static SBFStaticWallpaperView *_wallpaperView;
static UIImage *_artworkImage = nil;

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

    return controller;
}

%new
- (void)updateLockscreenArtwork {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^(){
        SBMediaController *mediaController = [%c(SBMediaController) sharedInstance];

        // Try to limit the number of times this needs to be run because it's expensive
        NSUInteger trackUniqueIdentifier = mediaController.trackUniqueIdentifier;
        if (trackUniqueIdentifier != _uniqueIdentifier || _artworkImage == nil) {
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
    // Clear wallpaper view except that explodes so not touching that for now [SBWallpaperController _clearWallpaperView:&wallpaperView];
    // Add New wallpaper
    // setVariant:0 ?
    // _handleWallpaperChangedForVariant:0 breaks

    SBWallpaperController *controller = [%c(SBWallpaperController) sharedInstance];

    id wallpaper = [controller valueForKeyPath:@"_lockscreenWallpaperView"];
    if (wallpaper != nil)
        [wallpaper removeFromSuperview];
    [controller setValue:nil forKeyPath:@"_lockscreenWallpaperView"];

    if (artworkImage != nil && [artworkImage isKindOfClass:[UIImage class]]) {
        CGImageRef image = CGImageCreateCopy(artworkImage.CGImage);
        UIImage *newImage = [UIImage imageWithCGImage:image scale:artworkImage.scale orientation:artworkImage.imageOrientation];
        artworkImage = newImage;

        _artworkImage = artworkImage;

        _wallpaperView = [controller _newWallpaperViewForProcedural:nil orImage:_artworkImage];
        [_wallpaperView setVariant:VARIANT_LOCKSCREEN];

        [controller setValue:_wallpaperView forKeyPath:@"_lockscreenWallpaperView"];
    }
    else {
        _wallpaperView = nil;
        [controller _updateSeparateWallpaper];
    }

    [controller _reconfigureBlurViewsForVariant:0];
    [controller _updateBlurImagesForVariant:0];
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

%hook SBWallpaperController

- (id)_wallpaperViewForVariant:(NSUInteger)variant {
    if (_artworkImage == nil || _wallpaperView == nil || variant == 1) {
        return %orig;
    }
    else {
        return _wallpaperView;
    }
}

%end

%end

%ctor {
    dlopen("/System/Library/SpringBoardPlugins/NowPlayingArtLockScreen.lockbundle/NowPlayingArtLockScreen", 2);
    %init(NowPlayingArtView);
}
