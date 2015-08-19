//
//  STKStickerController.m
//  StickerPipe
//
//  Created by Vadim Degterev on 21.07.15.
//  Copyright (c) 2015 908 Inc. All rights reserved.
//

#import "STKStickerController.h"
#import "STKStickerDelegateManager.h"
#import "STKStickerHeaderDelegateManager.h"
#import "STKStickerViewCell.h"
#import "STKStickersSeparator.h"
#import "STKStickerHeaderCell.h"
#import "STKStickerObject.h"
#import "STKUtility.h"
#import "STKStickersEntityService.h"
#import "STKEmptyRecentCell.h"
#import "STKStickersSettingsViewController.h"
#import "STKPackDescriptionController.h"
#import "STKStickerPackObject.h"
#import "STKOrientationNavigationController.h"

//SIZES
static const CGFloat kStickerHeaderItemHeight = 44.0;
static const CGFloat kStickerHeaderItemWidth = 44.0;

static const CGFloat kStickerSeparatorHeight = 1.0;
static const CGFloat kStickersSectionPaddingTopBottom = 12.0;
static const CGFloat kStickersSectionPaddingRightLeft = 16.0;

@interface STKStickerController() <STKPackDescriptionControllerDelegate>

@property (strong, nonatomic) UIView *internalStickersView;

@property (strong, nonatomic) UICollectionView *stickersCollectionView;
@property (strong, nonatomic) UICollectionViewFlowLayout *stickersFlowLayout;
@property (strong, nonatomic) STKStickerDelegateManager *stickersDelegateManager;

@property (strong, nonatomic) UICollectionView *stickersHeaderCollectionView;
@property (strong, nonatomic) UICollectionViewFlowLayout *stickersHeaderFlowLayout;
@property (strong, nonatomic) STKStickerHeaderDelegateManager *stickersHeaderDelegateManager;
@property (strong, nonatomic) UIButton *shopButton;


@property (strong, nonatomic) STKStickersEntityService *stickersService;



@end

@implementation STKStickerController

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        self.internalStickersView = [[UIView alloc] init];
        self.internalStickersView.backgroundColor = [UIColor whiteColor];
        
        self.stickersService = [STKStickersEntityService new];
        
        self.internalStickersView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
        self.internalStickersView.clipsToBounds = YES;
        
        //iOS 7 FIX
        if (CGRectEqualToRect(self.internalStickersView.frame, CGRectZero) && [UIDevice currentDevice].systemVersion.floatValue < 8.0) {
            self.internalStickersView.frame = CGRectMake(1, 1, 1, 1);
        }
        
        [self initStickerHeader];
        [self initStickersCollectionView];
        [self initShopButton];
        
        [self configureStickersViewsConstraints];
        
        [self reloadStickers];
    }
    return self;
}


- (void) initStickersCollectionView {
    
    self.stickersFlowLayout = [[UICollectionViewFlowLayout alloc] init];
    self.stickersFlowLayout.scrollDirection = UICollectionViewScrollDirectionVertical;
    self.stickersFlowLayout.itemSize = CGSizeMake(80.0, 80.0);
    self.stickersFlowLayout.sectionInset = UIEdgeInsetsMake(kStickersSectionPaddingTopBottom, kStickersSectionPaddingRightLeft, kStickersSectionPaddingTopBottom, kStickersSectionPaddingRightLeft);
    self.stickersFlowLayout.footerReferenceSize = CGSizeMake(0, kStickerSeparatorHeight);
    
    self.stickersDelegateManager = [STKStickerDelegateManager new];
    
    __weak typeof(self) weakSelf = self;
    [self.stickersDelegateManager setDidChangeDisplayedSection:^(NSInteger displayedSection) {
        [weakSelf setPackSelectedAtIndex:displayedSection];
    }];
    
    [self.stickersDelegateManager setDidSelectSticker:^(STKStickerObject *sticker) {
        [weakSelf.stickersService incrementStickerUsedCountWithID:sticker.stickerID];
        if ([weakSelf.delegate respondsToSelector:@selector(stickerController:didSelectStickerWithMessage:)]) {
            [weakSelf.delegate stickerController:weakSelf didSelectStickerWithMessage:sticker.stickerMessage];
        }
    }];
    
    self.stickersCollectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:self.stickersFlowLayout];
    self.stickersCollectionView.dataSource = self.stickersDelegateManager;
    self.stickersCollectionView.delegate = self.stickersDelegateManager;
    self.stickersCollectionView.delaysContentTouches = NO;
    self.stickersCollectionView.showsHorizontalScrollIndicator = NO;
    self.stickersCollectionView.showsVerticalScrollIndicator = NO;
    self.stickersCollectionView.backgroundColor = [UIColor clearColor];
    [self.stickersCollectionView registerClass:[STKStickerViewCell class] forCellWithReuseIdentifier:@"STKStickerViewCell"];
    [self.stickersCollectionView registerClass:[STKEmptyRecentCell class] forCellWithReuseIdentifier:@"STKEmptyRecentCell"];
    [self.stickersCollectionView registerClass:[UICollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"UICollectionReusableView"];
    [self.internalStickersView addSubview:self.stickersCollectionView];
    [self.stickersCollectionView registerClass:[STKStickersSeparator class] forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"STKStickerPanelSeparator"];
    
    self.stickersDelegateManager.collectionView = self.stickersCollectionView;
    
    [self.internalStickersView addSubview:self.stickersCollectionView];
}

