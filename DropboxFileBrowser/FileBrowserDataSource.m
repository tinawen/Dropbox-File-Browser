//
//  FileBrowserDataSource.m
//  FileBrowser
//
//	The data source and delegate of the file browser outline view
//	It's also a delegate of DBRestClient. It does all the heavy lifting to update data
//	FileDownloadItems are objects in file download queue
//
//  Created by Tina Wen on 7/8/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "FileBrowserDataSource.h"
#import "DropboxOSX/DBMetadata.h"
#import "FileBrowserCommonKeys.h"
#import "FileSystemItem.h"
#import "DropboxOSX/DBRestClient.h"
#import "FileBrowserWindowController.h"

static NSMutableDictionary *sFilesToOpenAfterDownloading;
static NSMutableArray *sFileDownloadQueue;
static NSSortDescriptor *sSortDescriptor;

static NSString * const sAlertSheetMessageTextUploadingErrorString = @"Error Uploading!";
static NSString * const sAlertSheetMessageTextDownloadingErrorString = @"Error Downloading!";
static NSString * const sAlertSheetMessageTextSyncingErrorString = @"Error Loading File Structure!";
static NSString * const sAlertSheetMessageTextDeletingErrorString = @"Error Deleting File or Directory!";

static NSString * const sDefaultDownloadStorageLocation = @"~/Downloads/Dropbox/";

static NSString * const sProgressIndicatorStringForDownloads = @"Downloading...";
static NSString * const sProgressIndicatorStringForUploads = @"Uploading...";
static NSString * const sProgressIndicatorStringForDeleting = @"Deleting folder...";
static NSString * const sProgressIndicatorStringForSyncing = @"Syncing...";

@interface FileDownloadItem ()

@property (readwrite, retain) FileSystemItem *fileItem;
@property (readwrite, retain) NSString *srcPath;
@property (readwrite, retain) NSString *destPath;
@property (readwrite, assign) BOOL openAfterDownload;

@end

@implementation FileDownloadItem

@synthesize fileItem = fileItem_;
@synthesize srcPath = srcPath_;
@synthesize destPath = destPath_;
@synthesize openAfterDownload = openAfterDownload_;

- (id)initWithFileItem:(FileSystemItem *)item srcPath:(NSString *)sourcePath destPath:(NSString *)destinationPath openAfterDownload:(BOOL)open
{
	self = [super init];
	if (self)
	{
		[self setFileItem:item];
		[self setSrcPath:sourcePath];
		[self setDestPath:destinationPath];
		[self setOpenAfterDownload:open];
	}
	return self;
}

- (void)dealloc
{
	[fileItem_ release];
	[srcPath_ release];
	[destPath_ release];
	
	[super dealloc];
}

@end


@interface FileBrowserDataSource() <DBRestClientDelegate, FileBrowserWindowToolbarActionDelegate>

@property (readwrite, assign) NSOutlineView *outlineView;
@property (readwrite, assign) BOOL isWorking;
@property (readwrite, assign) CGFloat workingProgress;
@property (readwrite, retain) NSString *workingString;
@property (readwrite, assign) BOOL canCancelProgress;
@property (readwrite, retain) FileDownloadItem *inflightDownload;
@property (readwrite, assign) NSUInteger metadataRequestInflight;
@property (readwrite, assign) BOOL isSyncingFileStructure;
@property (readwrite, retain) NSTimer *errorTrackingTimer;
@property (readwrite, assign) BOOL progressUpdated;
@property (readwrite, retain) FileSystemItem *folderToSyncAfterUpload;
@property (readwrite, retain) FileSystemItem *folderToSyncAfterDelete;
@property (readwrite, retain) FileSystemItem *syncingFolder;

- (void)sortFiles;
- (void)refreshFilesForFileItemChildren:(FileSystemItem *)fileItem;

@end

@implementation FileBrowserDataSource

