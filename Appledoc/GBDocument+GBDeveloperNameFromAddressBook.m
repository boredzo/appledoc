#import <AddressBook/AddressBook.h>
#import "GBDocument.h"
#import "GBDocument+GBDeveloperNameFromAddressBook.h"

@implementation GBDocument (GBDeveloperNameFromAddressBook)

+ (NSString *) companyNameFromAddressBook {
	ABAddressBook *addressBook = [ABAddressBook addressBook];
	ABPerson *me = [addressBook me];
	NSString *companyName = [me valueForProperty:kABOrganizationProperty];
	return companyName;
}

+ (NSString *) nicknameFromAddressBook {
	ABAddressBook *addressBook = [ABAddressBook addressBook];
	ABPerson *me = [addressBook me];
	NSString *nickname = [me valueForProperty:kABNicknameProperty];
	return nickname;
}

+ (NSString *) firstLastNameFromAddressBook {
	ABAddressBook *addressBook = [ABAddressBook addressBook];
	ABPerson *me = [addressBook me];
	NSString *firstName = [me valueForProperty:kABFirstNameProperty];
	NSString *lastName = [me valueForProperty:kABLastNameProperty];
	return ((firstName != nil) && (lastName != nil))
		? [@[ firstName, lastName ] componentsJoinedByString:@" "]
		: nil;
}

+ (NSString *) firstMiddleLastNameFromAddressBook {
	ABAddressBook *addressBook = [ABAddressBook addressBook];
	ABPerson *me = [addressBook me];
	NSString *firstName = [me valueForProperty:kABFirstNameProperty];
	NSString *middleName = [me valueForProperty:kABMiddleNameProperty];
	NSString *lastName = [me valueForProperty:kABLastNameProperty];
	return ((firstName != nil) && (middleName != nil) && (lastName != nil))
		? [@[ firstName, middleName, lastName ] componentsJoinedByString:@" "]
		: nil;
}

@end