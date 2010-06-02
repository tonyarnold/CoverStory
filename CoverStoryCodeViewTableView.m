//
//  CoverStoryCodeViewTableView.m
//  CoverStory
//
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

#import "CoverStoryCodeViewTableView.h"
#import "CoverStoryScroller.h"
#import "GTMDefines.h"

@implementation CoverStoryCodeViewTableView
- (void)awakeFromNib {
  [self setIntercellSpacing:NSMakeSize(0.0f, 0.0f)];
  CoverStoryScroller *scroller = [[[CoverStoryScroller alloc] init] autorelease];
  NSScrollView *scrollView = [self enclosingScrollView];
  [scrollView setVerticalScroller:scroller]; 
  
}

- (void)setCoverageData:(NSArray*)coverageData {
  NSScrollView *scrollView = [self enclosingScrollView];
  CoverStoryScroller *scroller = (CoverStoryScroller*)[scrollView verticalScroller]; 
  [scroller setEnabled:coverageData ? YES : NO];
  [scroller setCoverageData:coverageData];
}
  
- (void)insertNewline:(id)sender {
  [NSApp sendAction:@selector(openSelectedSource:) 
                 to:[self delegate] 
               from:self];
} 

- (void)keyDown:(NSEvent *)event {
  NSString *chars = [event characters];
  if ([chars length]) {
    unichar keyCode = [chars characterAtIndex:0];
    switch (keyCode) {        
      case '\r':
      case '\n':
        [NSApp sendAction:@selector(openSelectedSource:) 
                       to:nil 
                     from:self];
        break;
      
      case NSDownArrowFunctionKey:
        [NSApp sendAction:@selector(moveDownAndModifySelection:) 
                       to:nil 
                     from:self];
        break;

      case NSUpArrowFunctionKey:
        [NSApp sendAction:@selector(moveUpAndModifySelection:) 
                       to:nil 
                     from:self];
        break;
        
      default:
        [super keyDown:event];
        break;
    }
  }
}

@end
