//
//  SBBlurryArtworkView.h
//  Spectral
//
//  Created by Adam Bell on 2014-01-03.
//  Copyright (c) 2014 Adam Bell. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

@interface SBBlurryArtworkView : UIView
- (void)setArtworkImage:(UIImage *)image;
- (UIImage *)artworkImage;
@end
