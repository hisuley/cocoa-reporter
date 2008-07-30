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

#import <Cocoa/Cocoa.h>
#import "Uploader.h"

@interface FeedbackController : NSWindowController {

    IBOutlet NSTextView *commentView;
    IBOutlet NSTextField *emailField;

    IBOutlet NSTabView *tabView;

    BOOL showDetails;

    IBOutlet NSTextView *systemView;
    IBOutlet NSTextView *consoleView;
    IBOutlet NSTextView *crashesView;
    IBOutlet NSTextView *shellView;
    IBOutlet NSTextView *preferencesView;
    IBOutlet NSTextView *exceptionView;

    IBOutlet NSProgressIndicator *indicator;

    IBOutlet NSButton *cancelButton;
    IBOutlet NSButton *sendButton;

    NSString *user;
    NSString *comment;
    NSString *exception;
    
    Uploader *uploader;
}

#pragma mark Accessors

- (void) setUser:(NSString*)user;
- (void) setComment:(NSString*)comment;
- (void) setException:(NSString*)exception;

- (NSString*) user;
- (NSString*) comment;
- (NSString*) exception;

#pragma mark Other

- (IBAction) showDetails:(id)sender;
- (IBAction) cancel:(id)sender;
- (IBAction) send:(id)sender;

- (BOOL) show;

// FIXME show not be required
- (NSString*) applicationName;

@end