- (void)initShopButton {
    self.shopButton = [UIButton buttonWithType:UIButtonTypeSystem];

    [self.shopButton setImage:[UIImage imageNamed:@"STKMoreIcon"] forState:UIControlStateNormal];
    [self.shopButton setImage:[UIImage imageNamed:@"STKMoreIcon"] forState:UIControlStateHighlighted];

    self.shopButton.titleLabel.font = [UIFont systemFontOfSize:20.0];
    [self.shopButton setTintColor:[STKUtility defaultOrangeColor]];
    
    [self.shopButton addTarget:self action:@selector(shopButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    
    self.shopButton.backgroundColor = self.headerBackgroundColor ? self.headerBackgroundColor : [STKUtility defaultGreyColor];
    
    [self.internalStickersView addSubview:self.shopButton];
}

- (void) initStickerHeader {
    
    self.stickersHeaderFlowLayout = [[UICollectionViewFlowLayout alloc] init];
    self.stickersHeaderFlowLayout.itemSize = CGSizeMake(kStickerHeaderItemWidth, kStickerHeaderItemHeight);
    self.stickersHeaderFlowLayout.minimumInteritemSpacing = 0;
    self.stickersHeaderFlowLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    
    self.stickersHeaderDelegateManager = [STKStickerHeaderDelegateManager new];
    __weak typeof(self) weakSelf = self;
    [self.stickersHeaderDelegateManager setDidSelectRow:^(NSIndexPath *indexPath, STKStickerPackObject *stickerPack) {
        if (stickerPack.isNew.boolValue) {
            stickerPack.isNew = @NO;
            [weakSelf.stickersService updateStickerPackInCache:stickerPack];
            [weakSelf reloadHeaderItemAtIndexPath:indexPath];
        }
        NSIndexPath *newIndexPath = [NSIndexPath indexPathForItem:0 inSection:indexPath.item];
        CGRect layoutRect = [weakSelf.stickersCollectionView layoutAttributesForItemAtIndexPath:newIndexPath].frame;
        
        [weakSelf.stickersCollectionView setContentOffset:CGPointMake(weakSelf.stickersCollectionView.contentOffset.x, layoutRect.origin.y  - kStickersSectionPaddingTopBottom) animated:YES];
        weakSelf.stickersDelegateManager.currentDisplayedSection = indexPath.item;

    }];
    
    self.stickersHeaderCollectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:self.stickersHeaderFlowLayout];
    self.stickersHeaderCollectionView.dataSource = self.stickersHeaderDelegateManager;
    self.stickersHeaderCollectionView.delegate = self.stickersHeaderDelegateManager;
    self.stickersHeaderCollectionView.delaysContentTouches = NO;
    self.stickersHeaderCollectionView.allowsMultipleSelection = NO;
    self.stickersHeaderCollectionView.showsHorizontalScrollIndicator = NO;
    self.stickersHeaderCollectionView.showsVerticalScrollIndicator = NO;
    self.stickersHeaderCollectionView.backgroundColor = [UIColor clearColor];
    [self.stickersHeaderCollectionView registerClass:[STKStickerHeaderCell class] forCellWithReuseIdentifier:@"STKStickerPanelHeaderCell"];
    
    self.stickersHeaderCollectionView.backgroundColor = self.headerBackgroundColor ? self.headerBackgroundColor : [STKUtility defaultGreyColor];
    
    [self.internalStickersView addSubview:self.stickersHeaderCollectionView];
    
    
}


- (void) configureStickersViewsConstraints {
    
    self.stickersHeaderCollectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.stickersCollectionView.translatesAutoresizingMaskIntoConstraints = NO;
    self.shopButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    NSDictionary *viewsDictionary = @{@"stickersHeaderCollectionView" : self.stickersHeaderCollectionView,
                                      @"stickersView" : self.internalStickersView,
                                      @"stickersCollectionView" : self.stickersCollectionView,
                                      @"shopButton" : self.shopButton};
    NSArray *verticalShopButtonConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[shopButton]"
                                                                                    options:0
                                                                                    metrics:nil
                                                                                      views:viewsDictionary];
    [self.internalStickersView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[shopButton]|" options:0 metrics:nil views:viewsDictionary]];
    
    NSArray *heightConstraint = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[shopButton(==44.0)]" options:0 metrics:nil views:viewsDictionary];
    NSArray *widthConstraint = [NSLayoutConstraint constraintsWithVisualFormat:@"H:[shopButton(==44.0)]" options:0 metrics:nil views:viewsDictionary];
    
    NSArray *horizontalHeaderConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[stickersHeaderCollectionView]-0-[shopButton]"
                                                                                 options:0
                                                                                 metrics:nil
                                                                                   views:viewsDictionary];
    NSArray *verticalHeaderConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[stickersHeaderCollectionView]-0-[stickersCollectionView]"
                                                                                   options:0
                                                                                   metrics:nil
                                                                                     views:viewsDictionary];
    NSArray *horizontalStickersConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[stickersCollectionView]|" options:0 metrics:nil views:viewsDictionary];
    NSArray *verticalStickersConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[stickersHeaderCollectionView]-0-[stickersCollectionView]|"
                                                                                    options:0
                                                                                    metrics:nil
                                                                                      views:viewsDictionary];
    [self.stickersHeaderCollectionView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[stickersHeaderCollectionView(44.0)]" options:0 metrics:nil views:viewsDictionary]];
    [self.shopButton addConstraints:heightConstraint];
    [self.shopButton addConstraints:widthConstraint];
    
    [self.internalStickersView addConstraints:verticalShopButtonConstraints];
    [self.internalStickersView addConstraints:verticalHeaderConstraints];
    [self.internalStickersView addConstraints:verticalStickersConstraints];
    [self.internalStickersView addConstraints:horizontalHeaderConstraints];
    [self.internalStickersView addConstraints:horizontalStickersConstraints];
    
}


