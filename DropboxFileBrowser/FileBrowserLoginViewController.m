//
//  FileBrowserLoginController.m
//  FileBrowser
//
//  The view controller for login view
//
//  Created by Tina Wen on 7/8/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <DropboxOSX/DropboxOSX.h>
#import "FileBrowserLoginViewController.h"
#import "DropboxOSX/DBRestClient.h"
#import "FileBrowserWindowController.h"

@interface FileBrowserLoginViewController () <DBRestClientDelegate, DBRestClientOSXDelegate>

@property (readwrite, assign) BOOL errorOccured;
@property (nonatomic, retain) NSString *requestToken;

@end

@implementation FileBrowserLoginViewController

@synthesize errorOccured = errorOccured_;
@synthesize windowController = windowController_;
@synthesize requestToken = requestToken_;

- (void)awakeFromNib
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appBecomeActive) name:NSApplicationDidBecomeActiveNotification object:nil];
}

- (void)dealloc
{
	[restClient release];
	
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];	
}

- (DBRestClient*)restClient 
{
	//only allocate one instance of restClient
    if (restClient == nil) 
	{
        restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
        [restClient setDelegate:self];
    }
    return restClient;
}

- (void)updateViewFromOAuthState
{
    if ([[DBSession sharedSession] isLinked]) 
    {
        [self setErrorOccured:NO];
        [[self windowController] loadBrowserView];
    }
    
    else
    {
        if ([[self restClient] requestTokenLoaded]) 
            [[self restClient] loadAccessToken];
    }
}

- (void)loadView
{
    [super loadView];
    [self updateViewFromOAuthState];
}

- (void)appBecomeActive
{
    [self updateViewFromOAuthState];
}

- (IBAction)didClickConnect:(id)sender
{
	if ([[DBSession sharedSession] isLinked]) 
    {
		[[DBSession sharedSession] unlinkAll];
		restClient = nil;
	} 
    else if (![[self restClient] requestTokenLoaded]) 
		[[self restClient] loadRequestToken];
    else 
        [[self restClient] loadAccessToken];
}

#pragma mark DBRestClientOSXDelegate methods

- (void)restClientLoadedRequestToken:(DBRestClient *)restClient 
{
	NSURL *url = [[self restClient] authorizeURL];
	[[NSWorkspace sharedWorkspace] openURL:url];
}

- (void)restClient:(DBRestClient *)restClient loadRequestTokenFailedWithError:(NSError *)error 
{
    [self setErrorOccured:YES];
    NSLog(@"load request token failed, error is %@", error);
}

// callback after logged in successfully
- (void)restClientLoadedAccessToken:(DBRestClient *)restClient 
{
	[self setErrorOccured:NO];	
	[[self windowController] loadBrowserView];
}

//callback after login failed
- (void)restClient:(DBRestClient *)restClient loadAccessTokenFailedWithError:(NSError *)error 
{
	[self setErrorOccured:YES];
    NSLog(@"load access token failed, error is %@", error);
}
@end
