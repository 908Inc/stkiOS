//
//  STKStickersDataModel.m
//  StickerFactory
//
//  Created by Vadim Degterev on 08.07.15.
//  Copyright (c) 2015 908 Inc. All rights reserved.
//

#import "STKStickersCache.h"
#import <CoreData/CoreData.h>
#import "NSManagedObjectContext+STKAdditions.h"
#import "NSManagedObject+STKAdditions.h"
#import "STKStickerPack.h"
#import "STKStickerObject.h"
#import "STKStickerPackObject.h"
#import "STKSticker.h"
#import "STKAnalyticService.h"
#import "STKUtility.h"
#import "STKStickersNotificationConstants.h"



@interface STKStickersCache()

@property (strong, nonatomic) NSManagedObjectContext *backgroundContext;
@property (strong, nonatomic) NSManagedObjectContext *mainContext;

@end

@implementation STKStickersCache

- (instancetype)init
{
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didUpdateStorage:) name:NSManagedObjectContextDidSaveNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didUpdateStorage:(NSNotification*) notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:STKStickersCacheDidUpdateStickersNotification object:nil];
    });

}

- (void) saveStickerPacks:(NSArray *)stickerPacks {
    
    __weak typeof(self) weakSelf = self;
    
    [self.backgroundContext performBlock:^{
//        NSArray *packIDs = [stickerPacks valueForKeyPath:@"@unionOfObjects.packID"];
//        
//        NSFetchRequest *requestForDelete = [NSFetchRequest fetchRequestWithEntityName:[STKStickerPack entityName]];
//        requestForDelete.predicate = [NSPredicate predicateWithFormat:@"NOT (%K in %@)", STKStickerPackAttributes.packID, packIDs];
//        
//        NSArray *objectsForDelete = [weakSelf.backgroundContext executeFetchRequest:requestForDelete error:nil];
//        
//        for (STKStickerPack *pack in objectsForDelete) {
//            [self.backgroundContext deleteObject:pack];
//        }
        for (STKStickerPackObject *object in stickerPacks) {
            STKStickerPack *stickerPack = [weakSelf stickerPackModelWithID:object.packID context:weakSelf.backgroundContext];
            stickerPack.artist = object.artist;
            stickerPack.packName = object.packName;
            stickerPack.packID = object.packID;
            stickerPack.price = object.price;
            stickerPack.packTitle = object.packTitle;
            stickerPack.packDescription = object.packDescription;
            if (object.order) {
                stickerPack.order = object.order;
            }
            
            for (STKStickerObject *stickerObject in object.stickers) {
                STKSticker *sticker = [weakSelf stickerModelWithID:stickerObject.stickerID context:weakSelf.backgroundContext];
                sticker.stickerName = stickerObject.stickerName;
                sticker.stickerID = stickerObject.stickerID;
                sticker.stickerMessage = stickerObject.stickerMessage;
                sticker.usedCount = stickerObject.usedCount;
                if (sticker) {
                    [stickerPack addStickersObject:sticker];
                }
            }
            
        }
        [weakSelf.backgroundContext save:nil];
    }];
}

- (void)deleteStickerPacks:(NSArray *)stickerPacks {
    
    __weak typeof(self) weakSelf = self;
    
    [self.mainContext performBlockAndWait:^{
        NSArray *packIDs = [stickerPacks valueForKeyPath:@"@unionOfObjects.packID"];
        
        NSFetchRequest *requestForDelete = [NSFetchRequest fetchRequestWithEntityName:[STKStickerPack entityName]];
        requestForDelete.predicate = [NSPredicate predicateWithFormat:@"%K in %@", STKStickerPackAttributes.packID, packIDs];
        
        NSArray *objectsForDelete = [weakSelf.mainContext executeFetchRequest:requestForDelete error:nil];
        
        for (STKStickerPack *pack in objectsForDelete) {
            [weakSelf.mainContext deleteObject:pack];
        }
        [weakSelf.mainContext save:nil];
    }];
    
}


