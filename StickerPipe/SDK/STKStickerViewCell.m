//
//  STKStickerPanelCell.m
//  StickerFactory
//
//  Created by Vadim Degterev on 07.07.15.
//  Copyright (c) 2015 908 Inc. All rights reserved.
//

#import "STKStickerViewCell.h"
#import "UIImageView+Stickers.h"
#import "UIImage+Tint.h"
#import "STKUtility.h"
#import <DFImageManagerKit.h>

@interface STKStickerViewCell()

@property (strong, nonatomic) UIImageView *stickerImageView;
@property (strong, nonatomic) DFImageTask *imageTask;

@end

@implementation STKStickerViewCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.stickerImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, 0.0, 80.0, 80.0)];
        self.stickerImageView.center = CGPointMake(self.contentView.bounds.size.width/2,self.contentView.bounds.size.height/2);
        self.stickerImageView.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:self.stickerImageView];
    }
    return self;
}

- (void)layoutSubviews {
    self.stickerImageView.center = CGPointMake(self.contentView.bounds.size.width/2,self.contentView.bounds.size.height/2);
}

- (void)prepareForReuse {
    [self.imageTask cancel];
    self.imageTask = nil;
    self.stickerImageView.image = nil;
}

- (void) configureWithStickerMessage:(NSString*)stickerMessage
                         placeholder:(UIImage*)placeholder
                    placeholderColor:(UIColor*)placeholderColor {
    UIImage *resultPlaceholder = placeholder ? placeholder : [UIImage imageNamed:@"StickerPanelPlaceholder"];
    
    UIColor *colorForPlaceholder = placeholderColor && !placeholder ? placeholderColor : [STKUtility defaultGrayColor];
    
    UIImage *coloredPlaceholder = [resultPlaceholder imageWithImageTintColor:colorForPlaceholder];
    
    NSURL *stickerUrl = [STKUtility imageUrlForStickerPanelWithMessage:stickerMessage];
    
    DFImageRequestOptions *options = [DFImageRequestOptions new];
    options.priority = DFImageRequestPriorityNormal;
    
    self.stickerImageView.image = coloredPlaceholder;
    [self setNeedsLayout];
    
    DFImageRequest *request = [DFImageRequest requestWithResource:stickerUrl targetSize:CGSizeZero contentMode:DFImageContentModeAspectFit options:options];
    
    __weak typeof(self) weakSelf = self;
    
    self.imageTask =[[DFImageManager sharedManager] imageTaskForRequest:request completion:^(UIImage *image, NSDictionary *info) {
        if (image) {
            weakSelf.stickerImageView.image = image;
            [weakSelf setNeedsLayout];
        } else {
            NSError *error = info[DFImageInfoErrorKey];
            if (error && error.code != -1) {
                STKLog(@"Failed loading from stickerView cell: %@", error.localizedDescription);
            }
        }
    }];
    
    [self.imageTask resume];
            
}

@end
