//
//  CoverStoryCoverageData.h
//  CoverStory
//
//  Created by dmaclach on 12/24/06.
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

#import <Cocoa/Cocoa.h>

// Keeps track of the number of times a line of code has been hit. There is
// one CoverStoryCoverageData object per line of code in the file. Note that
// a hitcount of -1 means that the line is not executed.

@interface CoverStoryCoverageData : NSObject<NSCopying> {
 @private
  SInt32 hitCount_;  // how many times this line has been hit
  NSString *line_;  //  the line
}

+ (id)coverageDataWithLine:(NSString*)line hitCount:(UInt32)hitCount;
- (id)initWithLine:(NSString*)line hitCount:(UInt32)hitCount;
- (NSString*)line;
- (SInt32)hitCount;
@end