#pragma mark - Action

- (void)shopButtonAction:(UIButton*)shopButton {
    
    STKStickersSettingsViewController *vc = [[STKStickersSettingsViewController alloc] initWithNibName:@"STKStickersSettingsViewController" bundle:nil];
    
    STKOrientationNavigationController *navigationController = [[STKOrientationNavigationController alloc] initWithRootViewController:vc];
    
    UIViewController *presenter = [self.delegate stickerControllerViewControllerForPresentingModalView];
    
    [presenter presentViewController:navigationController animated:YES completion:nil];
}


#pragma mark - Reload

- (void)reloadStickersView {
    [self reloadStickers];
}

- (void)reloadHeaderItemAtIndexPath:(NSIndexPath*)indexPath {
    __weak typeof(self) wself = self;

    [self.stickersService getStickerPacksWithType:nil completion:^(NSArray *stickerPacks) {
        [wself.stickersHeaderDelegateManager setStickerPacks:stickerPacks];
        [wself.stickersHeaderCollectionView reloadItemsAtIndexPaths:@[indexPath]];
               [wself.stickersHeaderCollectionView selectItemAtIndexPath:indexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
    } failure:^(NSError *error) {
        
    }];
}

- (void)reloadStickersHeader {
    __weak  typeof(self) wself = self;

    [self.stickersService getStickerPacksWithType:nil completion:^(NSArray *stickerPacks) {
        [wself.stickersHeaderDelegateManager setStickerPacks:stickerPacks];
        [wself.stickersHeaderCollectionView reloadItemsAtIndexPaths:@[[NSIndexPath indexPathForItem:1 inSection:0]]];
        NSIndexPath *selectedIndexPath = [NSIndexPath indexPathForItem:wself.stickersDelegateManager.currentDisplayedSection inSection:0];
        [wself.stickersHeaderCollectionView selectItemAtIndexPath:selectedIndexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
    } failure:nil];
}

- (void)reloadStickers {
    __weak typeof(self) weakSelf = self;
    [self.stickersService getStickerPacksWithType:nil completion:^(NSArray *stickerPacks) {
        [weakSelf.stickersDelegateManager setStickerPacksArray:stickerPacks];
        [weakSelf.stickersHeaderDelegateManager setStickerPacks:stickerPacks];
        [weakSelf.stickersCollectionView reloadData];
        [weakSelf.stickersHeaderCollectionView reloadData];
        weakSelf.stickersCollectionView.contentOffset = CGPointZero;
        weakSelf.stickersDelegateManager.currentDisplayedSection = 0;
        
        [weakSelf setPackSelectedAtIndex:0];
    } failure:^(NSError *error) {
        
    }];
}


#pragma mark - Selection


- (void)setPackSelectedAtIndex:(NSInteger)index {
    if ([self.stickersHeaderCollectionView numberOfItemsInSection:0] - 1 >= index) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:index inSection:0];

        STKStickerPackObject *stickerPack = [self.stickersHeaderDelegateManager itemAtIndexPath:indexPath];
        if (stickerPack.isNew.boolValue) {
            stickerPack.isNew = @NO;
            [self.stickersService updateStickerPackInCache:stickerPack];
            [self reloadHeaderItemAtIndexPath:[NSIndexPath indexPathForItem:index inSection:0]];
        }
        [self.stickersHeaderCollectionView selectItemAtIndexPath:indexPath animated:YES scrollPosition:UICollectionViewScrollPositionCenteredHorizontally];
    }

}

