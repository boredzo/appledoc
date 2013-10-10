#import <objc/runtime.h>
#import "GBDocument.h"

static NSString *const GBDocumentProjectNameKey = @"--project-name";
static NSString *const GBDocumentCompanyNameKey = @"--project-company";
static NSString *const GBDocumentCompanyIDKey = @"--company-id";

static NSString *const GBAppledocErrorDomain = @"GBAppledocErrorDomain";

@implementation GBDocument
{
	NSPropertyListFormat _format;
}

- (id) init {
	self = [super init];
	if (self) {
		_format = NSPropertyListXMLFormat_v1_0;
	}
	return self;
}

- (NSString *) windowNibName {
	return @"GBDocument";
}

+ (BOOL) autosavesInPlace {
	return YES;
}

- (BOOL) readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
	NSDictionary *dict = [NSPropertyListSerialization propertyListWithData:data
		options:0
		format:&_format
		error:outError];

	if (dict == nil || ! [dict isKindOfClass:[NSDictionary class]]) {
		if (outError != nil)
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError userInfo:nil];
		return NO;
	}

	NSUndoManager *undoManager = [self undoManager];
	[undoManager disableUndoRegistration];

	[self conditionallySetValueFromDictionary:dict forDictionaryKey:GBDocumentProjectNameKey expectedValueClass:[NSString class]
		forPropertyKey:@"projectName"];
	[self conditionallySetValueFromDictionary:dict forDictionaryKey:GBDocumentCompanyNameKey expectedValueClass:[NSString class]
		forPropertyKey:@"companyName"];
	[self conditionallySetValueFromDictionary:dict forDictionaryKey:GBDocumentCompanyIDKey expectedValueClass:[NSString class]
		forPropertyKey:@"companyID"];

	[undoManager enableUndoRegistration];

	return YES;
}

- (bool) conditionallySetValueFromDictionary:(NSDictionary *)dict
	forDictionaryKey:(NSString *)dictKey
	expectedValueClass:(Class)valueClass
	forPropertyKey:(NSString *)propertyKey
{
	NSParameterAssert(propertyKey != nil);
	bool usableValue = true;

	id value = dict[dictKey];
	if (value != nil) {
		if ( ! [value isKindOfClass:valueClass] ) {
			usableValue = false;
		}
	}

	usableValue = usableValue && (value != nil);
	if (usableValue) {
		[self setValue:value forKey:propertyKey];
	}

	return usableValue;
}

- (NSData *) dataOfType:(NSString *)typeName error:(NSError **)outError {
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:4];

	if (self.projectName != nil) {
		dict[GBDocumentProjectNameKey] = self.projectName;
	}
	if (self.companyName != nil) {
		dict[GBDocumentCompanyNameKey] = self.companyName;
	}
	if (self.companyID != nil) {
		dict[GBDocumentCompanyIDKey] = self.companyID;
	}

	return [NSPropertyListSerialization dataWithPropertyList:dict
		format:_format
		options:0
		error:outError];
}

#pragma mark -

+ (NSArray *) restorableStateKeyPaths {
	return @[ @"projectName", @"companyName", @"companyID" ];
}

#pragma mark -

- (BOOL) presentError:(NSError *)error {
	[self presentError:error
		modalForWindow:self.windowForSheet
		delegate:self
		didPresentSelector:@selector(didPresentErrorWithRecovery:contextInfo:)
		contextInfo:NULL];
	return NO;
}
- (void) didPresentErrorWithRecovery:(BOOL)didRecover
	contextInfo:(void *)contextInfo
{
	//This method intentionally left blank.
}

#pragma mark -

- (BOOL) validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)item {
	if (sel_isEqual(item.action, @selector(generateDocumentationSet:))) {
		return [self canGenerateDocumentationSet];
	}
	return YES;
}

+ (NSSet *) keyPathsForValuesAffectingCanGenerateDocumentationSet {
	return [NSSet setWithArray:@[ @"projectName", @"companyName", @"companyID" ]];
}

- (bool) canGenerateDocumentationSet {
	return \
		   (self.projectName != nil)
		&& (self.companyName != nil)
		&& (self.companyID != nil);
}

- (void) setProjectName:(NSString *)projectName {
	NSUndoManager *undoManager = [self undoManager];
	[[undoManager prepareWithInvocationTarget:self] setProjectName:self.projectName];
	_projectName = [projectName copy];
	[undoManager setActionName:NSLocalizedString(@"Change Company Name", @"Undo action names")];
}

