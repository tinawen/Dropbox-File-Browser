//
//  FileBrowserDataSource.h
//  FileBrowser
//
//	The data source and delegate of the file browser outline view
//	It's also a delegate of DBRestClient. It does all the heavy lifting to update data
//	FileDownloadItems are objects in file download queue
//
//  Created by Tina Wen on 7/8/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class FileSystemItem;
@interface FileDownloadItem : NSObject
{
	FileSystemItem *fileItem_;
	NSString *srcPath_;
	NSString *destPath_;
	BOOL openAfterDownload_;
}

@property (readonly, retain) FileSystemItem *fileItem;
@property (readonly, retain) NSString *srcPath;
@property (readonly, retain) NSString *destPath;
@property (readonly, assign) BOOL openAfterDownload;

- (id)initWithFileItem:(FileSystemItem *)item srcPath:(NSString *)sourcePath destPath:(NSString *)destinationPath openAfterDownload:(BOOL)open;

@end

@class DBRestClient;
@class DBMetadata;

@interface FileBrowserDataSource : NSObject <NSTableViewDelegate, NSTableViewDataSource> 
{
	IBOutlet NSOutlineView *outlineView_;
	
	//status
	BOOL isWorking_;
	CGFloat workingProgress_;
	NSString *workingString_;
	BOOL canCancelProgress_;
	BOOL isSyncingFileStructure_;
	
@private
	DBRestClient *restClient;
	FileDownloadItem *inflightDownload_;
	NSUInteger metadataRequestInflight_;
	NSTimer *errorTrackingTimer_;
	BOOL progressUpdated_;
	FileSystemItem *folderToSyncAfterUpload_;
	FileSystemItem *folderToSyncAfterDelete_;
	//the folder that's currently being synced
	FileSystemItem *syncingFolder_;
}

@property (readonly, assign) NSOutlineView *outlineView;
@property (readonly, assign) BOOL isWorking;
@property (readonly, assign) CGFloat workingProgress;
@property (readonly, retain) NSString *workingString;
@property (readonly, assign) BOOL canCancelProgress;
@property (readonly, retain) FileDownloadItem *inflightDownload;
@property (readonly, assign) BOOL isSyncingFileStructure;

/*!
 @brief	Recursively call dropbox to build a file system structure locally for the outline view to display
 */
- (void)metadataLoaded:(DBMetadata *)metadata;

/*!
 @brief	Open the file in the selected row. If the file hasn't been downloaded, download the file first
 */
- (IBAction)rowDoubleClicked:(id)sender;

/*!
 @brief	Download the file. If openFile is YES, open the file after downloading it
 */
- (void)downloadFileWithOptionToOpenFile:(BOOL)openFile;

/*!
 @brief	Cancel all the file downloads
 */
- (void)cancelAllFileDownloads;

/*!
 @brief	Upload selected files to Dropbox
 */
- (void)uploadFile;

/*!
 @brief	Download selected files from Dropbox
 */
- (void)downloadFile;

/*!
 @brief	Call Dropbox to rebuild file structures and redisplay in outline view
 */
- (void)refreshFileTree;

/*!
 @brief	Delete selected files from Dropbox
 */
- (void)deleteFileOrDirectory;

/*!
 @brief	Logout of the user account. Return whether logout is successful. 
 Can only logout if there's no operation performed with Dropbox
 */
- (void)logout;

/*!
 @brief	Returns a BOOL indicating whether can logout of user account
 */
- (BOOL)canLogout;

@end
