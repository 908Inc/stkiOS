//
//  STKChatViewController.m
//  StickerFactory
//
//  Created by Vadim Degterev on 03.07.15.
//  Copyright (c) 2015 908 Inc. All rights reserved.
//

#import "STKChatViewController.h"
#import "STKChatStickerCell.h"
#import "STKChatTextCell.h"
#import "STKStickerPipe.h"
#import "STKShowStickerButton.h"
#import "STKStickersPurchaseService.h"

@interface STKChatViewController() <UITableViewDelegate, UITableViewDataSource, UITextViewDelegate, STKStickerControllerDelegate, UIAlertViewDelegate> {
    
    NSString *packName;
    NSString *packPrice;
}

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UITextView *inputTextView;
@property (weak, nonatomic) IBOutlet UIView *textInputPanel;
@property (weak, nonatomic) IBOutlet UIButton *sendButton;

@property (assign, nonatomic) BOOL isKeyboardShowed;

@property (strong, nonatomic) NSMutableArray *dataSource;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *textViewHeightConstraint;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomViewConstraint;
@property (weak, nonatomic) IBOutlet UIView *errorView;

@property (strong, nonatomic) STKStickerController *stickerController;

- (IBAction)sendClicked:(id)sender;

@end

@implementation STKChatViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //    self.dataSource = [@[@"[[pinkgorilla_bigsmile]]",@"[[pinkgorilla_china]]",@"[[pinkgorilla_bigsmile]]",@"[[pinkgorilla_bigsmile]]",@"[[pinkgorilla_bike]]",@"[[pinkgorilla_bigsmile]]",@"[[pinkgorilla_bigsmile]]",@"[[pinkgorilla_bigsmile]]",@"[[pinkgorilla_bigsmile]]",@"[[pinkgorilla_bigsmile]]",@"[[pinkgorilla_bigsmile]]",@"[[pinkgorilla_bigsmile]]",@"[[pinkgorilla_bigsmile]]",@"[[pinkgorilla_bigsmile]]",@"[[pinkgorilla_dontknow]]",@"[[flowers_flower1]]"] mutableCopy];
    
    self.dataSource = [@[@"[[1778]]", @"[[1778]]", @"[[1609]]", @"[[1624]]", @"[[1776]]", @"[[sonya45_1844]]"] mutableCopy];
    self.inputTextView.layer.cornerRadius = 7.0;
    self.inputTextView.layer.borderWidth = 1.0;
    self.inputTextView.layer.borderColor = [UIColor colorWithRed:0.84 green:0.84 blue:0.85 alpha:1].CGColor;
    
    self.textInputPanel.layer.borderWidth = 1.0;
    self.textInputPanel.layer.borderColor = [UIColor colorWithRed:0.82 green:0.82 blue:0.82 alpha:1].CGColor;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(willHideKeyboard:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didShowKeyboard:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(purchasePack:) name:STKPurchasePackNotification object:nil];
    
    
    //tap gesture
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(textViewDidTap:)];
    [self.inputTextView addGestureRecognizer:tapGesture];
    
    [self scrollTableViewToBottom];
    
    self.stickerController = [[STKStickerController alloc] init];
    self.stickerController.delegate = self;
    self.stickerController.textInputView = self.inputTextView;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didUpdateStickersCache:) name:STKStickersCacheDidUpdateStickersNotification object:nil];
    
    
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self.stickerController updateFrames];
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - UI Methods

- (void) scrollTableViewToBottom {
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.dataSource.count - 1 inSection:0];
    [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}


#pragma mark - Notifications

- (void)didUpdateStickersCache:(NSNotification*) notification {
    [self.tableView reloadData];
}

- (void) didShowKeyboard:(NSNotification*)notification {
    
    CGRect keyboardBounds = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    
    UIViewAnimationCurve curve = [[notification.userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] integerValue];
    CGFloat keyboardHeight = keyboardBounds.size.height;
    
    CGFloat animationDuration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] floatValue];
    
    self.bottomViewConstraint.constant = keyboardHeight;
    
    
    [UIView animateWithDuration:animationDuration animations:^{
        [UIView setAnimationCurve:curve];
        [self.view layoutIfNeeded];
    }];
    
    self.isKeyboardShowed = YES;
    [self scrollTableViewToBottom];
    
}


