//
//  UIImage+CustomBundle.m
//  MyWorkFramework
//
//  Created by Alexander908 on 6/2/16.
//  Copyright © 2016 Alexander908. All rights reserved.
//

#import "UIImage+CustomBundle.h"
#import "STKSticker+CoreDataClass.h"

@implementation UIImage (CustomBundle)

+ (UIImage*)imageNamedInCustomBundle: (NSString*)name {
    // TODO: check, if works for pods
    if ([UIImage respondsToSelector: @selector(imageNamed:inBundle:compatibleWithTraitCollection:)]) {
        return [UIImage imageNamed: name inBundle: [NSBundle bundleForClass: STKSticker.class] compatibleWithTraitCollection: nil];
    } else {
        return [UIImage imageNamed: name];
    }
}

@end
