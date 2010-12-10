//
//  GBDocSetOutputGenerator.m
//  appledoc
//
//  Created by Tomaz Kragelj on 29.11.10.
//  Copyright 2010 Gentle Bytes. All rights reserved.
//

#import "GRMustache.h"
#import "GBApplicationSettingsProvider.h"
#import "GBTask.h"
#import "GBDataObjects.h"
#import "GBTemplateHandler.h"
#import "GBDocSetOutputGenerator.h"

@interface GBDocSetOutputGenerator ()

- (BOOL)moveSourceFilesToDocuments:(NSError **)error;
- (BOOL)processInfoPlist:(NSError **)error;
- (BOOL)processNodesXml:(NSError **)error;
- (BOOL)processTokensXml:(NSError **)error;
- (BOOL)indexDocSet:(NSError **)error;
- (BOOL)removeTemporaryFiles:(NSError **)error;
- (BOOL)installDocSet:(NSError **)error;
- (BOOL)processTokensXmlForObjects:(NSArray *)objects type:(NSString *)type template:(NSString *)template index:(NSUInteger *)index error:(NSError **)error;
- (void)addTokensXmlModelObjectDataForObject:(GBModelBase *)object toData:(NSMutableDictionary *)data;
- (void)initializeSimplifiedObjects;
- (NSArray *)simplifiedObjectsFromObjects:(NSArray *)objects value:(NSString *)value index:(NSUInteger *)index;
- (NSString *)tokenIdentifierForObject:(GBModelBase *)object;
@property (retain) NSArray *classes;
@property (retain) NSArray *categories;
@property (retain) NSArray *protocols;
@property (readonly) NSMutableSet *temporaryFiles;

@end

#pragma mark -

@implementation GBDocSetOutputGenerator

#pragma Generation handling

- (BOOL)generateOutputWithStore:(id<GBStoreProviding>)store error:(NSError **)error {
	NSParameterAssert(self.previousGenerator != nil);
	
	// Prepare for run.
	if (![super generateOutputWithStore:store error:error]) return NO;
	[self.temporaryFiles removeAllObjects];
	[self initializeSimplifiedObjects];
	
	// Create documentation set from files generated by previous generator.
	if (![self moveSourceFilesToDocuments:error]) return NO;
	if (![self processInfoPlist:error]) return NO;
	if (![self processNodesXml:error]) return NO;
	if (![self processTokensXml:error]) return NO;
	if (![self indexDocSet:error]) return NO;
	
	// Install documentation set to Xcode.
	if (!self.settings.installDocSet) return YES;
	if (![self removeTemporaryFiles:error]) return NO;
	if (![self installDocSet:error]) return NO;
	return YES;
}

- (BOOL)moveSourceFilesToDocuments:(NSError **)error {
	GBLogInfo(@"Moving HTML files to DocSet bundle...");
	
	// Prepare all paths. Note that we determine the exact subdirectory by searching for documents-template and using it's subdirectory as the guide. If documents template wasn't found, exit.
	NSString *sourceFilesPath = [self.previousGenerator.outputUserPath stringByStandardizingPath];
	NSString *documentsPath = [self templateFileKeyEndingWith:@"documents-template"];
	if (!documentsPath) {
		if (error) *error = [NSError errorWithCode:GBErrorDocSetDocumentTemplateMissing description:@"Documents template is missing!" reason:@"documents-template file is required to determine location for Documents path in DocSet bundle!"];
		GBLogWarn(@"Failed finding documents-template in '%@'!", self.templateUserPath);
		return NO;
	}
	
	// First step is to move all files generated by previous generator as the Documents subfolder of docset structure.
	documentsPath = [documentsPath stringByDeletingLastPathComponent];
	NSString *destPath = [self.outputUserPath stringByAppendingPathComponent:documentsPath];
	NSString *movePath = [destPath stringByAppendingPathComponent:@"Documents"];
	if (![self.fileManager moveItemAtPath:sourceFilesPath toPath:[movePath stringByStandardizingPath] error:error]) {
		GBLogWarn(@"Failed moving files from '%@' to '%@'!", self.previousGenerator.outputUserPath, movePath);
		return NO;
	}
	return YES;
}

