//
//  CoverStoryArrayController.m
//  CoverStory
//
//  Created by dmaclach on 06/03/10.
//  Copyright 2006-2010 Google Inc.
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

#import "CoverStoryArrayController.h"
#import "CoverStoryDocument.h"
#import "CoverStoryPreferenceKeys.h"
#import "NSUserDefaultsController+KeyValues.h"

static NSString *const kPrefsToWatch[] = {
  kCoverStorySystemSourcesPatternsKey,
  kCoverStoryUnittestSourcesPatternsKey,
};

#define kCoverStoryHideSDKSources @"hideSDKSources"
#define kCoverStoryHideUnittestSources @"hideUnittestSources"
#define kCoverStoryRemoveCommonSourcePrefix @"removeCommonSourcePrefix"
#define kCoverStoryFilterString @"filterString"

static NSString *const kDocumentKeyPathsToWatch[] = {
  kCoverStoryHideSDKSources,
  kCoverStoryHideUnittestSources,
  kCoverStoryRemoveCommonSourcePrefix,
  kCoverStoryFilterString
};

@implementation CoverStoryArrayController

- (void)dealloc {
  for (size_t i = 0;
       i < sizeof(kDocumentKeyPathsToWatch) / sizeof(kDocumentKeyPathsToWatch[0]);
       ++i) {
    [owningDocument_ removeObserver:self forKeyPath:kDocumentKeyPathsToWatch[i]];
  }
  NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
  for (size_t i = 0; i < sizeof(kPrefsToWatch) / sizeof(NSString*); ++i) {
    [defaults removeObserver:self
                  forKeyPath:[NSUserDefaultsController cs_valuesKey:kPrefsToWatch[i]]];
  }

  [super dealloc];
}


- (void)awakeFromNib {
  for (size_t i = 0;
       i < sizeof(kDocumentKeyPathsToWatch) / sizeof(kDocumentKeyPathsToWatch[0]);
       ++i) {
    [owningDocument_ addObserver:self
                      forKeyPath:kDocumentKeyPathsToWatch[i]
                         options:0
                         context:nil];
  }
  NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
  for (size_t i = 0; i < sizeof(kPrefsToWatch) / sizeof(NSString*); ++i) {
    [defaults addObserver:self
               forKeyPath:[NSUserDefaultsController cs_valuesKey:kPrefsToWatch[i]]
                  options:0
                  context:nil];
  }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
  BOOL handled = NO;
  if ([object isEqualTo:[NSUserDefaultsController sharedUserDefaultsController]]) {
    if ([keyPath isEqualToString:
         [NSUserDefaultsController cs_valuesKey:kCoverStorySystemSourcesPatternsKey]]) {
      if ([owningDocument_ hideSDKSources]) {
        // if we're hiding them then update because the pattern changed
        [self rearrangeObjects];
        handled = YES;
      }
    } else if ([keyPath isEqualToString:
                [NSUserDefaultsController cs_valuesKey:kCoverStoryUnittestSourcesPatternsKey]]) {
      if ([owningDocument_ hideUnittestSources]) {
        // if we're hiding them then update because the pattern changed
        [self rearrangeObjects];
        handled = YES;
      }
    }
  } else if ([object isEqualTo:owningDocument_]) {
    for (size_t i = 0;
         i < sizeof(kDocumentKeyPathsToWatch) / sizeof(kDocumentKeyPathsToWatch[0]);
         ++i) {
      if ([keyPath isEqualToString:kDocumentKeyPathsToWatch[i]]) {
        // user has changed a setting that requires a rearrange
        [self rearrangeObjects];
        handled = YES;
      }
    }
  }
  if (!handled) {
    _GTMDevLog(@"Unexpected observance of %@ of %@ (%@)", keyPath, object, change);
  }
}

- (void)updateCommonPathPrefix {
  if (!owningDocument_) return;

  NSString *newPrefix = nil;

  // now figure out a new prefix
  NSArray *arranged = [self arrangedObjects];
  if ([arranged count] == 0) {
    // empty string
    newPrefix = @"";
  } else {
    // process the list to find the common prefix

    // start w/ the first path, and now loop throught them all, but give up
    // the moment he only common prefix is "/"
    NSArray *sourcePaths = [arranged valueForKey:@"sourcePath"];
    NSEnumerator *enumerator = [sourcePaths objectEnumerator];
    newPrefix = [enumerator nextObject];
    NSString *basePath;
    while (([newPrefix length] > 1) &&
           (basePath = [enumerator nextObject])) {
      newPrefix = [newPrefix commonPrefixWithString:basePath
                                            options:NSLiteralSearch];
    }
    // if you have two files of:
    //   /Foo/bar/spam.m
    //   /Foo/baz/wee.m
    // we end up here w/ "/Foo/ba" as the common prefix, but we don't want
    // to do that, so we make sure we end in a slash
    if (![newPrefix hasSuffix:@"/"]) {
      NSRange lastSlash = [newPrefix rangeOfString:@"/"
                                           options:NSBackwardsSearch];
      if (lastSlash.location == NSNotFound) {
        newPrefix = @"";
      } else {
        newPrefix = [newPrefix substringToIndex:NSMaxRange(lastSlash)];
      }
    }
    // if we just have the leading "/", use no prefix
    if ([newPrefix length] <= 1) {
      newPrefix = @"";
    }
  }
  // send it back to the document
  [owningDocument_ setCommonPathPrefix:newPrefix];
}

- (void)rearrangeObjects {
  // this fires when the filtering changes
  [super rearrangeObjects];
  [self updateCommonPathPrefix];
}

- (void)setContent:(id)content {
  // this fires as results are added during a load
  [super setContent:content];
  [self updateCommonPathPrefix];
}

@end