@synthesize outlineView = outlineView_;
@synthesize isWorking = isWorking_;
@synthesize workingProgress = workingProgress_;
@synthesize workingString = workingString_;
@synthesize canCancelProgress = canCancelProgress_;
@synthesize inflightDownload = inflightDownload_;
@synthesize metadataRequestInflight = metadataRequestInflight_;
@synthesize isSyncingFileStructure = isSyncingFileStructure_;
@synthesize errorTrackingTimer = errorTrackingTimer_;
@synthesize progressUpdated = progressUpdated_;
@synthesize folderToSyncAfterUpload = folderToSyncAfterUpload_;
@synthesize folderToSyncAfterDelete = folderToSyncAfterDelete_;
@synthesize syncingFolder = syncingFolder_;

- (DBRestClient*)restClient 
{
    if (restClient == nil) 
	{
        restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
        [restClient setDelegate:self];
    }
    return restClient;
}

- (void)awakeFromNib
{
	[super awakeFromNib];
	sFilesToOpenAfterDownloading = [[NSMutableDictionary dictionary] retain];
	sFileDownloadQueue = [[NSMutableArray array] retain];
	sSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"fullPath.lastPathComponent" ascending:YES];
	
	[FileSystemItem initialize];
	// force refresh all file structure
	[self refreshFileTree];
	
	[self setInflightDownload:nil];
}

- (void)dealloc
{
	[restClient release];
	[workingString_ release];
	[inflightDownload_ release];
	[errorTrackingTimer_ release];
	[folderToSyncAfterUpload_ release];
	[folderToSyncAfterDelete_ release];
	[syncingFolder_ release];
	
	[super dealloc];
}

#pragma mark NSOutlineView datasource and delegate methods

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item 
{	
	return (item == nil) ? [[[FileSystemItem rootItem] children] count] : [[item children] count];
}


- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item 
{
    //	return (item == nil) ? YES : ([[item children] count] > 0);
	return  [item isDirectory];
}


- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item 
{	
	if (item == nil) 
	{
		if (index < [[[FileSystemItem rootItem] children] count])
			return [[[FileSystemItem rootItem] children] objectAtIndex:index];
	}
	else 
	{
		if (index < [[(FileSystemItem *)item children] count])
			return [[(FileSystemItem *)item children] objectAtIndex:index];
	}
	return nil;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if ([[tableColumn identifier] isEqualToString:@"fileName"])
	{
		if (item)	
			return [[item fullPath] lastPathComponent];
	}
	else if ([[tableColumn identifier] isEqualToString:@"fileSize"])
	{
		if (item)	
			return [(FileSystemItem *)item fileSize];
	}
	return nil;
}

- (void)outlineView:(NSOutlineView *)outlineView sortDescriptorsDidChange:(NSArray *)oldDescriptors
{
	[self sortFiles];
}

- (void)outlineViewItemWillExpand:(NSNotification *)notification
{
	FileSystemItem *fileItem = [[[notification userInfo] allValues] objectAtIndex:0];
	[self refreshFilesForFileItemChildren:fileItem];
}

#pragma mark utility function for outlineView
- (FileSystemItem *)selectedItemInOutlineView
{
	return [[self outlineView] itemAtRow:[[self outlineView] selectedRow]];
}

- (NSMutableArray *)sortChildrenForParent:(FileSystemItem *)parent
{
    //	NSLog(@"sorting for parent %@", [parent fullPath]);
	NSMutableArray *children = [parent children];
	if ([children count])
	{
		NSArray *sortDescriptors = [[self outlineView] sortDescriptors];
		if (![sortDescriptors count])
			sortDescriptors = [NSArray arrayWithObject:sSortDescriptor];
		[children sortUsingDescriptors:sortDescriptors];
		[parent setChildren:children];
		return children;
	}
	else
	{
		return nil;
	}
}

- (void)sortFiles
{
	NSMutableArray *fileItemNeedsChildrenSorting = [NSMutableArray arrayWithObject:[FileSystemItem rootItem]];
	
	while (1) 
	{
		//check to see if sorting is done
		if (![fileItemNeedsChildrenSorting count])
			break;
		//pop the first object
		FileSystemItem *fileItem = [fileItemNeedsChildrenSorting objectAtIndex:0];
		[fileItemNeedsChildrenSorting removeObjectAtIndex:0];
		
		NSMutableArray *newFileItems = [self sortChildrenForParent:fileItem];
		for (FileSystemItem *newFileItem in  newFileItems)
		{
			if ([[newFileItem children] count])
				[fileItemNeedsChildrenSorting addObject:newFileItem];
		}
	}
	[[self outlineView] reloadData];	
}

