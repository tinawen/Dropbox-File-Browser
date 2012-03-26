//
//  FileBrowserCommonKeys.h
//  DropboxFileBrowser
//
//  Created by tina on 3/20/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

//notifications and keys
extern NSString * const kErrorDidOccurNotification;
extern NSString * const kMainWindowTitleShouldChangeNotification;
extern NSString * const kMainWindowNewTitleKey;
extern NSString * const kAlertSheetTitleErrorStringKey;
extern NSString * const kFileBrowserStartSyncingNotification;
extern NSString * const kFileBrowserStopSyncingNotification;
extern NSString * const kFileBrowserShouldUpdateAccountInfoNotification;

@interface FileBrowserCommonKeys : NSObject

@end
