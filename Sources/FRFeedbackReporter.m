#import "FRFeedbackReporter.h"
#import "FeedbackController.h"
#import "CrashLogFinder.h"

static NSString *KEY_LASTCRASCHECKDATE = @"FRFeedbackReporter.lastCrashDetectedDate";

@implementation FRFeedbackReporter

+ (void) reportAsUser:(NSString*)user
{
    FeedbackController *controller = [[FeedbackController alloc] initWithUser:user];

    [controller showWindow:self];
}

+ (void) reportCrashAsUser:(NSString*)user
{
    NSDate *lastCrashCheckDate = [[NSUserDefaults standardUserDefaults] valueForKey:KEY_LASTCRASCHECKDATE];
    NSArray *crashFiles = [CrashLogFinder findCrashLogsBefore:lastCrashCheckDate];
    
    if ([crashFiles count] > 0) {
        NSLog(@"found new crash files");

        NSString *comment = NSLocalizedString(@"The application crashed after I...", nil);

        FeedbackController *controller = [[FeedbackController alloc] initWithUser:user comment:comment];

        [controller showWindow:self];

    }
    
    [[NSUserDefaults standardUserDefaults] setValue: [NSDate date]
                                             forKey: KEY_LASTCRASCHECKDATE];

}

@end
