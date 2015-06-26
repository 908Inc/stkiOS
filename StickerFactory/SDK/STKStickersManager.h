//
//  STKStickersClient.h
//  StickerFactory
//
//  Created by Vadim Degterev on 25.06.15.
//  Copyright (c) 2015 908. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


@interface STKStickersManager : NSObject

- (void) getStickerForMessage:(NSString*) message
                     progress:(void(^)(NSInteger receivedSize, NSInteger expectedSize)) progress
                      success:(void(^)(UIImage *sticker))success
                      failure:(void(^)(NSError *error, NSString *errorMessage)) failure;



+ (BOOL) isStickerMessage:(NSString*) message;



@end
