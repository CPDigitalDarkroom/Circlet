//
//  Circlet.xm
//  Circlet
//
//  Created by Julian Weiss on 1/5/14.
//  Copyright (c) 2014 insanj. All rights reserved.
//

#import "CRHeaders.h"
#import "CRNotificationListener.h"
#import "CRView.h"

/******************** SpringBoard (foreground) Methods ********************/

%hook SBUIController
static BOOL kCRUnlocked;

-(void)_deviceLockStateChanged:(NSNotification *)changed{
	%orig();

	NSNumber *state = changed.userInfo[@"kSBNotificationKeyState"];
	if(!state.boolValue)
		kCRUnlocked = YES;
}//end m
%end

@interface SBUIAnimationController (Circlet)
-(void)dismissWithClickedButtonIndex:(NSInteger)buttonIndex animated:(BOOL)animated;
@end

%hook SBUIAnimationController
-(void)endAnimation{
	%orig();

	if(kCRUnlocked && ![[NSUserDefaults standardUserDefaults] boolForKey:@"CRDidRun"]){
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"CRDidRun"];
		[[[UIAlertView alloc] initWithTitle:@"Circlet" message:@"Welcome to Circlet. Set up your first circles by tapping Begin, or configure them later in Settings. Thanks for the dollar, I promise not to disappoint." delegate:self cancelButtonTitle:@"Later" otherButtonTitles:@"Begin", nil] show];
	}//end if
}

%new -(void)dismissWithClickedButtonIndex:(NSInteger)buttonIndex animated:(BOOL)animated{
	if(buttonIndex != 0){
		dispatch_async(dispatch_get_main_queue(), ^{
			[(SpringBoard *)[UIApplication sharedApplication] applicationOpenURL:[NSURL URLWithString:@"prefs:root=Circlet"] publicURLsOnly:NO];
		});
	}
}
%end	

@interface SpringBoard (Circlet)
-(void)circlet_generateCirclesFresh:(id)listener;
-(void)circlet_saveCircle:(CRView *)circle toPath:(NSString *)path withWhite:(UIColor *)white black:(UIColor *)black count:(int)count;
-(void)circlet_saveCircle:(CRView *)circle toPath:(NSString *)path withName:(NSString *)name;
@end

%hook SpringBoard

-(id)init{
	if(![NSDictionary dictionaryWithContentsOfFile:[NSHomeDirectory() stringByAppendingPathComponent:@"/Library/Preferences/com.insanj.circlet.plist"]])
		[self circlet_generateCirclesFresh:[CRNotificationListener sharedListener]];

	return %orig();
}

%new -(void)circlet_generateCirclesFresh:(CRNotificationListener *)listener{ 
	NSError *error;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	[fileManager removeItemAtPath:@"/private/var/mobile/Library/Circlet" error:&error];

	if(listener.signalEnabled){
		[listener.signalCircle setRadius:(listener.signalPadding / 2.0)];
		[self circlet_saveCircle:listener.signalCircle toPath:@"/private/var/mobile/Library/Circlet/Signal" withWhite:listener.signalWhiteColor black:listener.signalBlackColor count:5];
	}

	if(listener.wifiEnabled){
		[listener.wifiCircle setRadius:(listener.wifiPadding / 2.0)];
		[self circlet_saveCircle:listener.wifiCircle toPath:@"/private/var/mobile/Library/Circlet/Wifi" withWhite:listener.wifiWhiteColor black:listener.signalBlackColor count:3];
		[self circlet_saveCircle:listener.wifiCircle toPath:@"/private/var/mobile/Library/Circlet/Data" withWhite:listener.dataWhiteColor black:listener.dataBlackColor count:1];
	}

	if(listener.batteryEnabled){
		[listener.batteryCircle setRadius:(listener.batteryPadding / 2.0)];
		[self circlet_saveCircle:listener.batteryCircle toPath:@"/private/var/mobile/Library/Circlet/Battery" withWhite:listener.batteryWhiteColor black:listener.batteryBlackColor count:20];
		[self circlet_saveCircle:listener.wifiCircle toPath:@"/private/var/mobile/Library/Circlet/Charging" withWhite:listener.chargingWhiteColor black:listener.chargingBlackColor count:20];
	}
}

