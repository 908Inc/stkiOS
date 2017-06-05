//
// Created by vlad on 7/27/16.
// Copyright (c) 2016 908 Inc. All rights reserved.
//

#import <SDWebImage/SDWebImageDownloader.h>

#import "STKWebserviceManager.h"
#import "AFHTTPSessionManager.h"
#import "STKStickersManager.h"
#import "STKUUIDManager.h"
#import "STKApiKeyManager.h"
#import "STKStickersConstants.h"
#import "STKSearchModel.h"
#import "STKUtility.h"
#import "STKStatistic+CoreDataProperties.h"
#import "helper.h"


@protocol KeyValueHTTP <NSObject>
- (void)setValue: (NSString*)value forHTTPHeaderField: (NSString*)field;
@end

@interface AFJSONRequestSerializer (KeyValueHTTP) <KeyValueHTTP>
@end

@interface SDWebImageDownloader (KeyValueHTTP) <KeyValueHTTP>
@end

@interface STKWebserviceManager ()
@property (nonatomic, readonly) SDWebImageDownloader* imageDownloader;

@property (nonatomic, readonly) AFHTTPSessionManager* getSessionManager;
@property (nonatomic, readonly) AFHTTPSessionManager* stickerSessionManager;
@property (nonatomic, readonly) AFHTTPSessionManager* sessionManager;

//
// moved from old code;
// same as sessionManager, but with content type set
@property (nonatomic, readonly) AFHTTPSessionManager* analyticSessionManager;
// same as sessionManager, but with completion run on the background queue
@property (nonatomic, readonly) AFHTTPSessionManager* backgroundSessionManager;
//

@property (nonatomic, readonly) AFHTTPSessionManager* errorManager;

@property (nonatomic) BOOL networkReachable;

@property (nonatomic, readonly) NSString* rootURLString;
@end

@implementation STKWebserviceManager

static STKConstStringKey kLastModifiedDateKey = @"kLastModifiedDateKey";
static STKConstStringKey kPacksURL = @"shop/my";
static STKConstStringKey kStatisticUrl = @"statistics";
static STKConstStringKey kSearchURL = @"search";
static STKConstStringKey kSTKApiVersion = @"v2";
static STKConstStringKey kSdkVersion = @"0.4.4";

+ (instancetype)sharedInstance {
	static STKWebserviceManager* sharedInstance = nil;

	@synchronized (self){
		if (!sharedInstance) {
			sharedInstance = [STKWebserviceManager new];
		}
	}

	return sharedInstance;
}

- (instancetype)init {
	if (self = [super init]) {
		static const BOOL work = !YES;
		_rootURLString = work ? @"http://work.stk.908.vc/" : @"https://api.stickerpipe.com/";

		_imageDownloader = [SDWebImageDownloader new];
		_networkReachable = YES;
		[self fillHTTPHeader: self.imageDownloader];

		NSURL* URL = [NSURL URLWithString: [NSString stringWithFormat: @"%@/api/%@", self.rootURLString, kSTKApiVersion]];

		NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
		config.HTTPMaximumConnectionsPerHost = 1;
		config.timeoutIntervalForRequest = 180;

		_stickerSessionManager = [[AFHTTPSessionManager alloc] initWithBaseURL: URL sessionConfiguration: config];
		_sessionManager = [[AFHTTPSessionManager alloc] initWithBaseURL: URL];
		_getSessionManager = [[AFHTTPSessionManager alloc] initWithBaseURL: URL];

		NSURL* errorHandlingRoot = [NSURL URLWithString: @"https://api.stickerpipe.com/logs/"];
		_errorManager = [[AFHTTPSessionManager alloc] initWithBaseURL: errorHandlingRoot];

		self.errorManager.requestSerializer = [self baseSerializer];
		self.stickerSessionManager.requestSerializer = [self baseSerializer];
		self.sessionManager.requestSerializer = [self baseSerializer];
		self.getSessionManager.requestSerializer = [self getSerializer];

		_analyticSessionManager = [[AFHTTPSessionManager alloc] initWithBaseURL: URL];
		self.analyticSessionManager.requestSerializer = [self baseSerializer];
		[self.analyticSessionManager.requestSerializer setValue: @"application/json" forHTTPHeaderField: @"Content-Type"];

		_backgroundSessionManager = [[AFHTTPSessionManager alloc] initWithBaseURL: URL];
		self.backgroundSessionManager.requestSerializer = [self baseSerializer];
		self.backgroundSessionManager.completionQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

		self.lastUpdateDate = 0;
	}

	return self;
}

- (AFJSONRequestSerializer*)baseSerializer {
	AFJSONRequestSerializer* serializer = [AFJSONRequestSerializer serializer];
	[self fillHTTPHeader: serializer];

	return serializer;
}

