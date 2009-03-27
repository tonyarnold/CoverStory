//
//  CoverStoryApplicationDelegate.m
//  CoverStory
//
//  Created by dmaclach on 12/20/06.
//  Copyright 2006-2007 Google Inc.
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not
//  use this file except in compliance with the License.  You may obtain a copy
//  of the License at
// 
//  http://www.apache.org/licenses/LICENSE-2.0
// 
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
//  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
//  License for the specific language governing permissions and limitations under
//  the License.
//

#import "CoverStoryApplicationDelegate.h"
#import "CoverStoryDocumentController.h"
#import "CoverStoryFilePredicate.h"
#import "CoverStoryDocument.h"
#import "CoverStoryPreferenceKeys.h"

const NSInteger kCoverStorySDKToolbarIconTag = 1026;
const NSInteger kCoverStoryUnittestToolbarIconTag = 1027;

@implementation CoverStoryApplicationDelegate
- (void)applicationWillFinishLaunching:(NSNotification *)notification {
  // Most code uses initialize to get the defaults in, but these two classes
  // won't have initialize called until a window gets created, so we force their
  // defaults in now so the prefs and menus will have the right states.
  [CoverStoryFilePredicate registerDefaults];
  [CoverStoryDocument registerDefaults];
  
  // Set our document controller up as the shared document controller
  // so we don't get NSDocumentController instead.
  [[[CoverStoryDocumentController alloc] init] autorelease];
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)theApplication {
  return NO;
}

- (void)toggleKey:(NSString*)key {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  BOOL value = [ud boolForKey:key];
  [ud setBool:!value forKey:key];  
}

- (IBAction)toggleSDKSourcesShown:(id)sender {
  [self toggleKey:kCoverStoryHideSystemSourcesKey];
}

- (IBAction)toggleUnittestSourcesShown:(id)sender {
  [self toggleKey:kCoverStoryHideUnittestSourcesKey];
}

-(BOOL)validateToolbarItem:(NSToolbarItem *)theItem {
  NSInteger tag = [theItem tag];
  NSString *key = nil;
  NSString *label = nil;
  NSString *iconName = nil;
  if (tag == kCoverStorySDKToolbarIconTag) {
    key = kCoverStoryHideSystemSourcesKey;
    label = NSLocalizedString(@"SDK Files", nil);
    iconName = @"SDK";
  } else if (tag == kCoverStoryUnittestToolbarIconTag) {
    key = kCoverStoryHideUnittestSourcesKey;
    label = NSLocalizedString(@"Unittest Files", nil);
    iconName = @"UnitTests";
  }
  if (key) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    BOOL value = [ud boolForKey:key];
    NSString *labelFormat = nil;
    NSString *iconFormat = nil;
    if (value) {
      labelFormat = NSLocalizedString(@"Show %@", nil); 
      iconFormat = @"%@";
    } else {
      labelFormat = NSLocalizedString(@"Hide %@", nil); 
      iconFormat = @"%@Hide";
    }
    NSString *fullLabel = [NSString stringWithFormat:labelFormat, label];
    NSString *fullIcon = [NSString stringWithFormat:iconFormat, iconName];
    [theItem setLabel:fullLabel];
    NSImage *image = [NSImage imageNamed:fullIcon];
    [theItem setImage:image];
  }
  return YES;
}

@end
