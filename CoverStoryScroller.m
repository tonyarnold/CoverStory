//
//  CoverStoryScroller.m
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

#import "CoverStoryScroller.h"
#import "CoverStoryCoverageData.h"
#import <Carbon/Carbon.h>

@implementation CoverStoryScroller

- (void)dealloc {
  [coverageData_ release];
  [super dealloc];
}

- (void)drawRect:(NSRect)rect {
  NSRect bounds = [self bounds];
  
  // Used for mapping NSScroller states to Carbon theme scroll states.
  ThemeTrackPressState states[] = {
    0, 
    kThemeTopTrackPressed, 
    0, 
    kThemeBottomTrackPressed, 
    kThemeTopOutsideArrowPressed, 
    kThemeBottomOutsideArrowPressed, 
    0
  };
  CGFloat height = NSHeight(rect);
  HIThemeTrackDrawInfo drawInfo = {
    0,
    kThemeScrollBarMedium,
    {{NSMinX(bounds), NSMinY(bounds)}, {NSWidth(bounds), NSHeight(bounds)}},
    0,
    (SInt32)height,
    0,
    0,
    0,
    0,
    0,
    {{0, states[[self hitPart]]}}
  };

  CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
  
  // Draw our track
  OSStatus err = HIThemeDrawTrack(&drawInfo, NULL, context, 0);
  if (err) {
    NSLog(@"Error drawing scroller: %d", err);
  }
  
  // If we have coverage data, draw the lines to denote lines we didn't hit
  // over the track. Note that this looks FAR better than Shark's impl.
  if (coverageData_) {
    NSRect slot = [self rectForPart:NSScrollerKnobSlot];
    NSUInteger count = [coverageData_ count];
    [[[NSColor redColor] colorWithAlphaComponent:0.8] set];
    CGFloat oldLineWidth = [NSBezierPath defaultLineWidth];
    
    // Make our lines thick enough that they "touch" when you have two lines
    // side by side.
    [NSBezierPath setDefaultLineWidth:NSHeight(slot) / count];
    for (NSUInteger i = 0; i < count; ++i) {
      CoverStoryCoverageLineData *data = [coverageData_ objectAtIndex:i];
      NSInteger hitCount = [data hitCount];
      if (hitCount == 0) {
        CGFloat y = NSMinY(slot) + NSHeight(slot) * ((CGFloat)i / (CGFloat)count);
        
        [NSBezierPath strokeLineFromPoint:NSMakePoint(NSMinX(slot), y)
                                  toPoint:NSMakePoint(NSMinX(slot) + NSWidth(slot), y)];
      }
    }
    [NSBezierPath setDefaultLineWidth:oldLineWidth];
  }
  
  // call our superclass to draw the knob for us, over our coverage data.
  [self drawKnob];
}

- (void)setCoverageData:(NSArray*)coverageData {
  if (coverageData != coverageData_) {
    [coverageData_ release];
    coverageData_ = [coverageData retain];
    [self setNeedsDisplay:YES];
  }
}
@end
