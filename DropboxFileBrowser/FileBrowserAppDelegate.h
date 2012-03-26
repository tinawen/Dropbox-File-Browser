//
//  FileBrowserAppDelegate.h
//  FileBrowser
//	
//	The app delegate. It holds onto the window controller to load views
//
//  Created by Tina Wen on 7/8/11.
//  Copyright 2011. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class FileBrowserWindowController;
@interface FileBrowserAppDelegate : NSObject <NSApplicationDelegate> 
{
	NSView *view_;
	FileBrowserWindowController *windowController_;
}

@property (assign) IBOutlet FileBrowserWindowController *windowController;

@end

