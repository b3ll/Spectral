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

@interface SpringBoard : NSObject
- (void)setLockscreenArtworkImage:(UIImage *)artworkImage;
@end

%group NowPlayingArtView

static SBFStaticWallpaperView *_wallpaperView;
static UIImage *_artworkImage = nil;

%hook SpringBoard
- (void)applicationDidFinishLaunching:(BOOL)finished {
    %orig;

    MPNowPlayingInfoCenter *infoCenter = [MPNowPlayingInfoCenter defaultCenter];
    [infoCenter addObserver:self
                 forKeyPath:@"_nowPlayingInfo"
                    options:NSKeyValueObservingOptionNew
                    context:NULL];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(currentSongChanged:)
                                                 name:MPMusicPlayerControllerNowPlayingItemDidChangeNotification
                                               object:nil];
    [[MPMusicPlayerController iPodMusicPlayer] beginGeneratingPlaybackNotifications];
}

%new
- (void)currentSongChanged:(NSNotification *)notification {
    MPMusicPlayerController *iPodMusicPlayer = [MPMusicPlayerController iPodMusicPlayer];
    UIImage *artworkImage = [[iPodMusicPlayer.nowPlayingItem valueForProperty:MPMediaItemPropertyArtwork] imageWithSize:CGSizeMake(512.0, 512.0)];
    self.lockscreenArtworkImage = artworkImage;
}

%new
- (void)observeValueForKeyPath:(NSString *)path ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([path isEqualToString:@"_nowPlayingInfo"]) {
        NSDictionary *nowPlayingInfo = [change objectForKey:NSKeyValueChangeNewKey];
        UIImage *artworkImage = [nowPlayingInfo[MPMediaItemPropertyArtwork] imageWithSize:CGSizeMake(512.0, 512.0)];
        self.lockscreenArtworkImage = artworkImage;
    }
}

%new
- (void)setLockscreenArtworkImage:(UIImage *)artworkImage {
    // clear wallpaper view except that explodes so not touching that for now [SBWallpaperController _clearWallpaperView:&wallpaperView];
    // new wallpaper
    // setVariant:0 ?
    // _handleWallpaperChangedForVariant:0

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
    %init(NowPlayingArtView);
}
