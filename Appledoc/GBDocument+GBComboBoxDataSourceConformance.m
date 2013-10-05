#import "GBDocument+GBComboBoxDataSourceConformance.h"
#import "GBDocument+GBDeveloperNameFromAddressBook.h"

@interface GBDocumentDeveloperName: NSObject
+ (NSArray *) allDeveloperNames;
+ (instancetype) developerNameWithTitle:(NSString *)localizedTitle value:(NSString *)value;
- (NSString *) menuItemTitle;
@property(copy) NSString *menuItemTitleBasename;
@property(copy) NSString *value;
@end

@implementation GBDocument (GBComboBoxDataSourceConformance)

- (NSInteger) numberOfItemsInComboBox:(NSComboBox *)comboBox {
	return [GBDocumentDeveloperName allDeveloperNames].count;
}

- (id) comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)idx {
	NSArray *developerNames = [GBDocumentDeveloperName allDeveloperNames];
	GBDocumentDeveloperName *thisName = idx >= 0 ? developerNames[(NSUInteger)idx] : nil;
	return thisName.value;
}

- (NSString *) comboBox:(NSComboBox *)comboBox completedString:(NSString *)string {
	NSString *foldedQuery = string;
	NSString *foldedName;

	NSArray *developerNames = [GBDocumentDeveloperName allDeveloperNames];

	NSArray *values = [developerNames valueForKey:@"value"];
	for (NSString *name in values) {
		foldedName = [name stringByFoldingWithOptions:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch locale:[NSLocale currentLocale]];
		if ([foldedName hasPrefix:foldedQuery])
			return name;
	}

	NSArray *titles = [developerNames valueForKey:@"menuItemTitle"];
	for (NSString *name in titles) {
		foldedName = [name stringByFoldingWithOptions:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch locale:[NSLocale currentLocale]];
		if ([foldedName hasPrefix:foldedQuery])
			return name;
	}

	return nil;
}

- (NSUInteger) comboBox:(NSComboBox *)comboBox indexOfItemWithStringValue:(NSString *)string {
	NSUInteger idx;

	NSArray *developerNames = [GBDocumentDeveloperName allDeveloperNames];

	NSArray *values = [developerNames valueForKey:@"value"];
	idx = [values indexOfObjectPassingTest:^BOOL(id obj, NSUInteger objIdx, BOOL *stop) {
		return [string caseInsensitiveCompare:obj] == NSOrderedSame;
	}];
	if (idx == NSNotFound) {
		NSArray *titles = [developerNames valueForKey:@"menuItemTitle"];
		idx = [titles indexOfObjectPassingTest:^BOOL(id obj, NSUInteger objIdx, BOOL *stop) {
			return [string caseInsensitiveCompare:obj] == NSOrderedSame;
		}];
	}
	return idx;
}

@end

@implementation GBDocumentDeveloperName
+ (instancetype) developerNameWithTitle:(NSString *)localizedTitle value:(NSString *)value {
	GBDocumentDeveloperName *name = [[GBDocumentDeveloperName alloc] init];
	name.menuItemTitleBasename = localizedTitle;
	name.value = value;
	return name;
}

- (NSString *) menuItemTitle {
	return NSLocalizedString(@"Format string for developer name menu item titles", @"Format string for developer name menu item titles");
}

+ (NSArray *) allDeveloperNames {
	NSMutableArray *names = [NSMutableArray arrayWithCapacity:4];

	NSString *title, *value;

	title = NSLocalizedString(@"First, last name", @"Developer name menu item labels");
	value = [GBDocument firstLastNameFromAddressBook];
	[self generateDeveloperNameIntoArray:names menuItemTitle:title value:value];

	title = NSLocalizedString(@"First, middle, last name", @"Developer name menu item labels");
	value = [GBDocument firstMiddleLastNameFromAddressBook];
	[self generateDeveloperNameIntoArray:names menuItemTitle:title value:value];

	title = NSLocalizedString(@"Company name", @"Developer name menu item labels");
	value = [GBDocument companyNameFromAddressBook];
	[self generateDeveloperNameIntoArray:names menuItemTitle:title value:value];

	title = NSLocalizedString(@"Nickname", @"Developer name menu item labels");
	value = [GBDocument nicknameFromAddressBook];
	[self generateDeveloperNameIntoArray:names menuItemTitle:title value:value];

	return names;
}

+ (void) generateDeveloperNameIntoArray:(NSMutableArray *)names menuItemTitle:(NSString *)title value:(NSString *)value {
	if (value != nil) {
		[names addObject:[GBDocumentDeveloperName developerNameWithTitle:title value:value]];
	}
}
@end
