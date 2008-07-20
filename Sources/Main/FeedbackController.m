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
#import "Uploader.h"
#import "Command.h"
#import "Application.h"
#import "CrashLogFinder.h"
#import "SystemDiscovery.h"
#import "Constants.h"
#import "ConsoleLog.h"

@implementation FeedbackController

- (id) init
{
    self = [super initWithWindowNibName:@"FeedbackReporter"];
    if (self != nil) {
        comment = @"";
        user = @"unknown";
        exception = @"";
    }
    return self;
}

- (void) setUser:(NSString*)pUser
{
    if (pUser != nil) {
        user = pUser;
    }
}

- (NSString*)user
{
    return user;
}

- (void) setComment:(NSString*)pComment
{
    comment = pComment;
}

- (NSString*) comment
{
    return comment;
}

- (void) setException:(NSString*)pException
{
    exception = pException;
}

- (NSString*) exception
{
    return exception;
}


// FIXME just for the display pattern binding
- (NSString*) applicationName
{
    return [Application applicationName];
}


- (void) showDetails:(BOOL)show animate:(BOOL)animate
{
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
}

- (IBAction)showDetails:(id)sender
{
    [self showDetails:[sender intValue] animate:YES];
}

- (IBAction)cancel:(id)sender
{
    [uploader cancel];
    
    [NSApp stopModalWithCode:NSCancelButton];
}

BOOL terminated = NO;

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

    NSLog(@"Sending feedback to %@", target);
    
    uploader = [[Uploader alloc] initWithTarget:[Application feedbackURL] delegate:self];
    
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:5];

    [dict setObject:user forKey:@"user"];
    [dict setObject:[emailField stringValue] forKey:@"email"];
    [dict setObject:[Application applicationVersion] forKey:@"version"];
    [dict setObject:[commentView string] forKey:@"comment"];
    [dict setObject:[systemView string] forKey:@"system"];
    [dict setObject:[consoleView string] forKey:@"console"];
    [dict setObject:[crashesView string] forKey:@"crashes"];
    [dict setObject:[shellView string] forKey:@"shell"];
    [dict setObject:[preferencesView string] forKey:@"preferences"];
    [dict setObject:[exceptionView string] forKey:@"exception"];
    //[dict setObject:[NSURL fileURLWithPath: @"/var/log/fsck_hfs.log"] forKey:@"file"];
    
    [uploader postAndNotify:dict];

    terminated = NO;

    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    while(!terminated) {
        if (![[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:100000]]) {
            break;
        }
        [pool release];
        pool = [[NSAutoreleasePool alloc] init];
    }
    [pool release];
    
    NSLog(@"done");

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
    
    terminated = YES;

    [commentView setEditable:YES];
    [sendButton setEnabled:YES];

    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:@"Sorry, failed to submit your feedback to the server."];
    [alert setInformativeText:[NSString stringWithFormat:@"Error: %@", [error localizedDescription]]];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert runModal];
    [alert release];

}

- (void) uploaderFinished:(Uploader*)pUploader
{
    NSLog(@"Upload finished");

    [indicator stopAnimation:self];
    [indicator setHidden:YES];

    terminated = YES;

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

    [NSApp stopModalWithCode:NSOKButton];

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

    NSArray *crashFiles = [CrashLogFinder findCrashLogsBefore:lastSubmissionDate];

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


- (void) windowDidLoad
{

    [commentView setString:comment];

    NSString *sender = [[NSUserDefaults standardUserDefaults] stringForKey:KEY_SENDEREMAIL];
    
    if (sender == nil) {
        sender = @"anonymous";

/*
        ABAddressBook *book = [ABAddressBook sharedAddressBook];
        ABMultiValue *addrs = [[book me] valueForProperty:kABEmailProperty];
        int count           = [addrs count];  // Determining the number of values
        
        if (count > 0) {
            email = [addrs valueAtIndex:0];
        }
*/
    }

    [emailField setStringValue:sender];

    [systemView setString:[self system]];
    [consoleView setString:[self console]];
    [crashesView setString:[self crashes]];
    [shellView setString:[self shell]];
    [preferencesView setString:[self preferences]];
    [exceptionView setString:[self exception]];
    
    [indicator setHidden:YES];

    [self showDetails:NO animate:NO];
    
    if ([exception length] == 0) {
        // select exception tab
        [tabView selectTabViewItemWithIdentifier:@"System"];
    } else {
        // select system tab
        [tabView selectTabViewItemWithIdentifier:@"Exception"];
    }
    
}

- (int) runModal
{
    [self showWindow:self];
    return [NSApp runModalForWindow:[self window]];
}


@end
