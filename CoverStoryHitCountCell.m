//
//  CoverStoryHitCountCell.m
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

#import "CoverStoryHitCountCell.h"
#import "CoverStoryCoverageData.h"

@implementation CoverStoryHitCountCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
  CoverStoryCoverageLineData *data = [self objectValue];
  
  // draw background
  [[NSColor colorWithDeviceWhite:0.95 alpha:1.0] set];
  NSRectFill(cellFrame);
  
  // draw bevel on right edge
  [[NSColor colorWithDeviceWhite:0.4 alpha:1.0] set];
  NSPoint bottom = NSMakePoint(NSMinX(cellFrame) + NSWidth(cellFrame) - 0.5, 
                               NSMinY(cellFrame));
  NSPoint top = NSMakePoint(NSMinX(cellFrame) + NSWidth(cellFrame) - 0.5, 
                            NSMinY(cellFrame) + NSHeight(cellFrame));
  [NSBezierPath strokeLineFromPoint:bottom toPoint:top];
  
  // Draw the hitcount
  SInt32 hitCount = [data hitCount];
  if (hitCount != -1) {
    NSMutableParagraphStyle *pStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
    [pStyle setAlignment:NSRightTextAlignment];
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
      pStyle, NSParagraphStyleAttributeName, 
      [NSColor colorWithDeviceWhite:0.4 alpha:1.0], NSForegroundColorAttributeName, 
      [self font], NSFontAttributeName, 
      nil];
    cellFrame.size.width -= 2;
    NSString *displayString = nil;
    if (hitCount == -2) {
      displayString = @"--"; // for non-feasible lines
    } else {
      displayString = [NSString stringWithFormat:@"%d", hitCount];
    }
    [displayString drawInRect:cellFrame withAttributes:attributes];
  }
}
@end
