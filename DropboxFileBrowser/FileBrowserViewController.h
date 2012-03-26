//
//  FileBrowserViewController.h
//  FileBrowser
//
//	View controller for file browser view
//
//  Created by Tina Wen on 7/9/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class FileBrowserDataSource;
@class FileBrowserWindowController;
@class DBRestClient;

@interface FileBrowserViewController : NSViewController 
{
	__weak FileBrowserWindowController *windowController_;
	IBOutlet FileBrowserDataSource *dataSource_;
    IBOutlet NSProgressIndicator *syncingSpinner_;
@private
    DBRestClient *restClient;
    double accountSpaceUsed_;
	NSString *accountSpaceUsedString_;
}

@property (readwrite, assign) FileBrowserDataSource *dataSource;
@property (readwrite, assign) FileBrowserWindowController *windowController;
@property (readonly, assign) NSProgressIndicator *syncingSpinner;
@property (readonly, assign) double accountSpaceUsed;
@property (readonly, retain) NSString *accountSpaceUsedString;

/*!
	@brief	Can all in flight file downloads
 */
- (IBAction)cancelAllFileDownloads:(id)sender;

/*!
	@brief	Open Dropbox upgrade account page to let the user upgrade account
 */
- (IBAction)upgradeAccount:(id)sender;

@end
