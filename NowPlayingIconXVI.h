#import <UIKit/UIKit.h>

@interface SBApplication: NSObject
@property (nonatomic, readonly) NSString *bundleIdentifier;
@end

@interface SBMediaController : NSObject
+(id)sharedInstance;
- (SBApplication *)nowPlayingApplication;
@end

@interface SBIcon : NSObject
- (id)applicationBundleID;
@end

@interface SBIconImageView : UIImageView
@property (nonatomic) SBIcon *icon;
@property (nonatomic, retain) UIImageView *nowPlayingImageView;
- (void)updateImage;
- (void)setupNowPlayingIcon;
- (void)updateNowPlayingIcon;
- (void)updateNowPlayingIconVisibility;
@end
