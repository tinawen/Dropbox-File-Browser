//
//  FileSystemItem.h
//  FileBrowser
//
//	File representation in FileBrowserAppp
//
//  Created by Tina Wen on 7/8/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface FileSystemItem : NSObject 
{
@private	
	NSString *fullPath_;
    FileSystemItem *parent_;
    NSMutableArray *children_;
	Boolean isDirectory_;
	NSString *fileSize_;
	//indicating where the corresponding file is stored locally
	NSString *localStore_;
}

@property (readonly, assign) Boolean isDirectory;
@property (readonly, retain) NSString *fullPath;
@property (readonly, retain) NSString *fileSize;
@property (readwrite, retain) FileSystemItem *parent;
@property (readwrite, retain) NSMutableArray *children;
@property (readwrite, retain) NSString *localStore;

/*!
 @brief	Intialization function
 */
- (id)initWithPath:(NSString *)path parent:(FileSystemItem *)parentItem fileSize:(NSString *)fileSize isDirectory:(Boolean)isDirectory;

/*!
 @brief	return the rootItem fo the file system
 */
+ (FileSystemItem *)rootItem;

@end