#pragma mark action methods

- (IBAction)rowDoubleClicked:(id)sender
{
	FileSystemItem *fileItem = [self selectedItemInOutlineView];
	
	//check if the file has been downloaded
	NSString *localStore = [fileItem localStore];
	//if yes, open with the default program
	if (localStore)
	{
		[[NSWorkspace sharedWorkspace] openFile:[fileItem localStore]];
	}
	else	//otherwise download the file and open after
	{
		[self downloadFileWithOptionToOpenFile:YES];
	}	
}

#pragma mark utility functions for building file structure
//delete all the descendent files from item down including item
- (void)deleteFilesFromItem:(FileSystemItem *)item
{
	NSMutableArray *fileItemQueue = [NSMutableArray arrayWithObject:item];
	while (1) 
	{
		if (![fileItemQueue count])
			break;
		//pop first object
		FileSystemItem *fileItem = [fileItemQueue objectAtIndex:0];
		[fileItemQueue removeObjectAtIndex:0];
		
		if ([fileItem children])
		{
			for (FileSystemItem *child in [fileItem children])
			{
				[child setParent:nil];
				[fileItemQueue addObject:child];
			}
		}
		[[[fileItem parent] children] removeObject:fileItem];
	}
}

#pragma mark retrieving data
//called back after metadata is loaded. Create corresponding FileSystemItems for all metadata'd children
- (void)metadataLoaded:(DBMetadata *)metadata
{
	FileSystemItem *parentDirectory = [self syncingFolder];
	NSMutableDictionary *oldChildrenDictionary = [NSMutableDictionary dictionary];
	NSArray *oldChildren = [NSArray arrayWithArray:[parentDirectory children]];
	
	//build up a dictionary for all old children
	for (FileSystemItem *child in oldChildren)
	{
		[oldChildrenDictionary setObject:child forKey:[child fullPath]];
	}
	
	NSMutableArray *newChildren = [NSMutableArray array];
	//check the new children and see if they exist in old children dictionary. Create new file node if needed	
	for (DBMetadata *child in [metadata contents])
	{
		//if the new child exists, set the corresponding dictionary entry to null
		id oldChild = [oldChildrenDictionary objectForKey:[child path]];
		if (oldChild && [oldChild isKindOfClass:[FileSystemItem class]] && ([oldChild isDirectory] == [child isDirectory]))
		{
			[oldChildrenDictionary setObject:[NSNull null] forKey:[child path]];
		}
		else	//add the new child to the directory
		{
			[[[FileSystemItem alloc] initWithPath:[child path] parent:parentDirectory fileSize:[child humanReadableSize] isDirectory:[child isDirectory]] autorelease];
            //	NSLog(@"filesystemitem allocated for path %@, parent directory is %@", [child path], parentDirectory);	
		}
	}
	
	[[parentDirectory children] addObjectsFromArray:newChildren];
	
	//sweep through oldChildrenDictionary to delete
	NSEnumerator *enumerator = [oldChildrenDictionary keyEnumerator];
	id key;
	
	while ((key = [enumerator nextObject])) 
	{
		//if item needs to be deleted
		id object = [oldChildrenDictionary objectForKey:key];
		if (object != [NSNull null])
		{
			[[parentDirectory children] removeObject:object];
		}
	}
}

#pragma mark FileBrowserWindowToolbarActionDelegate
- (void)uploadFile
{
	//if there's already an operation in flight, return
	if ([self isWorking] || [self isSyncingFileStructure])
		return;
	FileSystemItem *fileItem = [self selectedItemInOutlineView];
	
	//get destination path
	NSString *destPath;
	if ([fileItem isDirectory])
	{
		destPath = [fileItem fullPath];
	}
	else
	{
		destPath = [[fileItem parent] fullPath];
		fileItem = [fileItem parent];
	}
	
	//open file open dialogue
	NSOpenPanel* openDlg = [NSOpenPanel openPanel];
	[openDlg setCanChooseFiles:YES];
	[openDlg setCanChooseDirectories:NO];
	
	//display the dialog. Process files after OK is pressed
	if ( [openDlg runModal] == NSOKButton )
	{
		NSArray *fileURLs = [openDlg URLs];
		for (NSURL *fileURL in fileURLs)
		{
			[self setFolderToSyncAfterUpload:fileItem];
			NSString *srcPath = [fileURL path];
            [[self restClient] uploadFile:[fileURL lastPathComponent] toPath:destPath withParentRev:@"" fromPath:srcPath];
			
			[self setProgressUpdated:NO];
			NSDictionary *userInfo = [NSDictionary dictionaryWithObject:sAlertSheetMessageTextUploadingErrorString forKey:kAlertSheetTitleErrorStringKey];
			[self setErrorTrackingTimer:[NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(timerExpired:) userInfo:userInfo repeats:NO]];
            
			//update status
			[self setWorkingString:sProgressIndicatorStringForUploads];
			[self setIsWorking:YES];
			[self setIsSyncingFileStructure:NO];
			[self setWorkingProgress:0];
		}
	}
}

