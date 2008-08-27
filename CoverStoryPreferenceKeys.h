//
//  CoverStoryPreferenceKeys.h
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
 
// Should we filter out system sources
#define kCoverStoryHideSystemSourcesKey @"hideSystemSources"  // Boolean
#define kCoverStorySystemSourcesPatternsKey @"systemSourcesPatterns"  // NSArray of NSString

// Should we filter out any test unittesting sources
#define kCoverStoryHideUnittestSourcesKey @"hideUnittestSources"  // Boolean
#define kCoverStoryUnittestSourcesPatternsKey @"unittestSourcesPatterns"  // NSArray of NSString

// Are we showing coverage or complexity
#define kCoverStoryShowComplexityKey @"showComplexity"  // Boolean

// Should we remove common prefixes in the source list
#define kCoverStoryRemoveCommonSourcePrefix @"removeCommonSourcePrefix"  // Boolean

// Colors to display things in our views
#define kCoverStoryMissedLineColorKey @"missedLineColor"  // NSColor
#define kCoverStoryUnexecutableLineColorKey @"unexecutableLineColor"  // NSColor
#define kCoverStoryNonFeasibleLineColorKey @"nonFeasibleLineColor"  // NSColor
#define kCoverStoryExecutedLineColorKey @"executedLineColor"  // NSColor

#define kCoverStoryFilterStringTypeKey @"filterStringType" // CoverStoryFilterStringType

typedef enum {
  kCoverStoryFilterStringTypeWildcardPattern = 0,
  kCoverStoryFilterStringTypeRegularExpression
} CoverStoryFilterStringType;
