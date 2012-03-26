//
//  FileSystemItem.m
//  FileBrowser
//
//	File representation in FileBrowserAppp
//
//  Created by Tina Wen on 7/8/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "FileSystemItem.h"

@interface FileSystemItem ()

@property (readwrite, assign) Boolean isDirectory;
@property (readwrite, retain) NSString *fullPath;
@property (readwrite, retain) NSString *fileSize;

@end

@implementation FileSystemItem

@synthesize fullPath;
@synthesize parent;
@synthesize children;
@synthesize isDirectory;
@synthesize localStore;
@synthesize fileSize;

static FileSystemItem *rootItem = nil;

+ (void)initialize 
{
    if (self == [FileSystemItem class]) 
	{
		if (rootItem)
			[rootItem release];
		rootItem = [[FileSystemItem alloc] initWithPath:@"/" parent:nil fileSize:@"0" isDirectory:YES];
    }
}

- (id)initWithPath:(NSString *)path parent:(FileSystemItem *)parentItem fileSize:(NSString *)fSize isDirectory:(Boolean)isADirectory
{
    self = [super init];
    if (self) 
	{
		[self setFullPath:path];
		[self setIsDirectory:isADirectory];
		[self setLocalStore:nil];
		[self setFileSize:fSize];
		//update parent 
		[self setParent:parentItem];
		//initialize children
		[self setChildren:[NSMutableArray array]];
		//update parent's children
		[[[self parent] children] addObject:self];
	}
    return self;
}

+ (FileSystemItem *)rootItem {
    return rootItem;
}

- (void)dealloc {
	[children_ release];
	[fullPath_ release];
	[parent_ release];
	[localStore_ release];
	[fileSize_ release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
	FileSystemItem *newItem = [[FileSystemItem allocWithZone:zone] init];
	[newItem setChildren:[self children]];
	[newItem setFullPath:[self fullPath]];
	[newItem setParent:[self parent]];
	[newItem setIsDirectory:[self isDirectory]];
	[newItem setLocalStore:[self localStore]];
	[newItem setFileSize:[self fileSize]];
    
	return newItem;
}

@end
