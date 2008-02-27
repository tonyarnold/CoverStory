//
//  CoverStoryCoverageCell.m
//  CoverStory
//
//  Created by thomasvl on 2/26/08.
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

#import "CoverStoryCoverageCell.h"
#import "CoverStoryCoverageData.h"

@implementation CoverStoryCoverageCell
- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
  CoverStoryCoverageFileData *data = [self objectValue];
  float coverage = [data coverage];
  NSString *coverageString = [NSString stringWithFormat:@"%.2f%%", coverage];
  NSColor *textColor;
  if (coverage < 40.0f) {
    textColor = [NSColor redColor];
  } else if (coverage < 65.0f) {
    textColor = [NSColor brownColor];
  } else {
    textColor = [NSColor blackColor];
  }
  NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
    textColor, NSForegroundColorAttributeName, 
    [self font], NSFontAttributeName,
    nil];
  cellFrame.origin.x += 5;
  cellFrame.size.width -= 5;
  [coverageString drawInRect:cellFrame withAttributes:attributes];
}
@end