- (void)saveDisabledStickerPack:(STKStickerPackObject *)stickerPack {
    
    STKStickerPack *stickerModel = [self stickerModelFormStickerObject:stickerPack context:self.backgroundContext];
    stickerModel.disabled = @(YES);
    
    for (STKStickerObject *stickerObject in stickerPack.stickers) {
        STKSticker *sticker = [self stickerModelWithID:stickerObject.stickerID context:self.backgroundContext];
        sticker.stickerName = stickerObject.stickerName;
        sticker.stickerID = stickerObject.stickerID;
        sticker.stickerMessage = stickerObject.stickerMessage;
        sticker.usedCount = stickerObject.usedCount;
        if (sticker) {
            [stickerModel addStickersObject:sticker];
        }
    }
    
    [self.backgroundContext save:nil];
}

- (void)markStickerPack:(STKStickerPackObject *)pack disabled:(BOOL)disabled {
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", STKStickerPackAttributes.packID, pack.packID];
    STKStickerPack *stickerPack = [STKStickerPack stk_findWithPredicate:predicate sortDescriptors:nil fetchLimit:1 context:self.mainContext].firstObject;
    
    stickerPack.disabled = @(disabled);
    
    [self.mainContext save:nil];
}

#pragma mark - NewItems

- (STKStickerPack*)stickerModelFormStickerObject:(STKStickerPackObject*)stickerPackObject
                                         context:(NSManagedObjectContext*)context {
    
    STKStickerPack *stickerPack = [self stickerPackModelWithID:stickerPackObject.packID context:context];
    stickerPack.artist = stickerPackObject.artist;
    stickerPack.packName = stickerPackObject.packName;
    stickerPack.packID = stickerPackObject.packID;
    stickerPack.price = stickerPackObject.price;
    stickerPack.packTitle = stickerPackObject.packTitle;
    stickerPack.packDescription = stickerPackObject.packDescription;
    stickerPack.disabled = stickerPackObject.disabled;
    return stickerPack;
}


- (STKSticker*)stickerModelWithID:(NSNumber*)stickerID context:(NSManagedObjectContext*)context
{
    STKSticker *sticker = [STKSticker stk_objectWithUniqueAttribute:STKStickerAttributes.stickerID value:stickerID context:context];
    return sticker;
}

- (STKStickerPack*)stickerPackModelWithID:(NSNumber*)packID context:(NSManagedObjectContext*)context
{
    STKStickerPack *stickerPack = [STKStickerPack stk_objectWithUniqueAttribute:STKStickerPackAttributes.packID value:packID context:context];
    return stickerPack;
}

- (void)getStickerPacksIgnoringRecent:(void (^)(NSArray *))response {
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@ OR %K == nil", STKStickerPackAttributes.disabled, @NO, STKStickerPackAttributes.disabled];
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:STKStickerPackAttributes.order ascending:YES];
    NSArray *stickerPacks = [STKStickerPack stk_findWithPredicate:predicate sortDescriptors:@[sortDescriptor] context:self.backgroundContext];
    
    NSMutableArray *result = [NSMutableArray array];
    
    for (STKStickerPack *pack in stickerPacks) {
        STKStickerPackObject *stickerPackObject = [[STKStickerPackObject alloc] initWithStickerPack:pack];
        if (stickerPackObject) {
            [result addObject:stickerPackObject];
        }
    }
    if (response) {
        dispatch_async(dispatch_get_main_queue(), ^{
            response(result);
        });
    }
    
}



- (void) getStickerPacks:(void(^)(NSArray *stickerPacks))response {
    
    __weak typeof(self) weakSelf = self;
    
    STKStickerPackObject *recentPack = [weakSelf recentStickerPack];
    
    NSMutableArray *result = [NSMutableArray array];
    
    [weakSelf getStickerPacksIgnoringRecent:^(NSArray *stickerPacks) {
        
        if (recentPack) {
            [result insertObject:recentPack atIndex:0];
            [result addObjectsFromArray:stickerPacks];
        }
        if (response) {
            response(result);
        }
        
    }];

}

