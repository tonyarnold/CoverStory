//
//  CoverStoryFilePredicate.m
//  CoverStory
//
//  Created by dmaclach on 03/20/08.
//  Copyright 2008 Google Inc.
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
#import "CoverStoryFilePredicate.h"
#import "CoverStoryPreferenceKeys.h"

@implementation CoverStoryFilePredicate

- (BOOL)evaluateWithObject:(id)object {
  NSString *text = [searchField_ stringValue];
  NSString *path = [object valueForKey:@"sourcePath"];
  BOOL isGood = NO;
  if ([text length] == 0) {
    isGood = YES;
  } else {
    isGood = [path rangeOfString:text 
                         options:NSCaseInsensitiveSearch].location != NSNotFound;
  }
  if (isGood) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL hideSDKFiles = [defaults boolForKey:kCoverStoryHideSystemSourcesKey];
    if (hideSDKFiles) {
      isGood = ![path hasPrefix:@"/Developer"] && 
               ![path hasPrefix:@"/usr"];
    }
  }
  return isGood;
}

@end
