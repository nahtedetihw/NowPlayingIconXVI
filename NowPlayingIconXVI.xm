/*
 * Tweak.xm
 * NowPlayingIcon
 *
 * Created by Ethan Whited <ethanwhited2208@gmail.com> on 12/19/2022.
 * Copyright © 2022 Ethan Whited <ethanwhited2208@gmail.com>. All rights reserved.
 */

// original tweak https://github.com/LacertosusRepo/Open-Source-Tweaks/tree/master/NowPlayingIcon

#import "MediaRemote.h"
#import "NowPlayingIconXVI.h"

NSString *lastNowPlayingBundleID;
UIImage *currentArtwork;
UIImage *currentMaskedArtwork;
static dispatch_once_t onceToken;

%hook SBMediaController
-(void)_setNowPlayingApplication:(id)arg1 {
    %orig;
    if (arg1 != nil) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"NowPlayingAppChanged" object:nil];
    } else {
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

%hook SBIconController
-(instancetype)initWithApplicationController:(id)arg1 applicationPlaceholderController:(id)arg2 userInterfaceController:(id)arg3 policyAggregator:(id)arg4 alertItemsController:(id)arg5 assistantController:(id)arg6 {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nowPlayingAppDidChange) name:@"NowPlayingAppChanged" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nowPlayingAppDidTerminate) name:@"NowPlayingAppTerminated" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nowPlayingInfoDidChange) name:@"NowPlayingInfoChanged" object:nil];
  return %orig;
}

-(id)initWithApplicationController:(id)arg1 applicationPlaceholderController:(id)arg2 userInterfaceController:(id)arg3 policyAggregator:(id)arg4 alertItemsController:(id)arg5 assistantController:(id)arg6 powerLogAggregator:(id)arg7 {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nowPlayingAppDidChange) name:@"NowPlayingAppChanged" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nowPlayingAppDidTerminate) name:@"NowPlayingAppTerminated" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nowPlayingInfoDidChange) name:@"NowPlayingInfoChanged" object:nil];
    return %orig;
}

- (id)initWithMainDisplayWindowScene:(id)arg1 {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nowPlayingAppDidChange) name:@"NowPlayingAppChanged" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nowPlayingAppDidTerminate) name:@"NowPlayingAppTerminated" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nowPlayingInfoDidChange) name:@"NowPlayingInfoChanged" object:nil];
    return %orig;
}

%new
-(void)nowPlayingInfoDidChange {
    MRMediaRemoteGetNowPlayingInfo(dispatch_get_main_queue(), ^(CFDictionaryRef information) {
        //Check if artwork image is the same
        NSDictionary *nowPlayingInfo = (__bridge NSDictionary *)information;
        NSData *artworkData = [nowPlayingInfo objectForKey:(__bridge NSString *)kMRMediaRemoteNowPlayingInfoArtworkData];
        if (artworkData) {
            NSData *oldArtworkData = UIImageJPEGRepresentation(currentArtwork, 1.0);
            NSData *newArtworkData = UIImageJPEGRepresentation([UIImage imageWithData:artworkData], 1.0);
            if ([oldArtworkData isEqualToData:newArtworkData]) {
                //HBLogInfo(@"NowPlayingIcon || Duplicate artwork data");
                return;
            } else {
                currentArtwork = [UIImage imageWithData:artworkData];
            }

            SBIconController *iconController = [%c(SBIconController) sharedInstance];
            SBApplication *nowPlayingApp = [[%c(SBMediaController) sharedInstance] nowPlayingApplication];
            NSString *bundleID = nowPlayingApp.bundleIdentifier;
            if (bundleID != nil) {
            SBApplicationIcon *appIcon = [iconController.model applicationIconForBundleIdentifier:bundleID];
            
            //Set artwork for app
            [self setNowPlayingArtworkForApp:appIcon withArtwork:currentArtwork];
            lastNowPlayingBundleID = nowPlayingApp.bundleIdentifier;
            }
        }
    });
}