- (void)fillHTTPHeader: (id <KeyValueHTTP>)header {
	[header setValue: [STKStickersManager userKey] forHTTPHeaderField: @"UserID"];
	[header setValue: kSTKApiVersion forHTTPHeaderField: @"ApiVersion"];
	[header setValue: @"iOS" forHTTPHeaderField: @"Platform"];
	[header setValue: [STKUUIDManager generatedDeviceToken] forHTTPHeaderField: @"DeviceId"];
	[header setValue: [STKApiKeyManager apiKey] forHTTPHeaderField: @"ApiKey"];
	[header setValue: kSdkVersion forHTTPHeaderField: @"SdkVersion"];
	[header setValue: [[NSBundle mainBundle] bundleIdentifier] forHTTPHeaderField: @"Package"];
	[header setValue: [self localization] forHTTPHeaderField: @"Localization"];
}

- (AFJSONRequestSerializer*)getSerializer {
	AFJSONRequestSerializer* serializer = [self baseSerializer];
	NSNumber* isSubscriber = @([STKStickersManager isSubscriber]);
	[serializer setValue: [isSubscriber stringValue] forHTTPHeaderField: @"is_subscriber"];

	return serializer;
}

- (NSString*)localization {
	NSString* predefinedLocalization = [[NSUserDefaults standardUserDefaults] stringForKey: kLocalizationDefaultsKey];

	if (predefinedLocalization) {
		return predefinedLocalization;
	} else {
		NSString* language = [NSLocale preferredLanguages].firstObject;
		NSDictionary* languageDic = [NSLocale componentsFromLocaleIdentifier: language];
		NSString* languageCode = languageDic[@"kCFLocaleLanguageCodeKey"];

		return languageCode;
	}
}

- (void)searchStickersWithSearchModel: (STKSearchModel*)searchModel completion: (void (^)(NSArray* stickers))completion {
	NSString* funcName = @"searchStickersWithSearchModel";

	if (!searchModel.isSuggest) {
		searchModel.topIfEmpty = @"0";
		searchModel.wholeWord = @"1";
	} else {
		searchModel.topIfEmpty = @"1";
		searchModel.wholeWord = @"0";
	}

	searchModel.limit = @"20";

	NSDictionary* params = @{
			@"q": searchModel.q,
			@"top_if_empty": searchModel.topIfEmpty,
			@"whole_word": searchModel.wholeWord,
			@"limit": searchModel.limit
	};

	[self.getSessionManager GET: kSearchURL parameters: params progress: nil success: ^ (NSURLSessionDataTask* task, id responseObject) {
		if (completion) {
			completion(responseObject[@"data"]);
		}
	}                   failure: ^ (NSURLSessionDataTask* task, NSError* error) {
		[self sendAnErrorWithCategory: funcName p1: @"" p2: @""];

		if (completion) {
			completion(nil);
		}
	}];
}

- (void)loadStickerPackWithName: (NSString*)packName andPricePoint: (NSString*)pricePoint
						success: (void (^)(id))success
						failure: (void (^)(NSError*))failure {
	NSString* funcName = @"loadStickerPackWithName";

	NSString* route = [NSString stringWithFormat: @"packs/%@", packName];
	NSDictionary* params = @{@"purchase_type": [self purchaseType: pricePoint]};

	[self.stickerSessionManager POST: route parameters: params progress: nil success: ^ (NSURLSessionDataTask* task, id responseObject) {
		if (success) {
			success(responseObject);
		}
	}                        failure: ^ (NSURLSessionDataTask* task, NSError* error) {
		[self sendAnErrorWithCategory: funcName p1: @"" p2: @""];

		if (failure) {
			failure(error);
		}
	}];
}

- (void)getPacksWithSuccess: (void (^)(id response, NSTimeInterval lastModifiedDate, BOOL newContent))success
					failure: (void (^)(NSError* error))failure {
	NSString* funcName = @"getStickersPacksForUserWithSuccess";

	NSDictionary* params = @{@"is_subscriber": @([STKStickersManager isSubscriber])};

	[self.getSessionManager GET: kPacksURL parameters: params progress: nil success: ^ (NSURLSessionDataTask* task, id responseObject) {
		//TODO: check, if this needed
		NSTimeInterval timeInterval = [responseObject[@"meta"][@"shop_last_modified"] doubleValue];

		BOOL newContent = [responseObject[@"meta"][@"new_shop_content"] boolValue];

		if ([responseObject[@"data"] count] == 0) {
			STKLog(@"get empty stickers pack JSON");
		}

		if (success) {
			success(responseObject, timeInterval, newContent);
		}
	}                   failure: ^ (NSURLSessionDataTask* task, NSError* error) {
		[self sendAnErrorWithCategory: funcName p1: @"" p2: @""];

		if (failure) {
			dispatch_async(dispatch_get_main_queue(), ^ {
				failure(error);
			});
		}
	}];
}

