//
//  FileBrowserLoginController.h
//  FileBrowser
//
//  The view controller for login view
//
//  Created by Tina Wen on 7/8/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class DBRestClient;
@class FileBrowserWindowController;

@interface FileBrowserLoginViewController : NSViewController 
{
	__weak FileBrowserWindowController *windowController_;
   
@private
	DBRestClient* restClient;
	BOOL errorOccurred_;
}

@property (readwrite, assign) FileBrowserWindowController *windowController;

/*!
 @brief	After the login button is clicked, attempt to contact the server
 to login
 */
- (IBAction)didClickConnect:(id)sender;

@end
