#import <Cocoa/Cocoa.h>

@interface GBDocument : NSDocument

@property(nonatomic, copy) NSString *projectName;

@property(nonatomic, copy) NSString *companyName;
@property(nonatomic, copy) NSString *companyID;

@property(nonatomic, copy) NSURL *projectSourceRootURL;

- (IBAction) generateDocumentationSet:(id)sender;

@end
