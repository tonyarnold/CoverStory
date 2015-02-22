//
//  CoverStoryScroller.h
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

// Draws the special CoverStory scroller that has the hilights in it to show
// places that don't have coverage
@interface CoverStoryScroller : NSScroller {
 @private
  NSArray *coverageData_; 
}

// set the data for the scroller to work from
- (void)setCoverageData:(NSArray*)coverageData;

@end