- (BOOL)processInfoPlist:(NSError **)error {
	GBLogInfo(@"Writting DocSet Info.plist...");
	NSString *templatePath = [self templateFileKeyEndingWith:@"info-template.plist"];
	if (!templatePath) {
		if (error) *error = [NSError errorWithCode:GBErrorDocSetInfoPlistTemplateMissing description:@"Info.plist template is missing!" reason:@"info-template.plist file is required to specify information about DocSet!"];
		GBLogWarn(@"Failed finding info-template.plist in '%@'!", self.templateUserPath);
		return NO;
	}
	
	// Prepare template variables and replace all placeholders with actual values.
	NSMutableDictionary *vars = [NSMutableDictionary dictionaryWithCapacity:20];
	[vars setObject:self.settings.docsetBundleIdentifier forKey:@"bundleIdentifier"];
	[vars setObject:self.settings.docsetBundleName forKey:@"bundleName"];
	[vars setObject:self.settings.projectVersion forKey:@"bundleVersion"];
	[vars setObject:self.settings.docsetCertificateIssuer forKey:@"certificateIssuer"];
	[vars setObject:self.settings.docsetCertificateSigner forKey:@"certificateSigner"];
	[vars setObject:self.settings.docsetDescription forKey:@"description"];
	[vars setObject:self.settings.docsetFallbackURL forKey:@"fallbackURL"];
	[vars setObject:self.settings.docsetFeedName forKey:@"feedName"];
	[vars setObject:self.settings.docsetFeedURL forKey:@"feedURL"];
	[vars setObject:self.settings.docsetMinimumXcodeVersion forKey:@"minimumXcodeVersion"];
	[vars setObject:self.settings.docsetPlatformFamily forKey:@"platformFamily"];
	[vars setObject:self.settings.docsetPublisherIdentifier forKey:@"publisherIdentifier"];
	[vars setObject:self.settings.docsetPublisherName forKey:@"publisherName"];
	[vars setObject:self.settings.docsetCopyrightMessage forKey:@"copyrightMessage"];
	
	// Run the template and save the results as Info.plist.
	GBTemplateHandler *handler = [self.templateFiles objectForKey:templatePath];
	NSString *output = [handler renderObject:vars];
	NSString *path = [[templatePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Info.plist"];
	NSString *filename = [self.outputUserPath stringByAppendingPathComponent:path];
	if (![self writeString:output toFile:[filename stringByStandardizingPath] error:error]) {
		GBLogWarn(@"Failed writting Info.plist to '%@'!", filename);
		return NO;
	}
	return YES;
}

- (BOOL)processNodesXml:(NSError **)error {
	GBLogInfo(@"Writting DocSet Nodex.xml file...");
	NSString *templatePath = [self templateFileKeyEndingWith:@"nodes-template.xml"];
	if (!templatePath) {
		if (error) *error = [NSError errorWithCode:GBErrorDocSetNodesTemplateMissing description:@"Nodes.xml template is missing!" reason:@"nodes-template.xml file is required to specify document structure for DocSet!"];
		GBLogWarn(@"Failed finding nodes-template.xml in '%@'!", self.templateUserPath);
		return NO;
	}
	
	// Prepare the variables for the template.
	NSMutableDictionary *vars = [NSMutableDictionary dictionary];
	[vars setObject:self.settings.projectName forKey:@"projectName"];
	[vars setObject:@"index.html" forKey:@"indexFilename"];
	[vars setObject:([self.classes count] > 0) ? [GRYes yes] : [GRNo no] forKey:@"hasClasses"];
	[vars setObject:([self.categories count] > 0) ? [GRYes yes] : [GRNo no] forKey:@"hasCategories"];
	[vars setObject:([self.protocols count] > 0) ? [GRYes yes] : [GRNo no] forKey:@"hasProtocols"];
	[vars setObject:self.classes forKey:@"classes"];
	[vars setObject:self.categories forKey:@"categories"];
	[vars setObject:self.protocols forKey:@"protocols"];
	[vars setObject:self.settings.stringTemplates forKey:@"strings"];
	
	// Run the template and save the results.
	GBTemplateHandler *handler = [self.templateFiles objectForKey:templatePath];
	NSString *output = [handler renderObject:vars];
	NSString *path = [[templatePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Nodes.xml"];
	NSString *filename = [self.outputUserPath stringByAppendingPathComponent:path];
	[self.temporaryFiles addObject:filename];
	if (![self writeString:output toFile:[filename stringByStandardizingPath] error:error]) {
		GBLogWarn(@"Failed writting Nodes.xml to '%@'!", filename);
		return NO;
	}
	return YES;
}

- (BOOL)processTokensXml:(NSError **)error {
	GBLogInfo(@"Writting DocSet Tokens.xml files...");
	
	// Get the template and prepare single Tokens.xml file for each object.
	NSString *templatePath = [self templateFileKeyEndingWith:@"tokens-template.xml"];
	if (!templatePath) {
		GBLogWarn(@"Didn't find tokens-template.xml in '%@', DocSet will not be indexed!", self.templateUserPath);
		return YES;
	}

	// Write each object as a separate token file.
	NSUInteger index = 1;
	if (![self processTokensXmlForObjects:self.classes type:@"cl" template:templatePath index:&index error:error]) return NO;
	if (![self processTokensXmlForObjects:self.categories type:@"cat" template:templatePath index:&index error:error]) return NO;
	if (![self processTokensXmlForObjects:self.protocols type:@"intf" template:templatePath index:&index error:error]) return NO;
	return YES;
}

- (BOOL)indexDocSet:(NSError **)error {
	GBLogInfo(@"Indexing DocSet...");
	GBTask *task = [GBTask task];
	task.reportIndividualLines = YES;
	NSArray *args = [NSArray arrayWithObjects:@"index", [self.outputUserPath stringByStandardizingPath], nil];
	BOOL result = [task runCommand:@"/Developer/usr/bin/docsetutil" arguments:args block:^(NSString *output, NSString *error) {
		if (output) GBLogDebug(@"> %@", [output stringByTrimmingWhitespaceAndNewLine]);
		if (error) GBLogError(@"!> %@", [error stringByTrimmingWhitespaceAndNewLine]);
	}];
	if (!result) {
		if (error) *error = [NSError errorWithCode:GBErrorDocSetUtilIndexingFailed description:@"docsetutil failed to index the documentation set!" reason:task.lastStandardError];
		return NO;
	}
	return YES;
}

- (BOOL)removeTemporaryFiles:(NSError **)error {
	// We delete all registered temporary files and clear the list. If there are some problems, we simply log but always return YES - if these files remain, documentation set is still usable, so it's no point of aborting...
	GBLogInfo(@"Removing temporary DocSet files...");
	NSError *err = nil;
	for (NSString *filename in self.temporaryFiles) {
		GBLogDebug(@"Removing '%@'...", filename);
		if (![self.fileManager removeItemAtPath:[filename stringByStandardizingPath] error:&err]) {
			GBLogNSError(err, @"Failed removing temporary file '%@'!", filename);
		}
	}
	return YES;
}

- (BOOL)installDocSet:(NSError **)error {
	GBLogInfo(@"Installing DocSet...");
	
	// Prepare destination directory path and documentation set name.
	NSString *destDir = self.settings.docsetInstallPath;
	NSString *destSubDir = [self.settings.docsetBundleIdentifier stringByAppendingPathExtension:@"docset"];

	// Prepare source and destination paths and file names.
	NSString *sourceUserPath = self.outputUserPath;
	NSString *destUserPath = [destDir stringByAppendingPathComponent:destSubDir];
	NSString *sourcePath = [sourceUserPath stringByStandardizingPath];
	NSString *destPath = [destUserPath stringByStandardizingPath];
	
	// Create destination directory and move files to it. If the destination directory alredy exists, remove it. Then create installation directory to make sure it's there the first time. Then move the docset files to the correct subdirectory.
	GBLogVerbose(@"Moving DocSet files from '%@' to '%@'...", sourceUserPath, destUserPath);
	if ([self.fileManager fileExistsAtPath:destPath]) {
		GBLogDebug(@"Removing previous DocSet installation directory '%@'...", destUserPath);
		if (![self.fileManager removeItemAtPath:destPath error:error]) {
			GBLogWarn(@"Failed removing previous DocSet installation directory '%@'!", destUserPath);
			return NO;
		}
	}
	if (![self.fileManager createDirectoryAtPath:[destDir stringByStandardizingPath] withIntermediateDirectories:YES attributes:nil error:error]) {
		GBLogWarn(@"Failed creating DocSet installation parent directory '%@'!", destDir);
		return NO;
	}
	if (![self.fileManager moveItemAtPath:sourcePath toPath:destPath error:error]) {
		GBLogWarn(@"Failed moving DocSet files from '%@' to '%@'!", sourceUserPath, destUserPath);
		return  NO;
	}
	
	// Prepare AppleScript for loading the documentation into the Xcode.
	GBLogVerbose(@"Installing DocSet to Xcode...");
	NSMutableString* installScript  = [NSMutableString string];
	[installScript appendString:@"tell application \"Xcode\"\n"];
	[installScript appendFormat:@"\tload documentation set with path \"%@\"\n", destPath];
	[installScript appendString:@"end tell"];
	
	// Run the AppleScript for loading the documentation into the Xcode.
	NSDictionary* errorDict = nil;
	NSAppleScript* script = [[NSAppleScript alloc] initWithSource:installScript];
	if (![script executeAndReturnError:&errorDict])
	{
		NSString *message = [errorDict objectForKey:NSAppleScriptErrorMessage];
		if (error) *error = [NSError errorWithCode:GBErrorDocSetXcodeReloadFailed description:@"Documentation set was installed, but couldn't reload documentation within Xcode." reason:message];
		return NO;
	}
	return YES;
}

#pragma mark Helper methods

- (BOOL)processTokensXmlForObjects:(NSArray *)objects type:(NSString *)type template:(NSString *)template index:(NSUInteger *)index error:(NSError **)error {
	// Prepare the output path and template handler then generate file for each object.
	GBTemplateHandler *handler = [self.templateFiles objectForKey:template];
	NSString *outputPath = [template stringByDeletingLastPathComponent];
	NSUInteger idx = *index;
	for (NSMutableDictionary *simplifiedObjectData in objects) {
		// Get the object's methods provider and prepare the array of all methods.
		GBModelBase *topLevelObject = [simplifiedObjectData objectForKey:@"object"];
		GBMethodsProvider *methodsProvider = [topLevelObject valueForKey:@"methods"];
		
		// Prepare template variables for object. Note that we reuse the ID assigned while creating the data for Nodes.xml.
		NSMutableDictionary *objectData = [NSMutableDictionary dictionaryWithCapacity:2];
		[objectData setObject:[simplifiedObjectData objectForKey:@"id"] forKey:@"refid"];
		[self addTokensXmlModelObjectDataForObject:topLevelObject toData:objectData];
		
		// Prepare the list of all members.
		NSMutableArray *membersData = [NSMutableArray arrayWithCapacity:[methodsProvider.methods count]];
		for (GBMethodData *method in methodsProvider.methods) {
			NSMutableDictionary *data = [NSMutableDictionary dictionaryWithCapacity:4];
			[data setObject:[self.settings htmlReferenceNameForObject:method] forKey:@"anchor"];
			[self addTokensXmlModelObjectDataForObject:method toData:data];
			[membersData addObject:data];
		}
		
		// Prepare the variables for the template.
		NSMutableDictionary *vars = [NSMutableDictionary dictionary];
		[vars setObject:[simplifiedObjectData objectForKey:@"path"] forKey:@"filePath"];
		[vars setObject:objectData forKey:@"object"];
		[vars setObject:membersData forKey:@"members"];
		
		// Run the template and save the results.
		NSString *output = [handler renderObject:vars];
		NSString *indexName = [NSString stringWithFormat:@"Tokens%ld.xml", idx++];
		NSString *subpath = [outputPath stringByAppendingPathComponent:indexName];
		NSString *filename = [self.outputUserPath stringByAppendingPathComponent:subpath];
		[self.temporaryFiles addObject:filename];
		if (![self writeString:output toFile:[filename stringByStandardizingPath] error:error]) {
			GBLogWarn(@"Failed writting tokens file '%@'!", filename);
			*index = idx;
			return NO;
		}
	}
	*index = idx;
	return YES;
}

- (void)addTokensXmlModelObjectDataForObject:(GBModelBase *)object toData:(NSMutableDictionary *)data {
	[data setObject:[self tokenIdentifierForObject:object] forKey:@"identifier"];
	[data setObject:[[object.sourceInfosSortedByName objectAtIndex:0] filename] forKey:@"declaredin"];
	if (object.comment) {
		if (object.comment.hasParagraphs) [data setObject:object.comment.firstParagraph forKey:@"abstract"];
		if ([object.comment.crossrefs count] > 0) {
			NSMutableArray *related = [NSMutableArray arrayWithCapacity:[object.comment.crossrefs count]];
			for (GBParagraphLinkItem *crossref in object.comment.crossrefs) {
				if (crossref.member)
					[related addObject:[self tokenIdentifierForObject:crossref.member]];
				else if (crossref.context)
					[related addObject:[self tokenIdentifierForObject:crossref.context]];
			}
			if ([related count] > 0) {
				[data setObject:[GRYes yes] forKey:@"hasRelatedTokens"];
				[data setObject:related forKey:@"relatedTokens"];
			}
		}
	}
}

- (NSString *)tokenIdentifierForObject:(GBModelBase *)object {
	if (object.isTopLevelObject) {
		// Class, category and protocol have different prefix, but are straighforward. Note that category has it's class name specified for object name!
		if ([object isKindOfClass:[GBClassData class]]) {
			NSString *objectName = [(GBClassData *)object nameOfClass];
			return [NSString stringWithFormat:@"//apple_ref/occ/cl/%@", objectName];
		} else if ([object isKindOfClass:[GBCategoryData class]]) {
			NSString *objectName = [(GBCategoryData *)object nameOfClass];
			return [NSString stringWithFormat:@"//apple_ref/occ/cat/%@", objectName];
		} else {
			NSString *objectName = [(GBProtocolData *)object nameOfProtocol];
			return [NSString stringWithFormat:@"//apple_ref/occ/intf/%@", objectName];
		}
	} else {
		// Members are slighly more complex - their identifier is different regarding to whether they are part of class or category/protocol. Then it depends on whether they are method or property. Finally their parent object (class/category/protocol) name (again class name for category) and selector should be added.
		if (!object.parentObject) [NSException raise:@"Can't create token identifier for %@; object is not top level and has no parent assigned!", object];
		
		// First handle parent related stuff.
		GBModelBase *parent = object.parentObject;
		NSString *objectName = nil;
		NSString *objectID = nil;
		if ([parent isKindOfClass:[GBClassData class]]) {
			objectName = [(GBClassData *)parent nameOfClass];
			objectID = @"inst";
		} else if ([parent isKindOfClass:[GBCategoryData class]]) {
			objectName = [(GBCategoryData *)parent nameOfClass];
			objectID = @"intf";
		} else {
			objectName = [(GBProtocolData *)parent nameOfProtocol];
			objectID = @"intf";
		}
		
		// Prepare the actual identifier based on method type.
		GBMethodData *method = (GBMethodData *)object;
		if (method.methodType == GBMethodTypeProperty)
			return [NSString stringWithFormat:@"//apple_ref/occ/%@p/%@/%@", objectID, objectName, method.methodSelector];
		else
			return [NSString stringWithFormat:@"//apple_ref/occ/%@m/%@/%@", objectID, objectName, method.methodSelector];
	}
	return nil;
}

- (void)initializeSimplifiedObjects {
	// Prepare flat list of objects for library nodes.
	GBLogDebug(@"Initializing simplified object representations...");
	NSUInteger index = 1;
	self.classes = [self simplifiedObjectsFromObjects:[self.store classesSortedByName] value:@"nameOfClass" index:&index];
	self.categories = [self simplifiedObjectsFromObjects:[self.store categoriesSortedByName] value:@"idOfCategory" index:&index];
	self.protocols = [self simplifiedObjectsFromObjects:[self.store protocolsSortedByName] value:@"nameOfProtocol" index:&index];
}

- (NSArray *)simplifiedObjectsFromObjects:(NSArray *)objects value:(NSString *)value index:(NSUInteger *)index {
	NSUInteger idx = *index;
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:[objects count]];
	for (id object in objects) {
		GBLogDebug(@"Initializing simplified representation of %@ with id %ld...", object, idx);
		NSMutableDictionary *data = [NSMutableDictionary dictionaryWithCapacity:4];
		[data setObject:object forKey:@"object"];
		[data setObject:[NSString stringWithFormat:@"%ld", idx++] forKey:@"id"];
		[data setObject:[object valueForKey:value] forKey:@"name"];
		[data setObject:[self.settings htmlReferenceForObjectFromIndex:object] forKey:@"path"];
		[result addObject:data];
	}
	*index = idx;
	return result;
}

- (NSMutableSet *)temporaryFiles {
	static NSMutableSet *result = nil;
	if (!result) result = [[NSMutableSet alloc] init];
	return result;
}

#pragma mark Overriden methods

- (NSString *)outputSubpath {
	return @"docset";
}

#pragma mark Properties

@synthesize classes;
@synthesize categories;
@synthesize protocols;

@end
