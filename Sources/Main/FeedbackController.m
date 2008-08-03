/*
 * Copyright 2008, Torsten Curdt
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "FeedbackController.h"
#import "FRFeedbackReporter.h"
#import "Uploader.h"
#import "Command.h"
#import "Application.h"
#import "CrashLogFinder.h"
#import "SystemDiscovery.h"
#import "Constants.h"
#import "ConsoleLog.h"

@implementation FeedbackController

#pragma mark Construction

- (id) init
{
    self = [super initWithWindowNibName:@"FeedbackReporter"];
    if (self != nil) {
        detailsShown = YES;
    }
    return self;
}

#pragma mark Accessors

- (id) delegate
{
	return delegate;
}

- (void) setDelegate:(id) pDelegate
{
	delegate = pDelegate;
}

- (void) setComment:(NSString*)comment
{
    [commentView setString:comment];
}

- (NSString*) comment
{
    return [commentView string];
}

- (void) setException:(NSString*)exception
{
    [exceptionView setString:exception];
}

- (NSString*) exception
{
    return [exceptionView string];
}

#pragma mark UI Actions

- (void) showDetails:(BOOL)show animate:(BOOL)animate
{
    if (show == detailsShown) {
        return;
    }
    
    NSSize fullSize = NSMakeSize(455, 302);
    
    NSRect windowFrame = [[self window] frame];
        
    if (show) {

        windowFrame.origin.y -= fullSize.height;
        windowFrame.size.height += fullSize.height;
        [[self window] setFrame: windowFrame
                        display: YES
                        animate: animate];

    } else {
        windowFrame.origin.y += fullSize.height;
        windowFrame.size.height -= fullSize.height;
        [[self window] setFrame: windowFrame
                        display: YES
                        animate: animate];
        
    }
    
    detailsShown = show;
}

- (IBAction)showDetails:(id)sender
{
    [self showDetails:[sender intValue] animate:YES];
}

- (IBAction)cancel:(id)sender
{
    [uploader cancel];
    
    [self close];
}

- (IBAction)send:(id)sender
{
    if (uploader != nil) {
        NSLog(@"Still uploading");
        return;
    }
            
    NSString *target = [Application feedbackURL];
    
    if (target == nil) {
        NSLog(@"You are missing the %@ key in your Info.plist!", KEY_TARGETURL);
        return;        
    }

    uploader = [[Uploader alloc] initWithTarget:[Application feedbackURL] delegate:self];
    
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:5];

	if ([delegate respondsToSelector:@selector(customParametersForFeedbackReport)]) {
        [dict addEntriesFromDictionary:[delegate customParametersForFeedbackReport]];
    }

    [dict setObject:[emailField stringValue] forKey:@"email"];
    [dict setObject:[Application applicationVersion] forKey:@"version"];
    [dict setObject:[commentView string] forKey:@"comment"];
    [dict setObject:[systemView string] forKey:@"system"];
    [dict setObject:[consoleView string] forKey:@"console"];
    [dict setObject:[crashesView string] forKey:@"crashes"];
    [dict setObject:[shellView string] forKey:@"shell"];
    [dict setObject:[preferencesView string] forKey:@"preferences"];
    [dict setObject:[exceptionView string] forKey:@"exception"];
    
    NSLog(@"Sending feedback to %@", target);
    
    [uploader postAndNotify:dict];

    [dict release];
}

- (void) uploaderStarted:(Uploader*)pUploader
{
    NSLog(@"Upload started");

    [indicator setHidden:NO];
    [indicator startAnimation:self];    
    
    [commentView setEditable:NO];
    [sendButton setEnabled:NO];
}

- (void) uploaderFailed:(Uploader*)pUploader withError:(NSError*)error
{
    NSLog(@"Upload failed: %@", error);

    [indicator stopAnimation:self];
    [indicator setHidden:YES];

    [uploader release], uploader = nil;
    
    [commentView setEditable:YES];
    [sendButton setEnabled:YES];

    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:@"Sorry, failed to submit your feedback to the server."];
    [alert setInformativeText:[NSString stringWithFormat:@"Error: %@", [error localizedDescription]]];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert runModal];
    [alert release];

    [self close];
}

- (void) uploaderFinished:(Uploader*)pUploader
{
    NSLog(@"Upload finished");

    [indicator stopAnimation:self];
    [indicator setHidden:YES];

    NSString *response = [uploader response];

    [uploader release], uploader = nil;

    [commentView setEditable:YES];
    [sendButton setEnabled:YES];

    NSLog(@"response = %@", response);

    NSArray *lines = [response componentsSeparatedByString:@"\n"];
    int i = [lines count];
    while(i--) {
        NSString *line = [lines objectAtIndex:i];
        
        if ([line length] == 0) {
            continue;
        }
        
        if (![line hasPrefix:@"OK "]) {

            NSAlert *alert = [[NSAlert alloc] init];
            [alert addButtonWithTitle:@"OK"];
            [alert setMessageText:@"Sorry, failed to submit your feedback to the server."];
            [alert setInformativeText:[NSString stringWithFormat:@"Error: %@", line]];
            [alert setAlertStyle:NSWarningAlertStyle];
            [alert runModal];
            [alert release];
            
            return;
        }
    }

    [[NSUserDefaults standardUserDefaults] setValue: [NSDate date]
                                             forKey: KEY_LASTSUBMISSIONDATE];

    [[NSUserDefaults standardUserDefaults] setObject:[emailField stringValue]
                                              forKey:KEY_SENDEREMAIL];

    [self close];
}


- (NSString*) console
{
    ConsoleLog *console = [[ConsoleLog alloc] init];

    NSString *log = [console log];
    
    [console release];
    
    return log;
}


- (NSString*) system
{
    NSMutableString *system = [[[NSMutableString alloc] init] autorelease];

    SystemDiscovery *discovery = [[SystemDiscovery alloc] init];

    NSDictionary *dict = [discovery discover];

    [system appendFormat:@"os version = %@\n", [dict valueForKey:@"OS_VERSION"]];
    [system appendFormat:@"ram = %@\n", [dict valueForKey:@"RAM_SIZE"]];
    [system appendFormat:@"cpu type = %@\n", [dict valueForKey:@"CPU_TYPE"]];
    [system appendFormat:@"cpu count = %@\n", [dict valueForKey:@"CPU_COUNT"]];
    [system appendFormat:@"cpu speed = %@\n", [dict valueForKey:@"CPU_SPEED"]];

    [discovery release];

    return system;
}


- (NSString*) crashes
{
    NSMutableString *crashes = [NSMutableString string];

    NSDate *lastSubmissionDate = [[NSUserDefaults standardUserDefaults] valueForKey:KEY_LASTSUBMISSIONDATE];

    NSLog(@"Checking for crash files earlier than %@", lastSubmissionDate);

    NSArray *crashFiles = [CrashLogFinder findCrashLogsSince:lastSubmissionDate];

    int i = [crashFiles count];
    while(i--) {
        NSString *crashFile = [crashFiles objectAtIndex:i];
        [crashes appendFormat:@"File: %@\n", crashFile];
        [crashes appendString:[NSString stringWithContentsOfFile:crashFile]];
        [crashes appendString:@"\n"];
    }

    return crashes;
}

- (NSString*) shell
{
    NSMutableString *shell = [NSMutableString string];

    NSString *scriptPath = [[NSBundle mainBundle] pathForResource:FILE_SHELLSCRIPT ofType:@"sh"];

    if ([[NSFileManager defaultManager] fileExistsAtPath:scriptPath]) {

        Command *cmd = [[Command alloc] initWithPath:scriptPath];
        [cmd setOutput:shell];
        [cmd setError:shell];
        int ret = [cmd execute];
        [cmd release];

        NSLog(@"Script returned code = %d", ret);
        
    } else {
        NSLog(@"No custom script to execute");
    }

    return shell;
}

- (NSString*) preferences
{
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    
    return [NSString stringWithFormat:@"%@", [preferences persistentDomainForName:[Application applicationIdentifier]]];
}

- (void) windowWillClose: (NSNotification *) n
{
	[uploader cancel];
}

- (void) windowDidLoad
{
	[[self window] setDelegate:self];
}


- (void) reset
{
    NSString *email = [[NSUserDefaults standardUserDefaults] stringForKey:KEY_SENDEREMAIL];
    
    if (email == nil) {
        email = @"anonymous";

/*
        ABAddressBook *book = [ABAddressBook sharedAddressBook];
        ABMultiValue *addrs = [[book me] valueForProperty:kABEmailProperty];
        int count = [addrs count];
        
        if (count > 0) {
            email = [addrs valueAtIndex:0];
        }
*/
    }


    [messageField setStringValue:[NSString stringWithFormat:
        NSLocalizedString(@"Encountered a problem with %@?\n\n"
                           "Please provide some comments of what happened.\n"
                           "See below the information that will get send along.", nil),
        [Application applicationName]]];


    [emailField setStringValue:email];
    [exceptionView setString:@""];
    [commentView setString:@""];
    [systemView setString:[self system]];
    [consoleView setString:[self console]];
    [crashesView setString:[self crashes]];
    [shellView setString:[self shell]];
    [preferencesView setString:[self preferences]];
    [exceptionView setString:[self exception]];
    
    [indicator setHidden:YES];

    [self showDetails:NO animate:NO];
    
}

- (void) showWindow:(id)sender
{
    // TODO show/hide tabs according to what information is there

    if ([[exceptionView string] length] == 0) {
        // select exception tab
        [tabView selectTabViewItemWithIdentifier:@"System"];
    } else {
        // select system tab
        [tabView selectTabViewItemWithIdentifier:@"Exception"];
    }


    [super showWindow:sender];
}

- (BOOL) isShown
{
    return [[self window] isVisible];
}

@end
