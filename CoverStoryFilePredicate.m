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
#import "GTMRegex.h"
#import <fnmatch.h>

@interface NSString (CoverStoryStringMatching)
- (BOOL)cs_isRegularExpressionEqual:(NSString*)string;
- (BOOL)cs_isWildcardPatternEqual:(NSString*)string;
@end

@implementation CoverStoryFilePredicate
- (BOOL)evaluateWithObject:(id)object {
  BOOL isGood = YES;
  NSString *path = [object valueForKey:@"sourcePath"];
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  BOOL hideSDKFiles = [defaults boolForKey:kCoverStoryHideSystemSourcesKey];
  if (hideSDKFiles) {
    isGood = !([path hasPrefix:@"/Developer"] || [path hasPrefix:@"/usr"]);
  }
  if (isGood) {
    NSString *text = [searchField_ stringValue];
    if ([text length] == 0) {
      isGood = YES;
    } else {
      CoverStoryFilterStringType type 
        = [defaults integerForKey:kCoverStoryFilterStringTypeKey];
      switch (type) {
        default:
        case kCoverStoryFilterStringTypeWildcardPattern:
          isGood = [path cs_isWildcardPatternEqual:text];
          break;
          
        case kCoverStoryFilterStringTypeRegularExpression:
          isGood = [path cs_isRegularExpressionEqual:text];
          break;
      }
    }
  }
  return isGood;
}

@end

@implementation NSString (CoverStoryStringMatching)
- (BOOL)cs_isRegularExpressionEqual:(NSString*)string {
  return [self gtm_firstSubStringMatchedByPattern:string] != nil;
}

- (BOOL)cs_isWildcardPatternEqual:(NSString*)string {
  NSString *pattern = [NSString stringWithFormat:@"*%@*", string];
  int flags = FNM_CASEFOLD;
  BOOL isGood = fnmatch([pattern UTF8String], [self UTF8String], flags) == 0;
  return isGood;
}
@end