- (void)downloadFile
{
	[self downloadFileWithOptionToOpenFile:NO];
}

- (void)deleteFileOrDirectory
{
	//if there's already an operation in flight, return
	if ([self isWorking] || [self isSyncingFileStructure] || [self folderToSyncAfterDelete])
		return;
	
	FileSystemItem *fileItem = [self selectedItemInOutlineView];
	
	NSString *srcPath = [fileItem fullPath];
	
	//after server responds, sync parent folder
	if ([fileItem parent])
		[self setFolderToSyncAfterDelete:[fileItem parent]];
	else 
		[self setFolderToSyncAfterDelete:[FileSystemItem rootItem]];
    
	[[self restClient] deletePath:srcPath];
	
	[self setWorkingString:sProgressIndicatorStringForDeleting];
	[self setCanCancelProgress:NO];
	
	//delete the file locally for better performance. Sync from server later
	[self deleteFilesFromItem:fileItem];
}

- (void)logout
{
	if ([self isSyncingFileStructure] || [self isWorking])
		return;
    [[DBSession sharedSession] unlinkAll];
	[DBSession setSharedSession:nil];
}

- (BOOL)canLogout
{
	return (![self isSyncingFileStructure] && ![self isWorking]);
}

//refreshing file tree only for all children of file item
- (void)refreshFilesForFileItemChildren:(FileSystemItem *)fileItem
{
	//cancel the refresh file tree request if there's already another request in flight
	if (![self isWorking])
	{
		//remember the syncing folder
		[self setSyncingFolder:fileItem];
		
		//contact server to refresh
		[[self restClient] loadMetadata:[fileItem fullPath] withHash:nil];
		//update status
		[self setWorkingString:sProgressIndicatorStringForSyncing];
		[self setIsWorking:YES];
		[self setIsSyncingFileStructure:YES];
        [[NSNotificationCenter defaultCenter] postNotificationName:kFileBrowserStartSyncingNotification object:nil];
	}
}

//refresh file structure for item selected. If the selected item is a directory, refresh the directory content
//If the selected item is a file, refresh the file content. If there's nothing selected, refresh the root directory
- (void)refreshFileTree
{
	FileSystemItem *fileItem = [self selectedItemInOutlineView];
	if (!fileItem)
		fileItem = [FileSystemItem rootItem];
	[self refreshFilesForFileItemChildren:fileItem];
}

- (void)downloadFile:(FileSystemItem *)fileItem fromSrc:(NSString *)srcPath toDest:(NSString *)destPath withOptionToOpenFile:(BOOL)openFile
{
	assert(![self inflightDownload]);
	
	FileDownloadItem *inflightDownload = [[[FileDownloadItem alloc] initWithFileItem:fileItem srcPath:srcPath destPath:destPath openAfterDownload:openFile] autorelease];
	[self setInflightDownload:inflightDownload];
	
	//remember to open the file after download completes
	if (openFile)
		[sFilesToOpenAfterDownloading setObject:fileItem forKey:destPath];
	
	//remember where the file is stored locally
	[fileItem setLocalStore:destPath];
    
	NSDictionary *userInfo = [NSDictionary dictionaryWithObject:sAlertSheetMessageTextDownloadingErrorString forKey:kAlertSheetTitleErrorStringKey];
	[self setProgressUpdated:NO];
	[self setErrorTrackingTimer:[NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(timerExpired:) userInfo:userInfo repeats:NO]];
    
	[[self restClient] loadFile:srcPath intoPath:destPath];
    
	//update status
	[self setWorkingString:sProgressIndicatorStringForDownloads];
	[self setIsWorking:YES];
	[self setWorkingProgress:0];
	[self setCanCancelProgress:YES];
}

