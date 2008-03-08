//
//  CoverStoryLineCell.m
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

#import "CoverStoryLineCell.h"
#import "CoverStoryCoverageData.h"

@implementation CoverStoryLineCell
- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
  CoverStoryCoverageLineData *data = [self objectValue];
  NSString *line = [data line];
  SInt32 hitCount = [data hitCount];
  NSColor *textColor;
  if (hitCount == 0) {
    [[NSColor colorWithDeviceRed:1.0 green:0.0 blue:0.0 alpha:1.0] set];
    NSRectFill(cellFrame);
    textColor = [NSColor whiteColor];
  } else if (hitCount < 0) {
    textColor = [NSColor grayColor];
  } else {
    textColor = [NSColor blackColor];
  }
  NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
    textColor, NSForegroundColorAttributeName, 
    [self font], NSFontAttributeName,
    nil];
  cellFrame.origin.x += 5;
  cellFrame.size.width -= 5;
  [line drawInRect:cellFrame withAttributes:attributes];
}
@end