- (void) setCompanyName:(NSString *)companyName {
	NSUndoManager *undoManager = [self undoManager];
	[[undoManager prepareWithInvocationTarget:self] setCompanyName:self.companyName];
	_companyName = [companyName copy];
	[undoManager setActionName:NSLocalizedString(@"Change Company Name", @"Undo action names")];
}

- (void) setCompanyID:(NSString *)companyID {
	NSUndoManager *undoManager = [self undoManager];
	[[undoManager prepareWithInvocationTarget:self] setCompanyID:self.companyID];
	_companyID = [companyID copy];
	[undoManager setActionName:NSLocalizedString(@"Change Company ID", @"Undo action names")];
}

- (IBAction) generateDocumentationSet:(id)sender {
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	savePanel.directoryURL = [self.fileURL URLByDeletingLastPathComponent];
	savePanel.nameFieldStringValue = [self.projectName stringByAppendingPathExtension:@"docset"];
	[savePanel beginSheetModalForWindow:self.windowForSheet
		completionHandler:^(NSInteger result) {
			if (result != NSFileHandlingPanelOKButton)
				return;

			[self generateDocumentationSetAtURL:savePanel.URL];
		}
	];
}

- (void) generateDocumentationSetAtURL:(NSURL *)URL {
	NSBundle *mainBundle = [NSBundle mainBundle];

	NSURL *appledocExecutableURL = [mainBundle URLForResource:@"appledoc" withExtension:@""];
	NSString *appledocExecutablePath = appledocExecutableURL.path;

	NSURL *templatesDirURL = [mainBundle URLForResource:@"Templates" withExtension:@""];

	NSFileManager *manager = [NSFileManager new];
	NSURL *tempDirURL = [manager URLForDirectory:NSCachesDirectory
		inDomain:NSUserDomainMask
		appropriateForURL:nil
		create:YES
		error:NULL];
	if (tempDirURL == nil) {
		NSString *tempDirPath = NSTemporaryDirectory();
		tempDirURL = [NSURL fileURLWithPath:tempDirPath isDirectory:YES];
	}
	if (tempDirURL != nil) {
		tempDirURL = [tempDirURL URLByAppendingPathComponent:mainBundle.bundleIdentifier isDirectory:YES];
		[manager createDirectoryAtURL:tempDirURL
			withIntermediateDirectories:YES
			attributes:nil
			error:NULL];
	}

	NSTask *task = [NSTask new];
	task.launchPath = appledocExecutablePath;
	task.arguments = @[
		@"--output", [tempDirURL path],
		@"--clean-output",
		@"--finalize-docset",
		@"--templates", [templatesDirURL path],
		@"--docset-install-path", [URL path],
		[[self.fileURL URLByDeletingLastPathComponent] path]
	];
	task.standardError = [NSPipe pipe];

	NSMutableArray *argsForLogging = [task.arguments mutableCopy];
	[task.arguments enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		argsForLogging[idx] = [NSString stringWithFormat:@"'%@'", obj];
	}];
	NSLog(@"Running %@ %@", task.launchPath, [argsForLogging componentsJoinedByString:@" "]);

	task.terminationHandler = ^(NSTask *exitedTask) {
		if (exitedTask.terminationStatus == EXIT_SUCCESS) {
			NSUserNotification *notification = [NSUserNotification new];
			notification.title = NSLocalizedString(@"Documentation generated", @"Generation completion notification");
			notification.subtitle = [NSString stringWithFormat:NSLocalizedString(@"Successfully generated %@ documentation", @"Generation completion notification"), self.projectName];

			NSUserNotificationCenter *notificationCenter = [NSUserNotificationCenter defaultUserNotificationCenter];
			[notificationCenter scheduleNotification:notification];
		} else {
			NSPipe *stderrPipe = exitedTask.standardError;
			NSData *stderrData = [[stderrPipe fileHandleForReading] readDataToEndOfFile];
			NSString *stderrStr = [[NSString alloc] initWithData:stderrData encoding:NSUTF8StringEncoding];
			NSDictionary *userInfo = (stderrStr != nil)
				? @{ NSLocalizedFailureReasonErrorKey: stderrStr }
				: nil;
			NSError *error = [NSError errorWithDomain:GBAppledocErrorDomain code:exitedTask.terminationStatus userInfo:userInfo];
			[self performSelectorOnMainThread:@selector(presentError:) withObject:error waitUntilDone:NO];
		}
	};

	[task launch];
}

@end