- (void)willHideKeyboard:(NSNotification*)notification {
    
    self.isKeyboardShowed = NO;
    
    CGFloat animationDuration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] floatValue];
    
    self.bottomViewConstraint.constant = 0;
    
    [UIView animateWithDuration:animationDuration animations:^{
        [self.view layoutIfNeeded];
    }];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return self.dataSource.count;
    
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *message = self.dataSource[indexPath.row];
    
    if ([STKStickersManager isStickerMessage:message]) {
        STKChatStickerCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"Cell"];
        
        [cell fillWithStickerMessage:message downloaded:[self.stickerController isStickerPackDownloaded:message]];
        
        return cell;
    } else {
        STKChatTextCell *cell = [self.tableView
                                 dequeueReusableCellWithIdentifier:@"textCell"];
        
        [cell fillWithTextMessage:message];
        return cell;
    }
    return nil;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    id cell = [tableView cellForRowAtIndexPath:indexPath];
    if ([cell isKindOfClass:[STKChatStickerCell class]]) {
        [self.stickerController showPackInfoControllerWithStickerMessage:self.dataSource[indexPath.row]];
    }
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *message = self.dataSource[indexPath.row];
    return ([STKStickersManager isStickerMessage:message]) ? 160 : 40;
}

#pragma mark - STKStickerControllerDelegate

- (void)stickerController:(STKStickerController *)stickerController didSelectStickerWithMessage:(NSString *)message {
    STKChatStickerCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"Cell"];
    [cell fillWithStickerMessage:message downloaded:[self.stickerController isStickerPackDownloaded:message]];
    
    [self addMessage:message];
}

- (UIViewController *)stickerControllerViewControllerForPresentingModalView {
    return self;
}

- (void)stickerControllerErrorHandle:(NSError *)error {
    self.errorView.hidden = NO;
}

- (void)addMessage:(NSString *)message {
    [self.tableView beginUpdates];
    [self.dataSource addObject:message];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.dataSource.count - 1 inSection:0];
    [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationBottom];
    [self.tableView endUpdates];
    [self scrollTableViewToBottom];
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView  {
    self.sendButton.enabled = textView.text.length > 0;
    self.textViewHeightConstraint.constant = textView.contentSize.height;
    self.stickerController.keyboardButton.hidden = textView.text.length > 0;
}

#pragma mark - Gesture

- (void) textViewDidTap:(UITapGestureRecognizer*) gestureRecognizer {
    [self.inputTextView becomeFirstResponder];
}

#pragma mark - Property

- (STKStickerController *)stickerController {
    if (!_stickerController) {
        _stickerController = [STKStickerController new];
        _stickerController.delegate = self;
        _stickerController.textInputView = self.inputTextView;
    }
    return _stickerController;
}

#pragma mark - Actions

- (void)sendClicked:(id)sender {
    NSString *message = self.inputTextView.text;
    if (message.length > 0) {
        [self addMessage:message];
        [self.stickerController textMessageSent:message];
        self.inputTextView.text = @"";
        self.textViewHeightConstraint.constant = 33;
    }
    
}

#pragma mark - PurchasePack

- (void)purchasePack:(NSNotification *)notification {
    
    packName = notification.userInfo[@"packName"];
    packPrice = notification.userInfo[@"packPrice"];
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"" message:@"Purchase this stickers pack?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
    alertView.delegate = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [alertView show];
    });
    //    STKPurchaseService *purchaseService = [STKPurchaseService new];
    //    [purchaseService purchaseFailed];
    
}

#pragma mark - Alert controller delegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    switch (buttonIndex) {
        case 0:
            [[STKStickersPurchaseService sharedInstance] purchaseFailedError:nil];
            break;
        case 1:[[STKStickersPurchaseService sharedInstance] purchasInternalPackName:packName andPackPrice:packPrice];
            
        default:
            break;
    }
    
}


@end