#pragma mark - STKPackDescriptionControllerDelegate

- (void)packDescriptionControllerDidChangePakcStatus:(STKPackDescriptionController*)controller {
    if ([self.delegate respondsToSelector:@selector(stickerControllerDidChangePackStatus:)]) {
        [self.delegate stickerControllerDidChangePackStatus:self];
    }
}

#pragma mark - Presenting

-(void)showPackInfoControllerWithStickerMessage:(NSString*)message {
    STKPackDescriptionController *vc = [[STKPackDescriptionController alloc] initWithNibName:@"STKPackDescriptionController" bundle:nil];
    vc.stickerMessage = message;
    vc.delegate = self;
    UIViewController *presentViewController = [self.delegate stickerControllerViewControllerForPresentingModalView];
    [presentViewController presentViewController:vc animated:YES completion:nil];
}

#pragma mark - Checks

-(BOOL)isStickerPackDownloaded:(NSString *)packMessage {
    NSArray *packNames = [STKUtility trimmedPackNameAndStickerNameWithMessage:packMessage];
    NSString *packName = packNames.firstObject;
    return [self.stickersService isPackDownloaded:packName];

}

#pragma mark - Colors

-(void)setColorForStickersHeaderPlaceholderColor:(UIColor *)color {
    self.stickersHeaderDelegateManager.placeholderHeadercolor = color;
}

-(void)setColorForStickersPlaceholder:(UIColor *)color {
    self.stickersDelegateManager.placeholderColor = color;
}

#pragma mark - Property

- (BOOL)isStickerViewShowed {
    
    BOOL isShowed = self.internalStickersView.superview != nil;

    return isShowed;
}

-(UIView *)stickersView {
    
    [self reloadStickers];
    
    return _internalStickersView;
}


@end