%new -(void)circlet_saveCircle:(CRView *)circle toPath:(NSString *)path withWhite:(UIColor *)white black:(UIColor *)black count:(int)count{

	NSError *error;
	NSFileManager *fileManager = [[NSFileManager alloc] init];
	if([fileManager fileExistsAtPath:path])
		return;

	[fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
	
	CRView *whiteCircle = [circle versionWithColor:white];
	CRView *blackCircle = [circle versionWithColor:black];

	for(int i = 0; i < count; i++){
		[whiteCircle setState:i withMax:count];
		[blackCircle setState:i withMax:count];

		[self circlet_saveCircle:whiteCircle toPath:path withName:[NSString stringWithFormat:@"/%iWhite@2x.png", i]];
		[self circlet_saveCircle:blackCircle toPath:path withName:[NSString stringWithFormat:@"/%iBlack@2x.png", i]];
	}

	NSLog(@"[Circlet] Wrote %i circle-views to directory: %@", count, [fileManager contentsOfDirectoryAtPath:path error:&error]);
}

%new -(void)circlet_saveCircle:(CRView *)circle toPath:(NSString *)path withName:(NSString *)name{
	UIGraphicsBeginImageContextWithOptions(circle.bounds.size, NO, 0.0);
    [circle.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

	[UIImagePNGRepresentation(image) writeToFile:[path stringByAppendingString:name] atomically:YES];
}

%end

/**************************** StatusBar Image Replacment  ****************************/

%hook UIStatusBarSignalStrengthItemView
static CRNotificationListener *signalListener;
static BOOL shouldOverrideSignal;
static NSMutableArray *signalImages;

-(id)initWithItem:(UIStatusBarItem *)arg1 data:(id)arg2 actions:(int)arg3 style:(id)arg4{
	signalListener = [CRNotificationListener sharedListener];
	shouldOverrideSignal = [signalListener enabledForClassname:@"UIStatusBarSignalStrengthItemView"];
	[signalListener debugLog:[NSString stringWithFormat:@"Override preferences for classname \"%@\" are set to %@.", NSStringFromClass([%orig() class]), shouldOverrideSignal?@"override":@"ignore"]];
	if(shouldOverrideSignal){
		signalImages = [[NSMutableArray alloc] init];
		for(int i = 0; i < 5; i++){
			[signalImages addObject:@[[UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"/private/var/mobile/Library/Circlet/Signal/%iWhite@2x.png", i]], [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"/private/var/mobile/Library/Circlet/Signal/%iBlack@2x.png", i]]]];
		}
	}

	return %orig();
}


-(_UILegibilityImageSet *)contentsImage{
	if(signalImages){
		CGFloat w, a;
		[[[self foregroundStyle] textColorForStyle:[self legibilityStyle]] getWhite:&w alpha:&a];
		int bars = MSHookIvar<int>(self, "_signalStrengthBars") - 1;

		UIImage *white = (w > 0.5)?[[signalImages objectAtIndex:bars] firstObject]:[[signalImages objectAtIndex:bars] lastObject];
		UIImage *black = (w > 0.5)?[[signalImages objectAtIndex:bars] lastObject]:[[signalImages objectAtIndex:bars] firstObject];

		return [%c(_UILegibilityImageSet) imageFromImage:white withShadowImage:black];
	}

	return %orig();
}

%end

%hook UIStatusBarDataNetworkItemView