- (void)downloadFileWithOptionToOpenFile:(BOOL)openFile
{
	FileSystemItem *fileItem = [self selectedItemInOutlineView];
	
	//only take the action if it's a file, only download one file at a time
	if (![fileItem isDirectory])
	{
		NSString *srcPath = [fileItem fullPath];
		
		//default download location is in Donwloads/Dropbox/ folder
		NSString *destFolderPath = sDefaultDownloadStorageLocation;
		
		BOOL isDirectory = YES;
		BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:destFolderPath isDirectory:&isDirectory];
		//if this directory doesn't exist, create it
		if (!fileExists || !isDirectory)
		{
			NSError *error;
			[[NSFileManager defaultManager] createDirectoryAtPath:destFolderPath withIntermediateDirectories:YES attributes:nil error:&error];
		}
		
		NSString *destPath = [destFolderPath stringByAppendingString:[[fileItem fullPath] lastPathComponent]];
        
		//if there's syncing, delete or upload in flight, cancel the operation
		if ([self isSyncingFileStructure] || [self folderToSyncAfterDelete] || [self folderToSyncAfterUpload])
			return;
		FileDownloadItem *inflightDownload = [self inflightDownload];
		//if there's an inflight download or uoloading / downloading, add the job to the queue
		if (inflightDownload)
		{
			FileDownloadItem *nextDownload = [[[FileDownloadItem alloc] initWithFileItem:fileItem srcPath:srcPath destPath:destPath openAfterDownload:openFile] autorelease];
			[sFileDownloadQueue addObject:nextDownload];
		}
		else
		{
			[self downloadFile:fileItem fromSrc:srcPath toDest:destPath withOptionToOpenFile:openFile];
		}
	}
}

- (void)cancelAllFileDownloads
{
	//cancel all inflight downloads
	FileDownloadItem *inflightDownload = [self inflightDownload];
	if (inflightDownload)
	{
		[[self restClient] cancelFileLoad:[inflightDownload srcPath]];
		//clear the local store
		[[inflightDownload fileItem] setLocalStore:nil];
	}
	[self setInflightDownload:nil];
	
	//delete all objects in download queue
	[sFileDownloadQueue removeAllObjects];
	
	//update status
	[self setCanCancelProgress:NO];
	[self setIsWorking:NO];
	[self setWorkingProgress:0];
}

- (void)timerExpired:(NSDictionary *)userInfo
{
	if (![self progressUpdated])
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:kErrorDidOccurNotification object:nil userInfo:userInfo];
		[[self errorTrackingTimer] invalidate];
	}
	[self setProgressUpdated:NO];
}

#pragma mark DBRestClient methods
#pragma mark metadata loading
- (void)restClient:(DBRestClient*)client loadedMetadata:(DBMetadata*)metadata 
{
	//create cooresponding file structures
	[self metadataLoaded:metadata];
	
	[self setSyncingFolder:nil];
	//syncing is finished
    [[NSNotificationCenter defaultCenter] postNotificationName:kFileBrowserShouldUpdateAccountInfoNotification object:nil];
	[self sortFiles];
    
	//update status
	[self setIsWorking:NO];
	[self setIsSyncingFileStructure:NO];
	[[NSNotificationCenter defaultCenter] postNotificationName:kFileBrowserStopSyncingNotification object:nil];
}

- (void)restClient:(DBRestClient*)client loadMetadataFailedWithError:(NSError*)error 
{
	[self setSyncingFolder:nil];
	[self setIsWorking:NO];
	[self setIsSyncingFileStructure:NO];
	[[NSNotificationCenter defaultCenter] postNotificationName:kFileBrowserStopSyncingNotification object:nil];
	NSDictionary *userInfo = [NSDictionary dictionaryWithObject:sAlertSheetMessageTextSyncingErrorString forKey:kAlertSheetTitleErrorStringKey];
	[[NSNotificationCenter defaultCenter] postNotificationName:kErrorDidOccurNotification object:nil userInfo:userInfo];
}