- (void)sendStatistics: (NSArray*)statisticsArray success: (void (^)(id))success failure: (void (^)(NSError*))failure {
	NSString* funcName = @"sendStatistics";

	NSMutableArray* array = [NSMutableArray array];

	for (STKStatistic* statistic in statisticsArray) {
		[array addObject: [statistic dictionary]];
	}

	[self.analyticSessionManager POST: kStatisticUrl parameters: array progress: nil success: ^ (NSURLSessionDataTask* task, id responseObject) {
		if (success) {
			success(responseObject);
		}
	}                         failure: ^ (NSURLSessionDataTask* task, NSError* error) {
		[self sendAnErrorWithCategory: funcName p1: @"" p2: @""];

		if (failure) {
			failure(error);
		}
	}];
}

- (NSString*)purchaseType: (NSString*)pricePoint {
	if ([pricePoint isEqualToString: @"A"]) {
		return @"free";
	} else if ([pricePoint isEqualToString: @"B"]) {
		return [STKStickersManager isSubscriber] ? @"subscription" : @"oneoff";
	} else if ([pricePoint isEqualToString: @"C"]) {
		return @"oneoff";
	}
	return @"";
}

- (void)getStickerInfoWithId: (NSString*)contentId
					 success: (void (^)(id response))success
					 failure: (void (^)(NSError*))failure {
	NSString* funcName = @"getStickerInfoWithId";

	NSString* route = [NSString stringWithFormat: @"content/%@", contentId];

	[self.backgroundSessionManager GET: route parameters: nil progress: nil success: ^ (NSURLSessionDataTask* task, id responseObject) {
		if (success) {
			success(responseObject);
		}
	}                          failure: ^ (NSURLSessionDataTask* task, NSError* error) {
		[self sendAnErrorWithCategory: funcName p1: @"" p2: @""];

		if (failure) {
			failure(error);
		}
	}];
}

- (void)getStickerPackWithName: (NSString*)packName
					   success: (void (^)(id))success
					   failure: (void (^)(NSError*))failure {
	NSString* route = [NSString stringWithFormat: @"pack/%@", packName];

	NSString* funcName = @"getStickerPackWithName";

	[self.backgroundSessionManager GET: route parameters: nil progress: nil success: ^ (NSURLSessionDataTask* task, id responseObject) {
		if (success) {
			success(responseObject);
		}
	}                          failure: ^ (NSURLSessionDataTask* task, NSError* error) {
		[self sendAnErrorWithCategory: funcName p1: packName p2: @""];

		if (failure) {
			failure(error);
		}
	}];
}

- (void)deleteStickerPackWithName: (NSString*)packName
						  success: (void (^)(id))success
						  failure: (void (^)(NSError*))failure {
	NSString* funcName = @"deleteStickerPackWithName";

	NSString* route = [NSString stringWithFormat: @"packs/%@", packName];

	[self.backgroundSessionManager DELETE: route parameters: nil success: ^ (NSURLSessionDataTask* task, id responseObject) {
		if (success) {
			success(responseObject);
		}
	}                             failure: ^ (NSURLSessionDataTask* task, NSError* error) {
		[self sendAnErrorWithCategory: funcName p1: packName p2: @""];

		if (failure) {
			failure(error);
		}
	}];
}

- (id <SDWebImageOperation>)downloadImageWithURL: (NSURL*)url
									  completion: (SDWebImageDownloaderCompletedBlock)completion {
	return [self downloadImageWithURL: url progress: nil completion: completion];
}

- (id <SDWebImageOperation>)downloadImageWithURL: (NSURL*)url
										progress: (SDWebImageDownloaderProgressBlock)progressBlock
									  completion: (SDWebImageDownloaderCompletedBlock)completion {
	return [self.imageDownloader downloadImageWithURL: url
											  options: 0
											 progress: progressBlock
											completed: completion];
}

- (void)sendDeviceToken: (NSString*)token failure: (void (^)(NSError*))failure {
	NSString* funcName = @"sendDeviceToken";

	[self.backgroundSessionManager POST: @"token" parameters: @{@"token": token} progress: nil success: nil failure: ^ (NSURLSessionDataTask* _Nullable task, NSError* _Nonnull error) {
		[self sendAnErrorWithCategory: funcName p1: token p2: @""];

		if (failure) {
			failure(error);
		}
	}];
}