%new
-(void)nowPlayingAppDidChange {
    //Reset last icon when the app has changed or the now playing app is killed
    SBIconController *iconController = [%c(SBIconController) sharedInstance];
    if (lastNowPlayingBundleID != nil) {
        SBApplicationIcon *appIcon = [iconController.model applicationIconForBundleIdentifier:lastNowPlayingBundleID];
        
        if ([appIcon application]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __NSSingleObjectArrayI *iconsToPurge = [%c(__NSSingleObjectArrayI) arrayWithObjects:appIcon, nil];
                [[iconController.iconManager iconImageCache] purgeCachedImagesForIcons:iconsToPurge];
                [[iconController.iconManager iconImageCache] notifyObserversOfUpdateForIcon:appIcon];
            });
        }
    }
}

%new
-(void)nowPlayingAppDidTerminate {
    //Reset last icon when the now playing app is killed
    SBIconController *iconController = [%c(SBIconController) sharedInstance];
    if (lastNowPlayingBundleID != nil) {
        SBApplicationIcon *appIcon = [iconController.model applicationIconForBundleIdentifier:lastNowPlayingBundleID];
        
        if ([appIcon application]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __NSSingleObjectArrayI *iconsToPurge = [%c(__NSSingleObjectArrayI) arrayWithObjects:appIcon, nil];
                [[iconController.iconManager iconImageCache] purgeCachedImagesForIcons:iconsToPurge];
                [[iconController.iconManager iconImageCache] notifyObserversOfUpdateForIcon:appIcon];
            });
        }
    }
}

%new
-(void)setNowPlayingArtworkForApp:(SBApplicationIcon *)appIcon withArtwork:(UIImage *)artwork {
    if (appIcon && artwork) {
        SBHIconImageCache *imageCacheHS = [self.iconManager iconImageCache];
        SBFolderIconImageCache *imageCacheFLDR = [self.iconManager folderIconImageCache];
        NSArray *imageCaches = @[imageCacheHS,
                            self.appSwitcherHeaderIconImageCache,];

        CALayer *maskLayer = [CALayer layer];
        maskLayer.frame = CGRectMake(0, 0, artwork.size.width, artwork.size.height);
        maskLayer.contents = (id)imageCacheHS.overlayImage.CGImage;

        CALayer *artLayer = [CALayer layer];
        artLayer.frame = CGRectMake(0, 0, artwork.size.width, artwork.size.height);
        artLayer.contents = (id)artwork.CGImage;
        artLayer.masksToBounds = YES;
        artLayer.mask = maskLayer;

        UIGraphicsBeginImageContext(artwork.size);
        [artLayer renderInContext:UIGraphicsGetCurrentContext()];
        currentMaskedArtwork = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        //Update icon image caches and notify
        for (SBHIconImageCache *cache in imageCaches) {
            [cache cacheImage:currentMaskedArtwork forIcon:appIcon];
            [cache notifyObserversOfUpdateForIcon:appIcon];
        }
        [imageCacheFLDR iconImageCache:imageCacheHS didUpdateImageForIcon:appIcon];
    }
}
%end

%hook SBIconImageCrossfadeView
//iOS 13
-(instancetype)initWithImageView:(SBIconImageView *)arg1 crossfadeView:(UIView *)arg2 {
    SBIcon *icon = [arg1 icon];
    SBApplication *nowPlayingApp = [[%c(SBMediaController) sharedInstance] nowPlayingApplication];
    if ([[icon applicationBundleID] isEqualToString:nowPlayingApp.bundleIdentifier] && currentMaskedArtwork) {
        CATransition *transition = [CATransition animation];
        transition.duration = 1.0f;
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        transition.type = kCATransitionFade;
        [arg1.layer addAnimation:transition forKey:nil];
      
        arg1.layer.contents = (id)currentMaskedArtwork.CGImage;
    }
    return %orig;
}

//iOS 14
-(instancetype)initWithSource:(SBIconImageView *)arg1 crossfadeView:(UIView *)arg2 {
    SBIcon *icon = [arg1 icon];
    SBApplication *nowPlayingApp = [[%c(SBMediaController) sharedInstance] nowPlayingApplication];
    if ([[icon applicationBundleID] isEqualToString:nowPlayingApp.bundleIdentifier] && currentMaskedArtwork) {
        CATransition *transition = [CATransition animation];
        transition.duration = 1.0f;
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        transition.type = kCATransitionFade;
        [arg1.layer addAnimation:transition forKey:nil];
        
        arg1.layer.contents = (id)currentMaskedArtwork.CGImage;
    }
    return %orig;
}
%end