#pragma mark file uploading
- (void)restClient:(DBRestClient*)client uploadedFile:(NSString*)destPath from:(NSString*)srcPath;
{
	[[self errorTrackingTimer] invalidate];
    
	[self setWorkingProgress:1.0];
	[self setIsWorking:NO];
	[self refreshFilesForFileItemChildren:[self folderToSyncAfterUpload]];
	[self setFolderToSyncAfterUpload:nil];
}

- (void)restClient:(DBRestClient*)client uploadProgress:(CGFloat)progress 
		   forFile:(NSString*)destPath from:(NSString*)srcPath
{
	//reset timer
	[self setProgressUpdated:YES];
	[self setWorkingProgress:(100 * progress)];	
}

- (void)restClient:(DBRestClient*)client uploadFileFailedWithError:(NSError*)error
{
	[self setWorkingProgress:0];
	[self setIsWorking:NO];
	[self setCanCancelProgress:NO];
	[self setProgressUpdated:NO];
	NSDictionary *userInfo = [NSDictionary dictionaryWithObject:sAlertSheetMessageTextUploadingErrorString forKey:kAlertSheetTitleErrorStringKey];
	[self timerExpired:userInfo];
	[self setFolderToSyncAfterUpload:nil];
}

#pragma mark file loading
- (void)restClient:(DBRestClient*)client loadedFile:(NSString*)destPath contentType:(NSString*)contentType
{
	[[self errorTrackingTimer] invalidate];
    
	//update status
	[self setCanCancelProgress:NO];
	[self setWorkingProgress:1.0];
	[self setIsWorking:NO];
	
	//open the file if necessary
	FileSystemItem *fileItem = [sFilesToOpenAfterDownloading objectForKey:destPath];
	if (fileItem)
	{
		[[NSWorkspace sharedWorkspace] openFile:[fileItem localStore]];
		[sFilesToOpenAfterDownloading removeObjectForKey:destPath];
	}
    
	//reset and start next download if necessary
	[self setInflightDownload:nil];
	if ([sFileDownloadQueue count])
	{
		FileDownloadItem *item = [sFileDownloadQueue objectAtIndex:0];
		
		[self downloadFile:[item fileItem] fromSrc:[item srcPath] toDest:[item destPath] withOptionToOpenFile:[item openAfterDownload]];
		[sFileDownloadQueue removeObjectAtIndex:0];
	}
}

- (void)restClient:(DBRestClient*)client loadProgress:(CGFloat)progress forFile:(NSString*)destPath
{
	//reset timer
	[self setProgressUpdated:YES];
	[self setWorkingProgress:(100 * progress)];
}

- (void)restClient:(DBRestClient*)client loadFileFailedWithError:(NSError*)error
{	
	//download error happened, clear all local stores
	if ([self inflightDownload])
	{
		[[[self inflightDownload] fileItem] setLocalStore:nil];
	}
	[self setInflightDownload:nil];
	[sFileDownloadQueue removeAllObjects];
	
	//update status
	[self setWorkingProgress:0];
	[self setIsWorking:NO];
	[self setCanCancelProgress:NO];
	
	[self setProgressUpdated:NO];
	NSDictionary *userInfo = [NSDictionary dictionaryWithObject:sAlertSheetMessageTextDownloadingErrorString forKey:kAlertSheetTitleErrorStringKey];
	[self timerExpired:userInfo];
}

#pragma mark path deleting
- (void)restClient:(DBRestClient*)client deletedPath:(NSString *)path
{
	[self refreshFilesForFileItemChildren:[self folderToSyncAfterDelete]];
	[self setFolderToSyncAfterDelete:nil];
}

- (void)restClient:(DBRestClient*)client deletePathFailedWithError:(NSError*)error
{
	[self setFolderToSyncAfterDelete:nil];
	NSDictionary *userInfo = [NSDictionary dictionaryWithObject:sAlertSheetMessageTextDeletingErrorString forKey:kAlertSheetTitleErrorStringKey];
	[[NSNotificationCenter defaultCenter] postNotificationName:kErrorDidOccurNotification object:nil userInfo:userInfo];
}

@end