- (STKStickerPackObject*)recentStickerPack {
    
     __block STKStickerPackObject *object = nil;
    [self.backgroundContext performBlockAndWait:^{
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K > 0 AND (%K.%K == NO OR %K.%K == nil)", STKStickerAttributes.usedCount, STKStickerRelationships.stickerPack, STKStickerPackAttributes.disabled,STKStickerRelationships.stickerPack, STKStickerPackAttributes.disabled];
        
        NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:STKStickerAttributes.usedCount
                                                                         ascending:YES];
        
        NSArray *stickers = [STKSticker stk_findWithPredicate:predicate
                                              sortDescriptors:@[sortDescriptor]
                                                   fetchLimit:12
                                                      context:self.backgroundContext];
        
            STKStickerPackObject *recentPack = [STKStickerPackObject new];
            recentPack.packName = @"Recent";
            recentPack.packTitle = @"Recent";
            NSMutableArray *stickerObjects = [NSMutableArray new];
            for (STKSticker *sticker in stickers) {
                STKStickerObject *stickerObject = [[STKStickerObject alloc] initWithSticker:sticker];
                if (stickerObject) {
                    [stickerObjects addObject:stickerObject];

                }
            }
            NSArray *sortedRecentStickers = [stickerObjects sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:STKStickerAttributes.usedCount ascending:NO]]];
            recentPack.stickers = sortedRecentStickers;
            
            object = recentPack;
    }];

    
    return object;
}

- (void)incrementUsedCountWithStickerID:(NSNumber *)stickerID {
    
        __weak typeof(self) weakSelf = self;
    [self.backgroundContext performBlock:^{
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@",STKStickerAttributes.stickerID , stickerID];
        NSArray *stickers = [STKSticker stk_findWithPredicate:predicate sortDescriptors:nil fetchLimit:1 context:self.backgroundContext];
        STKSticker *sticker = stickers.firstObject;
        NSArray *trimmedPackNameAndStickerName = [STKUtility trimmedPackNameAndStickerNameWithMessage:sticker.stickerMessage];

        NSInteger usedCount = [sticker.usedCount integerValue];
        usedCount++;
        sticker.usedCount = @(usedCount);
        
        [[STKAnalyticService sharedService] sendEventWithCategory:STKAnalyticStickerCategory action:trimmedPackNameAndStickerName.firstObject label:sticker.stickerName value:nil];
        
        [weakSelf.backgroundContext save:nil];
        
    }];
}

- (BOOL)isStickerPackDownloaded:(NSString*)packName {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@ AND (%K == NO OR %K == nil)", STKStickerPackAttributes.packName, packName, STKStickerPackAttributes.disabled, STKStickerPackAttributes.disabled];
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:[STKStickerPack entityName]];
    request.predicate = predicate;
    request.fetchLimit = 1;
    NSInteger count = [self.mainContext countForFetchRequest:request error:nil];
    BOOL downloaded = count > 0;
    return downloaded;
}

- (STKStickerPackObject *)getStickerPackWithPackName:(NSString *)packName {
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", STKStickerPackAttributes.packName, packName];
    
    STKStickerPack *stickerPack = [[STKStickerPack stk_findWithPredicate:predicate sortDescriptors:nil fetchLimit:1 context:self.mainContext] firstObject];
    if (stickerPack) {
        STKStickerPackObject *object = [[STKStickerPackObject alloc] initWithStickerPack:stickerPack];
        return object;
    } else {
        return nil;
    }
}


#pragma mark - Properties

- (NSManagedObjectContext *)mainContext {
    if (!_mainContext) {
        _mainContext = [NSManagedObjectContext stk_defaultContext];
    }
    return _mainContext;
}

- (NSManagedObjectContext *)backgroundContext {
    if (!_backgroundContext) {
        _backgroundContext = [NSManagedObjectContext stk_backgroundContext];
    }
    return _backgroundContext;
}

@end
