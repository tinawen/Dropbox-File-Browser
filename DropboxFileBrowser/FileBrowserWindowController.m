//
//  FileBrowserWindowController.m
//  FileBrowser
//
//	Window controller for file browser app. It adds the toolbar and updates window title
//
//  Created by Tina Wen on 7/10/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "FileBrowserWindowController.h"
#import "FileBrowserCommonKeys.h"
#import "FileBrowserLoginViewController.h"
#import "FileBrowserViewController.h"
#import "DropboxOSX/DBSession.h"

static NSString * const kUploadToolbarItemIdentifier = @"Upload Toolbar Item";
static NSString * const kDeleteToolbarItemIdentifier = @"Delete Toolbar Item";
static NSString * const kDownloadToolbarItemIdentifier = @"Download Toolbar Item";
static NSString * const kRefreshToolbarItemIdentifier = @"Refresh Toolbar Item";
static NSString * const kLogoutToolbarItemIdentifier = @"Logout Toolbar Item";

static NSString * const sAlertSheetInformativeTextErrorString = @"Please check network connection and try again";
static NSImage *sErrorImage;
static NSString * const kFileBrowserWindowDefaultTitle = @"Dropbox File Browser";

@implementation FileBrowserWindowController

@synthesize viewController = viewController_;
@synthesize view = view_;
@synthesize delegate = delegate_;

- (void)awakeFromNib
{
	[super awakeFromNib];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(errorOccured:) name:kErrorDidOccurNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowNameShouldChange:) name:kMainWindowTitleShouldChangeNotification object:nil];
	sErrorImage = [[NSImage imageNamed:@"error.png"] retain];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[viewController_ release];
	[view_ release];
	[super dealloc];
}

-(BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem
{
    if ([[toolbarItem itemIdentifier] isEqual:kUploadToolbarItemIdentifier])
	{
		if ([self delegate] && [[self delegate] respondsToSelector:@selector(uploadFile)])
			return YES;
	} 
	else if ([[toolbarItem itemIdentifier] isEqual:kDownloadToolbarItemIdentifier]) 
	{
        if ([self delegate] && [[self delegate] respondsToSelector:@selector(downloadFile)])
			return YES;
    }
	else if ([[toolbarItem itemIdentifier] isEqual:kDeleteToolbarItemIdentifier]) 
	{
        if ([self delegate] && [[self delegate] respondsToSelector:@selector(deleteFileOrDirectory)])
			return YES;
    }
	else if ([[toolbarItem itemIdentifier] isEqual:kRefreshToolbarItemIdentifier]) 
	{
        if ([self delegate] && [[self delegate] respondsToSelector:@selector(refreshFileTree)])
			return YES;
    }
	else if ([[toolbarItem itemIdentifier] isEqual:kLogoutToolbarItemIdentifier]) 
	{
        if ([self delegate] && [[self delegate] respondsToSelector:@selector(logout)])
		{
			if ([[self delegate] respondsToSelector:@selector(canLogout)])
				return [[self delegate] canLogout];
		}	
    }
	
	return NO;
}

#pragma mark toolbar item actions
- (void)uploadFile:(id)sender
{
	if ([self delegate] && [[self delegate] respondsToSelector:@selector(uploadFile)])
		[[self delegate] uploadFile];
}

- (void)downloadFile:(id)sender
{
	if ([self delegate] && [[self delegate] respondsToSelector:@selector(downloadFile)])
		[[self delegate] downloadFile];
}

- (void)refreshFileTree:(id)sender
{
	if ([self delegate] && [[self delegate] respondsToSelector:@selector(refreshFileTree)])
		[[self delegate] refreshFileTree];
}

- (void)deleteFileOrDirectory:(id)sender
{
	if ([self delegate] && [[self delegate] respondsToSelector:@selector(deleteFileOrDirectory)])
		[[self delegate] deleteFileOrDirectory];
}

- (void)logout:(id)sender
{
	if ([self delegate] && [[self delegate] respondsToSelector:@selector(logout)])
		[[self delegate] logout];
	[self loadLoginView];
}

- (void)loadLoginView 
{
	// Use my developer key and secrete
    NSString* consumerKey = @"6om0tlafu7t4fqg";
	NSString* consumerSecret = @"oaq6oybnuw9uf7c";
	
	// set up DB session
	DBSession* session = [[DBSession alloc] initWithAppKey:consumerKey appSecret:consumerSecret root:@"dropbox"];
	session.delegate = self; 
	[DBSession setSharedSession:session];
    [session release];
	
	//hide the toolbar for login view
	[[[self window] toolbar] setVisible:NO];
	
	//set the viewController
	NSViewController *loginViewController = [[[FileBrowserLoginViewController alloc] initWithNibName:@"LogInView" bundle:nil] autorelease];
	[self setViewController:loginViewController];
	[(FileBrowserLoginViewController *)[self viewController] setWindowController:self];	

	[[[self viewController] view] setFrameSize:NSMakeSize([[self view] frame].size.width, [[self view] frame].size.height)];
	// load the old view with loginView
	if ([[[self view] subviews] count])
		[[self view] replaceSubview:[[[self view]subviews] objectAtIndex:0] with:[[self viewController] view]];
	
	//set window title
	[[self window] setTitle:kFileBrowserWindowDefaultTitle];
    
}

- (void)loadBrowserView
{
	//show the toolbar for browser view
	[[[self window] toolbar] setVisible:YES];
	
	//set the view controller
	NSViewController *fileBrowserViewController = [[[FileBrowserViewController alloc] initWithNibName:@"BrowserView" bundle:nil] autorelease];
	[self setViewController:fileBrowserViewController];
	[(FileBrowserViewController *)[self viewController] setWindowController:self];
    
    [[[self viewController] view] setFrameSize:NSMakeSize([[self view] frame].size.width, [[self view] frame].size.height)];
	if ([[[self view] subviews] count])
		[[self view] replaceSubview:[[[self view]  subviews] objectAtIndex:0] with:[[self viewController] view]];
}

#pragma mark notification selectors
- (void)errorOccured:(NSNotification *)notification
{
	//only display an error sheet if there isn't any already displaying
	if (![[self window] attachedSheet])
	{
		NSDictionary *userInfo = [notification userInfo];
		if ([userInfo isKindOfClass:[NSDictionary class]])
		{
			NSString *messagText = [userInfo valueForKey:kAlertSheetTitleErrorStringKey];
			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			[alert addButtonWithTitle:@"OK"];
			[alert setMessageText:messagText];
			[alert setInformativeText:sAlertSheetInformativeTextErrorString];
			[alert setAlertStyle:NSWarningAlertStyle];
			[alert setIcon:sErrorImage];
			[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
		}
	}
}

- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo 
{
	//user can only hit the first button to dismiss
}
 
- (void)windowNameShouldChange:(NSNotification *)notification
{
	NSDictionary *userInfo = [notification userInfo];
	if ([userInfo isKindOfClass:[NSDictionary class]])
	{
		NSString *newWindowTitle = [userInfo valueForKey:kMainWindowNewTitleKey];
		[[self window] setTitle:newWindowTitle];
	}
}

#pragma mark -
#pragma mark DBSessionDelegate methods
- (void)sessionDidReceiveAuthorizationFailure:(DBSession *)session userId:(NSString *)userId
{
	NSLog(@"Authorization failed for userId %@! Check key and secret!", userId);
}
@end
