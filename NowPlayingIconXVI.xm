/*
 * Tweak.xm
 * NowPlayingIcon
 *
 * Created by Ethan Whited <ethanwhited2208@gmail.com> on 12/19/2022.
 * Copyright © 2022 Ethan Whited <ethanwhited2208@gmail.com>. All rights reserved.
 */
#import "MediaRemote.h"
#import "NowPlayingIconXVI.h"

NSString *nowPlayingAppBundleID;
static dispatch_once_t onceToken;

%hook SBMediaController
-(void)_setNowPlayingApplication:(id)arg1 {
    %orig;
    if (arg1 != nil) {
        // post notification when our now playing app changes
        [[NSNotificationCenter defaultCenter] postNotificationName:@"NowPlayingAppChanged" object:nil];
    } else {
        // post notification when now playing app is terminated
        [[NSNotificationCenter defaultCenter] postNotificationName:@"NowPlayingAppTerminated" object:nil];
    }
}

-(void)_mediaRemoteNowPlayingInfoDidChange:(id)arg1 {
    %orig;
    // set a delay to prevent multiple notifications
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 0.75);
    dispatch_after(delay, dispatch_get_main_queue(), ^(void){
        // only call once so we can ensure we don't get multiple notifications
        dispatch_once(&onceToken, ^{
            // post notification when now playing info changes
            if (arg1 != nil) [[NSNotificationCenter defaultCenter] postNotificationName:@"NowPlayingInfoChanged" object:nil];
       });
   });
    // reset our once call after our deflay of 0.75 and animations of 1.0
    dispatch_time_t delay2 = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 1.75);
    dispatch_after(delay2, dispatch_get_main_queue(), ^(void){
        onceToken = 0;
    });
}
%end

%hook SBIconImageView
%property (nonatomic, retain) UIImageView *nowPlayingImageView;
- (id)initWithFrame:(CGRect)frame {
    id o = %orig;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateNowPlayingIconVisibility) name:@"NowPlayingAppChanged" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateNowPlayingIconTerminated) name:@"NowPlayingAppTerminated" object:nil];
            
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateNowPlayingIcon) name:@"NowPlayingInfoChanged" object:nil];

    [self setupNowPlayingIcon];
    
    return o;
}

- (void)layoutSubviews {
    %orig;
    // only set the corner radius of our view in layoutSubviews
    if (self.nowPlayingImageView != nil) {
        self.nowPlayingImageView.frame = self.frame;
        self.nowPlayingImageView.layer.cornerRadius = self.nowPlayingImageView.frame.size.height/5;
        self.nowPlayingImageView.layer.cornerCurve = kCACornerCurveContinuous;
    }
}
 
%new
- (void)setupNowPlayingIcon {
    if (!self.nowPlayingImageView) {
        self.nowPlayingImageView = [[UIImageView alloc] initWithFrame:self.bounds];
        self.nowPlayingImageView.contentMode = UIViewContentModeScaleAspectFill;
        self.nowPlayingImageView.layer.masksToBounds = YES;
        self.nowPlayingImageView.layer.cornerRadius = self.nowPlayingImageView.frame.size.height/5;
        self.nowPlayingImageView.layer.cornerCurve = kCACornerCurveContinuous;
        self.nowPlayingImageView.clipsToBounds = YES;
        
        CATransition *transition = [CATransition animation];
        transition.duration = 1.0f;
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        transition.type = kCATransitionFade;
        [self.nowPlayingImageView.layer addAnimation:transition forKey:nil];
        
        [self addSubview:self.nowPlayingImageView];
            
        float height = self.frame.size.height;
        float width = self.frame.size.width;
            
        self.nowPlayingImageView.translatesAutoresizingMaskIntoConstraints = false;
        [self.nowPlayingImageView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor constant:0].active = YES;
        [self.nowPlayingImageView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:0].active = YES;
        [self.nowPlayingImageView.heightAnchor constraintEqualToConstant:height].active = YES;
        [self.nowPlayingImageView.widthAnchor constraintEqualToConstant:width].active = YES;
        
        if ([self respondsToSelector:@selector(updateNowPlayingIconVisibility)]) [self updateNowPlayingIconVisibility];
    }
}

%new
- (void)updateNowPlayingIcon {
    // check if the now playing app bundle id equals our icons bundle id then update
    SBApplication *nowPlayingApp = [[%c(SBMediaController) sharedInstance] nowPlayingApplication];
    nowPlayingAppBundleID = nowPlayingApp.bundleIdentifier;
    if (nowPlayingApp != nil) {
        if ([self.icon.applicationBundleID isEqual:nowPlayingAppBundleID]) {
            if ([self respondsToSelector:@selector(updateImage)]) [self updateImage];
        }
    }
}

%new
- (void)updateNowPlayingIconVisibility {
    // check if the now playing app bundle id equals our icons bundle id then unhide our view, otherwise hide it
    SBApplication *nowPlayingApp = [[%c(SBMediaController) sharedInstance] nowPlayingApplication];
    nowPlayingAppBundleID = nowPlayingApp.bundleIdentifier;
    if (nowPlayingApp != nil) {
        if ([self.icon.applicationBundleID isEqual:nowPlayingAppBundleID]) {
            [UIView animateWithDuration:1.0 animations:^{
                [self.nowPlayingImageView setAlpha:1];
            }];
        } else {
            [UIView animateWithDuration:1.0 animations:^{
                [self.nowPlayingImageView setAlpha:0];
            }];
        }
    } else {
        [UIView animateWithDuration:1.0 animations:^{
            [self.nowPlayingImageView setAlpha:0];
        }];
    }
}

%new
- (void)updateNowPlayingIconTerminated {
    // hide our view when now playing app equals nil
    SBApplication *nowPlayingApp = [[%c(SBMediaController) sharedInstance] nowPlayingApplication];
    if (nowPlayingApp == nil) {
        [UIView animateWithDuration:1.0 animations:^{
            [self.nowPlayingImageView setAlpha:0];
        }];
    }
}

%new
- (void)updateImage {
    // apply our artwork to the view and a fancy animation
    MRMediaRemoteGetNowPlayingInfo(dispatch_get_main_queue(), ^(CFDictionaryRef result) {
        if (result) {
            NSDictionary *dictionary = (__bridge NSDictionary *)result;
            NSData *artworkData = [dictionary objectForKey:(__bridge NSString *)kMRMediaRemoteNowPlayingInfoArtworkData];
            
            if (artworkData != nil) {
                if (self.nowPlayingImageView != nil) {
                    
                    CATransition *transition = [CATransition animation];
                    transition.duration = 1.0f;
                    transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
                    transition.type = kCATransitionFade;
                    [self.nowPlayingImageView.layer addAnimation:transition forKey:nil];
                    
                    UIImage *artworkImage = [UIImage imageWithData:artworkData];
                    if (artworkImage != nil) {
                        self.nowPlayingImageView.image = artworkImage;
                    }
                }
            }
        }
  });
}
%end
