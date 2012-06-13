//
//  Extensions.h
//  appledoc
//
//  Created by Tomaž Kragelj on 3/17/12.
//  Copyright (c) 2012 Tomaz Kragelj. All rights reserved.
//

#import <ParseKit/ParseKit.h>

@interface NSError (Appledoc)
+ (NSError *)gb_errorWithCode:(NSInteger)code description:(NSString *)description reason:(NSString *)reason;
@end

enum {
	GBErrorCodeTemplatePathNotFound,
	GBErrorCodeTemplatePathNotDirectory,
};

#pragma mark - 

@interface NSFileManager (Appledoc)
- (BOOL)gb_fileExistsAndIsFileAtPath:(NSString *)path;
- (BOOL)gb_fileExistsAndIsDirectoryAtPath:(NSString *)path;
@end

#pragma mark - 

@interface NSString (Appledoc)
- (NSString *)gb_stringByStandardizingCurrentDir;
- (NSString *)gb_stringByStandardizingCurrentDirAndPath;
- (BOOL)gb_stringContainsOnlyCharactersFromSet:(NSCharacterSet *)set;
@end

#pragma mark - 

@interface NSArray (Appledoc)
- (BOOL)gb_containsObjectWithValue:(id)value forSelector:(SEL)selector;
- (NSUInteger)gb_indexOfObjectWithValue:(id)value forSelector:(SEL)selector;
@end

#pragma mark - 

@interface PKToken (Appledoc)
- (BOOL)matches:(id)expected;
- (NSUInteger)matchResult:(id)expected;
@property (nonatomic, assign) NSPoint location;
@end
