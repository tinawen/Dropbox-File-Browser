//
//  FileBrowserViewController.m
//  FileBrowser
//
//	View controller for file browser view
//
//  Created by Tina Wen on 7/9/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "FileBrowserViewController.h"

#import "FileSystemItem.h"
#import "FileBrowserCommonKeys.h"
#import "FileBrowserDataSource.h"
#import "DropboxOSX/DBAccountInfo.h"
#import "DropboxOSX/DBRestClient.h"
#import "DropboxOSX/DBQuota.h"

static NSString * const kDropboxURLToUpgradeAccount = @"https://www.dropbox.com/plans";

@interface FileBrowserViewController () <DBRestClientDelegate>

@property (readwrite, assign) double accountSpaceUsed;
@property (readwrite, retain) NSString *accountSpaceUsedString;

- (void)retrieveAccountInfo;

@end

@implementation FileBrowserViewController

@synthesize dataSource = dataSource_;
@synthesize windowController = windowController_;
@synthesize syncingSpinner = syncingSpinner_;
@synthesize accountSpaceUsed = accountSpaceUsed_;
@synthesize accountSpaceUsedString = accountSpaceUsedString_;

- (void)awakeFromNib
{
	[super awakeFromNib];
	[[self windowController] setDelegate:[self dataSource]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(syncingStarted) name:kFileBrowserStartSyncingNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(syncingStopped) name:kFileBrowserStopSyncingNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(shouldUpdateAccountInfo) name:kFileBrowserShouldUpdateAccountInfoNotification object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [accountSpaceUsedString_ release];
	[super dealloc];
}

- (DBRestClient*)restClient 
{
    if (restClient == nil) 
	{
        restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
        [restClient setDelegate:self];
    }
    return restClient;
}

- (void)retrieveAccountInfo
{
	[[self restClient] loadAccountInfo];
}

#pragma mark File operations with Dropbox
- (IBAction)cancelAllFileDownloads:(id)sender
{
	[[self dataSource] cancelAllFileDownloads];
}

- (IBAction)upgradeAccount:(id)sender;
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:kDropboxURLToUpgradeAccount]];
}

#pragma mark notifications
- (void)syncingStarted
{
    [[self syncingSpinner] startAnimation:nil];
}

- (void)syncingStopped
{
    [[self syncingSpinner] stopAnimation:nil];
}

- (void)shouldUpdateAccountInfo
{
    [self retrieveAccountInfo];
}

#pragma mark load account info

- (void)restClient:(DBRestClient*)client loadedAccountInfo:(DBAccountInfo*)info
{
	if (![self accountSpaceUsed])
	{
		DBQuota *quota = [info quota];
		NSString *displayName = [info displayName];
		//1 giga byte
		long long oneGigaByte = 1000000000;
		double consumedBytes = (double)[quota normalConsumedBytes];
		double totalBytes = (double)[quota totalBytes];
		double spaceUsed = consumedBytes / totalBytes;
		[self setAccountSpaceUsed:spaceUsed * 100];
		double consumedGigaByte = consumedBytes / oneGigaByte;
		double totalGigaByte = totalBytes / oneGigaByte;
		NSString *spaceUsedString = [NSString stringWithFormat:@"%.2f of %.2f GB", consumedGigaByte, totalGigaByte];
		[self setAccountSpaceUsedString:spaceUsedString];
		NSDictionary *userInfo = [NSDictionary dictionaryWithObject:displayName forKey:kMainWindowNewTitleKey];
		[[NSNotificationCenter defaultCenter] postNotificationName:kMainWindowTitleShouldChangeNotification object:nil userInfo:userInfo];
    }
}

- (void)restClient:(DBRestClient*)client loadAccountInfoFailedWithError:(NSError*)error
{
	//don't want to interrupt the user
	NSLog(@"error loading account info. only log to the consoles");
}
@end
