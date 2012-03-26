//
//  FileBrowserAppDelegate.m
//  FileBrowser
//
//  The app delegate. It holds onto the window controller to load views
//
//  Created by Tina Wen on 7/8/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "FileBrowserAppDelegate.h"
#import "FileBrowserWindowController.h"

@implementation FileBrowserAppDelegate

@synthesize windowController = windowController_;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification 
{		
	[[self windowController] loadLoginView];
	[[[self windowController] window] makeKeyAndOrderFront:nil];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
}

@end
