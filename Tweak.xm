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
- (void)_updateSharedWallpaper;
- (void)_reconfigureBlurViewsForVariant:(NSUInteger)variant;
- (void)_updateBlurImagesForVariant:(NSUInteger)variant;
@end

@interface SBFStaticWallpaperView : UIView
- (instancetype)initWithFrame:(CGRect)frame wallpaperImage:(UIImage *)wallpaperImage;
- (UIImageView *)contentView;
- (void)setVariant:(NSUInteger)variant;
- (void)setZoomFactor:(float)zoomFactor;
@end

@interface _SBFakeBlurView : UIView
+ (UIImage *)_imageForStyle:(int *)style withSource:(SBFStaticWallpaperView *)source;
- (void)updateImageWithSource:(id)source;
- (void)reconfigureWithSource:(id)source;
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

@interface _NowPlayingArtView : UIView
@end

@interface SBLockScreenScrollView : UIScrollView
@end

@interface SBBlurryArtworkView : UIView
- (void)setArtworkImage:(UIImage *)image;
@end

@implementation SBBlurryArtworkView {
    /*UIToolbar *_blurView;*/
    SBFStaticWallpaperView *_wallpaperView;
    UIImageView *_imageView;

    UIImage *_artworkImage;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        _imageView = [[UIImageView alloc] initWithFrame:frame];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;
        [self addSubview:_imageView];
    }

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGRect bounds = self.bounds;
    _imageView.frame = bounds;
}

- (void)setZoomFactor:(float)zoomFactor andStyle:(int)style {
    SBWallpaperController *controller = [%c(SBWallpaperController) sharedInstance];
    _wallpaperView = [controller _newWallpaperViewForProcedural:nil orImage:_artworkImage];
    [_wallpaperView removeFromSuperview];
    // doesn't work yet, so use transform
    _wallpaperView.zoomFactor = zoomFactor;

    UIImage *blurredImage = [%c(_SBFakeBlurView) _imageForStyle:&style withSource:_wallpaperView];
    _imageView.image = blurredImage;

    _imageView.transform = CGAffineTransformScale(CGAffineTransformIdentity, zoomFactor, zoomFactor);
}

- (void)setArtworkImage:(UIImage *)artworkImage {
    _artworkImage = artworkImage;

    if (artworkImage == nil) {
        self.hidden = YES;
    }
    else {
        if (![artworkImage isKindOfClass:[UIImage class]]) {
            _artworkImage = nil;
            return;
        }

        SBWallpaperController *controller = [%c(SBWallpaperController) sharedInstance];
        _wallpaperView = [controller _newWallpaperViewForProcedural:nil orImage:artworkImage];
        [_wallpaperView removeFromSuperview];

        self.hidden = NO;

        // 0 No blur
        // 1 No blur
        // 2 Barely any blur
        // 3 blurred more than 4 (they're super close)
        // 4 blurred less than 3
        // 5 blurred less than 3 and 4
        // 6 really blurred, lighter, most commonly used
        // 7 blur? what's a blur? let's use black
        int style = 6;
        UIImage *blurredImage = [%c(_SBFakeBlurView) _imageForStyle:&style withSource:_wallpaperView];
        _imageView.image = blurredImage;
    }
}

@end

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
    _blurryArtworkView.artworkImage = artworkImage;
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

- (void)setArtworkView:(UIView *)view {
    %orig;
}

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

%new
+ (id)sharedInstance {
    return _blurryArtworkView;
}

%end

%end

%ctor {
    dlopen("/System/Library/SpringBoardPlugins/NowPlayingArtLockScreen.lockbundle/NowPlayingArtLockScreen", 2);
    %init(NowPlayingArtView);
}
