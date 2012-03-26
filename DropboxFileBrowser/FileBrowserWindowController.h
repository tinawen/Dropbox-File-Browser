//
//  FileBrowserWindowController.h
//  FileBrowser
//
//	Window controller for file browser app. It adds the toolbar and updates window title
//
//  Created by Tina Wen on 7/10/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DropboxOSX/DBSession.h"

@protocol FileBrowserWindowToolbarActionDelegate;
@interface FileBrowserWindowController : NSWindowController <DBSessionDelegate>
{
	id <FileBrowserWindowToolbarActionDelegate> delegate_;
	NSViewController *viewController_;
	IBOutlet NSView *view_;
}

@property (assign) id <FileBrowserWindowToolbarActionDelegate> delegate;
@property (readwrite, retain) NSViewController *viewController;
@property (readwrite, retain) NSView *view;

/*!
	@brief	Swap out the old view and replace it with login view
 */
- (void)loadLoginView;

/*!
	@brief	Swap out the old view and replace it with browser view
 */
- (void)loadBrowserView;

/*!
	@brief	Toolbar action: upload file
 */
- (void)uploadFile:(id)sender;

/*!
	@brief	Toolbar action: download file
 */
- (void)downloadFile:(id)sender;

/*!
	@brief	Toolbar action: refresh file tree
 */
- (void)refreshFileTree:(id)sender;

/*!
	@brief	Toolbar action: delete file or directory
 */
- (void)deleteFileOrDirectory:(id)sender;

/*!
	@brief	Toolbar action: logout
 */
- (void)logout:(id)sender;

@end

@protocol FileBrowserWindowToolbarActionDelegate <NSObject>

@required

- (void)uploadFile;
- (void)downloadFile;
- (void)refreshFileTree;
- (void)deleteFileOrDirectory;
- (void)logout;
- (BOOL)canLogout;

@end