-(_UILegibilityImageSet *)contentsImage{
	CRNotificationListener *listener = [CRNotificationListener sharedListener];
	BOOL shouldOverride = [listener enabledForClassname:@"UIStatusBarDataNetworkItemView"];
	[listener debugLog:[NSString stringWithFormat:@"Override preferences for classname \"UIStatusBarDataNetworkItemView\" are set to %@.", shouldOverride?@"override":@"ignore"]];

	if(shouldOverride){
		int networkType = MSHookIvar<int>(self, "_dataNetworkType");
		int wifiState = MSHookIvar<int>(self, "_wifiStrengthBars") - 1;
		UIImage *white, *black;
		if(networkType == 5){
			white = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"/private/var/mobile/Library/Circlet/Wifi/%iWhite@2x.png", wifiState]];
			black = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"/private/var/mobile/Library/Circlet/Wifi/%iBlack@2x.png", wifiState]];
		}

		else{
			white = [UIImage imageWithContentsOfFile:@"/private/var/mobile/Library/Circlet/Data/0White@2x.png"];
			black = [UIImage imageWithContentsOfFile:@"/private/var/mobile/Library/Circlet/Data/0Black@2x.png"];
		}

		CGFloat w, a;
		[[[self foregroundStyle] textColorForStyle:[self legibilityStyle]] getWhite:&w alpha:&a];

		return (w > 0.5)?[%c(_UILegibilityImageSet) imageFromImage:white withShadowImage:black]:[%c(_UILegibilityImageSet) imageFromImage:black withShadowImage:white];
	}//end if override

	return %orig();
}

%end

%hook UIStatusBarBatteryItemView

-(_UILegibilityImageSet *)contentsImage{
	CRNotificationListener *listener = [CRNotificationListener sharedListener];
	BOOL shouldOverride = [listener enabledForClassname:@"UIStatusBarBatteryItemView"];
	[listener debugLog:[NSString stringWithFormat:@"Override preferences for classname \"UIStatusBarBatteryItemView\" are set to %@.", shouldOverride?@"override":@"ignore"]];

	if(shouldOverride){	
		int level = ceilf((MSHookIvar<int>(self, "_capacity")) * (19.0/100.0));
		int state = MSHookIvar<int>(self, "_state");
		UIImage *white, *black;
		if(state != 0){
			white = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"/private/var/mobile/Library/Circlet/Charging/%iWhite@2x.png", level]];
			black = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"/private/var/mobile/Library/Circlet/Charging/%iBlack@2x.png", level]];
		}

		else{
			white = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"/private/var/mobile/Library/Circlet/Battery/%iWhite@2x.png", level]];
			black = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"/private/var/mobile/Library/Circlet/Battery/%iBlack@2x.png", level]];			
		}

		CGFloat w, a;
		[[[self foregroundStyle] textColorForStyle:[self legibilityStyle]] getWhite:&w alpha:&a];

		return (w > 0.5)?[%c(_UILegibilityImageSet) imageFromImage:white withShadowImage:black]:[%c(_UILegibilityImageSet) imageFromImage:black withShadowImage:white];
	}//end if override

	return %orig();
}

%end

/**************************** Item View Spacing  ****************************/

%hook UIStatusBarLayoutManager
CGFloat signalWidth;

-(CGRect)_frameForItemView:(UIStatusBarItemView *)arg1 startPosition:(float)arg2{
	CRNotificationListener *listener = [CRNotificationListener sharedListener];
	NSString *className = NSStringFromClass([arg1 class]);

	if([className isEqualToString:@"UIStatusBarSignalStrengthItemView"])
		signalWidth = %orig().size.width;

	else if([className isEqualToString:@"UIStatusBarServiceItemView"])
		signalWidth += %orig().size.width;

	else if([className isEqualToString:@"UIStatusBarDataNetworkItemView"] && [listener enabledForClassname:className])
		return CGRectMake(signalWidth + listener.wifiPadding - 1.0, %orig().origin.y, %orig().size.width, %orig().size.height);

	else if([className isEqualToString:@"UIStatusBarBatteryItemView"] && [listener enabledForClassname:className]){
		int state = MSHookIvar<int>(arg1, "_state");
		if(state != 0)
			[[[arg1 subviews] lastObject] setHidden:YES];
	}

	return %orig();
}
%end