- (void)sendAnErrorWithCategory: (NSString*)category p1: (NSString*)p1 p2: (NSString*)p2 {
#ifndef DEBUG
	NSString* categoryWithoutSpaces = [category stringByReplacingOccurrencesOfString: @" " withString: @""];
	NSString* p1WithoutSpaces = [p1 stringByReplacingOccurrencesOfString: @" " withString: @""];
	NSString* p2WithoutSpaces = [p2 stringByReplacingOccurrencesOfString: @" " withString: @""];

	NSString* route = [NSString stringWithFormat: @"pack/%@/%@/%@", categoryWithoutSpaces, p1WithoutSpaces, p2WithoutSpaces];

	[self.errorManager POST: route parameters: nil progress: nil success: ^ (NSURLSessionDataTask* task, id responseObject) {
		STKLog(@"Error sent for %@", route);
	} failure: ^ (NSURLSessionDataTask* task, NSError* error) {
		STKLog(@"Error was not sent for %@", route);
	}];
#endif
}

#pragma mark - Reachability

- (void)startCheckingNetwork {
	static dispatch_once_t once;
	dispatch_once(&once, ^ {
		[[AFNetworkReachabilityManager sharedManager] startMonitoring];

		[[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock: ^ (AFNetworkReachabilityStatus status) {
			self.networkReachable = (status == AFNetworkReachabilityStatusReachableViaWWAN ||
					status == AFNetworkReachabilityStatusReachableViaWiFi);
		}];
	});
}


#pragma mark -

- (NSString*)stickerUrl {
	NSString* lang = [[NSLocale preferredLanguages] objectAtIndex: 0];

	NSString* language = [[lang componentsSeparatedByString: @"-"] objectAtIndex: 0];

	NSString* color = [[NSUserDefaults standardUserDefaults] stringForKey: kShopColor];
	if (color == nil || [color isEqualToString: @""]) {
		color = @"047aff";
	}

	/**
	 *  Shop content color from navigation controller

	 UIColor *navigationBarColor = self.navigationController.navigationBar.backgroundColor;

	 CGFloat red = 0.0, green = 0.0, blue = 0.0, alpha =0.0;
	 [navigationBarColor getRed:&red green:&green blue:&blue alpha:&alpha];

	 int r,g,b,a;

	 r = (int)(255.0 * red);
	 g = (int)(255.0 * green);
	 b = (int)(255.0 * blue);
	 a = (int)(255.0 * alpha);

	 NSString *color = [NSString stringWithFormat:@"%02x%02x%02x", r, g, b];
	 */

	return [NSMutableString stringWithFormat: @"%@api/v2/web?&apiKey=%@&platform=IOS&userId=%@&density=%@&is_subscriber=%d&primaryColor=%@&localization=%@", self.rootURLString, [STKApiKeyManager apiKey], [STKStickersManager userKey], [STKUtility scaleString], [STKStickersManager isSubscriber], color, language];
}


#pragma mark - URL

- (NSURL*)stkUrl {
	return [NSURL URLWithString: [NSString stringWithFormat: @"%@stk/", self.rootURLString]];
}

- (NSURL*)tabImageUrlForPackName: (NSString*)name {
	NSString* density = [STKUtility scaleString];

	NSString* urlString = [NSString stringWithFormat: @"%@/tab_icon_%@.png", name, density];

	return [NSURL URLWithString: urlString relativeToURL: [self stkUrl]];
}

- (NSURL*)mainImageUrlForPackName: (NSString*)name {
	NSString* density = [STKUtility scaleString];

	NSString* urlString = [NSString stringWithFormat: @"%@/main_icon_%@.png", name, density];

	return [NSURL URLWithString: urlString relativeToURL: [self stkUrl]];
}

//TODO: move it somewhere
#pragma mark - defaults

- (NSTimeInterval)lastUpdateDate {
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	NSTimeInterval lastUpdateDate = [defaults doubleForKey: kLastUpdateIntervalKey];
	return lastUpdateDate;
}

- (void)setLastUpdateDate: (NSTimeInterval)lastUpdateDate {
	[self willChangeValueForKey: @"lastUpdateDate"];
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	[defaults setDouble: lastUpdateDate forKey: kLastUpdateIntervalKey];
	[self didChangeValueForKey: @"lastUpdateDate"];
}

- (NSTimeInterval)lastModifiedDate {
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	NSTimeInterval timeInterval = [defaults doubleForKey: kLastModifiedDateKey];
	return timeInterval;
}

- (void)setLastModifiedDate: (NSTimeInterval)lastModifiedDate {
	[self willChangeValueForKey: @"lastModifiedDate"];
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	[defaults setDouble: lastModifiedDate forKey: kLastModifiedDateKey];
	[self didChangeValueForKey: @"lastModifiedDate"];
}

@end
