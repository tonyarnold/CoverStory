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
#import "CoverStoryValueTransformers.h"

@implementation CoverStoryApplicationDelegate
- (void)applicationWillFinishLaunching:(NSNotification *)notification {
  // Register default values for various classes so that prefs and menus 
  // will have the right states.
  [CoverStoryFilePredicate registerDefaults];
  [CoverStoryDocument registerDefaults];
  [CoverageLineDataToSourceLineTransformer registerDefaults];
  
  // Set our document controller up as the shared document controller
  // so we don't get NSDocumentController instead.
  [[[CoverStoryDocumentController alloc] init] autorelease];
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)theApplication {
  return NO;
}

- (NSColor *)colorForKey:(NSString *)key {
  NSUserDefaultsController *defaults
    = [NSUserDefaultsController sharedUserDefaultsController];
  id values = [defaults values];
  NSData *colorData = [values valueForKey:key];
  NSColor *color = nil;
  if (colorData) {
    color = (NSColor *)[NSUnarchiver unarchiveObjectWithData:colorData];
  }
  return color;
}

- (void)setColor:(NSColor *)color forKey:(NSString *)key {
  NSData *colorData = [NSArchiver archivedDataWithRootObject:color];
  if (colorData) {
    NSUserDefaultsController *defaults
      = [NSUserDefaultsController sharedUserDefaultsController];
    [[defaults defaults] setObject:colorData forKey:key];
  }
}

- (NSColor *)executedLineColor {
  return [self colorForKey:kCoverStoryExecutedLineColorKey];
}

- (void)setExecutedLineColor:(NSColor *)color {
  [self setColor:color forKey:kCoverStoryExecutedLineColorKey];
}

- (NSColor *)missedLineColor {
  return [self colorForKey:kCoverStoryMissedLineColorKey];
}

- (void)setMissedLineColor:(NSColor *)color {
  [self setColor:color forKey:kCoverStoryMissedLineColorKey];
}

- (NSColor *)unexecutableLineColor {
  return [self colorForKey:kCoverStoryUnexecutableLineColorKey];
}

- (void)setUnexecutableLineColor:(NSColor *)color {
  [self setColor:color forKey:kCoverStoryUnexecutableLineColorKey];
}

- (NSColor *)nonFeasibleLineColor {
  return [self colorForKey:kCoverStoryNonFeasibleLineColorKey];
}

- (void)setNonFeasibleLineColor:(NSColor *)color {
  [self setColor:color forKey:kCoverStoryNonFeasibleLineColorKey];
}

- (BOOL)application:(NSApplication *)sender delegateHandlesKey:(NSString *)key {
  return ([key isEqual:@"nonFeasibleLineColor"] ||
          [key isEqual:@"unexecutableLineColor"] ||
          [key isEqual:@"missedLineColor"] ||
          [key isEqual:@"executedLineColor"]);
}
  
@end
