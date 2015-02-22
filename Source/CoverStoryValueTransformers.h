//
//  CoverStoryValueTransformers.h
//  CoverStory
//
//  Copyright 2008-2009 Google Inc.
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

#import <Foundation/Foundation.h>

// Transformer for changing Line Data to source lines.
// Used for second column of source code table.
@interface CoverageLineDataToSourceLineTransformer : NSValueTransformer
+ (void)registerDefaults;
@end

// Transformer for changing line coverage to short summaries.
// Used at top of file list.
@interface LineCoverageToCoverageShortSummaryTransformer : NSValueTransformer
@end

// Transformer for changing line coverage to summaries.
// Used for top of code window summaries.
@interface FileLineCoverageToCoverageSummaryTransformer : NSValueTransformer
@end
