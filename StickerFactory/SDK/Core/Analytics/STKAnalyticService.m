//
//  STKAnalyticService.m
//  StickerFactory
//
//  Created by Vadim Degterev on 30.06.15.
//  Copyright (c) 2015 908 Inc. All rights reserved.
//

#import "STKAnalyticService.h"
#import <UIKit/UIKit.h>
#import "STKStatistic.h"
#import "NSManagedObjectContext+STKAdditions.h"
#import "STKAnalyticsAPIClient.h"
#import "NSManagedObject+STKAdditions.h"

//Categories
NSString *const STKAnalyticMessageCategory = @"message";

//Actions
NSString *const STKAnalyticActionCheck = @"check";


static const NSInteger kMemoryCacheObjectsCount = 20;

@interface STKAnalyticService()

@property (assign, nonatomic) NSInteger objectCounter;
@property (strong, nonatomic) NSManagedObjectContext *backgroundContext;
@property (strong, nonatomic) STKAnalyticsAPIClient *analyticsApiClient;

@end

@implementation STKAnalyticService

#pragma mark - Init

+ (instancetype) sharedService {
    static STKAnalyticService *service = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        service = [[STKAnalyticService alloc] init];
    });
    return service;
}


- (instancetype)init
{
    self = [super init];
    if (self) {
        
        self.analyticsApiClient = [STKAnalyticsAPIClient new];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillResignActive:)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillTerminateNotification:)
                                                     name:UIApplicationWillTerminateNotification object:nil];
        
    }
    return self;
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
}

#pragma mark - Events

- (void)sendEventWithCategory:(NSString*)category
                       action:(NSString*)action
                        label:(NSString*)label
                        value:(NSInteger)value
{
    
    __weak typeof(self) weakSelf = self;
    [self.backgroundContext performBlock:^{
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:[STKStatistic entityName]];
        request.fetchLimit = 1;
        
        NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:STKStatisticAttributes.label ascending:YES];
        request.sortDescriptors = @[sortDescriptor];
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"label == %@", label];
        request.predicate = predicate;
        
        NSArray *objects = [weakSelf.backgroundContext executeFetchRequest:request error:nil];
        
        if (objects.count > 0) {
            STKStatistic *fetchedStatistic = objects.firstObject;
            NSInteger tempValue = fetchedStatistic.value.integerValue;
            tempValue += value;
            fetchedStatistic.value = @(tempValue);
        } else {
            STKStatistic *statistic = [NSEntityDescription insertNewObjectForEntityForName:[STKStatistic entityName] inManagedObjectContext:weakSelf.backgroundContext];
            statistic.category = category;
            statistic.action = action;
            statistic.label = label;
            statistic.time = [NSDate date];
            statistic.value = @(value);
        }
        
        NSError *error = nil;
        weakSelf.objectCounter++;
        if (weakSelf.objectCounter == kMemoryCacheObjectsCount) {
            [weakSelf.backgroundContext save:&error];
            weakSelf.objectCounter = 0;
        }
    }];
    
}



#pragma mark - Notifications

- (void)applicationWillResignActive:(NSNotification*) notification {
    
    [self sendEventsFromDatabase];
    
}

- (void) applicationWillTerminateNotification:(NSNotification*) notification {
    
    [self sendEventsFromDatabase];
    
}

#pragma mark - Sending

- (void) sendEventsFromDatabase {
    
    __weak typeof(self) weakSelf = self;

    if (self.backgroundContext.hasChanges) {
        [self.backgroundContext performBlockAndWait:^{
            NSError *error = nil;
            [weakSelf.backgroundContext save:&error];
        }];
    }
    
    NSArray *events = [STKStatistic stk_findAllInContext:self.backgroundContext];
    
    [self.analyticsApiClient sendStatistics:events success:^(id response) {
        
        for (id object in events) {
            [weakSelf.backgroundContext deleteObject:object];
        }
        
    } failure:^(NSError *error) {
        
        NSLog(@"Failed to send events");
        
    }];
    
}


#pragma mark - Properties

- (NSManagedObjectContext *)backgroundContext {
    if (!_backgroundContext) {
        _backgroundContext = [NSManagedObjectContext stk_backgroundContext];
    }
    return _backgroundContext;
}


@end
