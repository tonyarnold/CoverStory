//
//  CoverStoryDocument.m
//  CoverStory
//
//  Created by dmaclach on 12/20/06.
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

#import "CoverStoryDocument.h"
#import "CoverStoryCoverageData.h"
#import "CoverStoryScroller.h"

@implementation CoverStoryDocument
- (id)init {
  self = [super init];
  if (self) {
    data_ = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void)dealloc {
  [data_ release];
  [sourcePath_ release];
  [super dealloc];
}

- (NSString *)windowNibName {
  return @"CoverStoryDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController {
  // Now that our nib is loaded, we can figure out statistics and set up
  // our scroller correctly
  
  // Statistics first
  int hitLines = 0;  // how many lines did we hit
  int codeLines = 0; // how many actual executable lines
  int firstMissedLine = -1; // what's the line number of the first missed line
  int count = 0;
  NSEnumerator *dataEnum = [data_ objectEnumerator];
  CoverStoryCoverageData* dataPoint;
  while ((dataPoint = [dataEnum nextObject])) {
    int hitCount = [dataPoint hitCount];
    if (hitCount == 0) {
      ++codeLines;
      if (firstMissedLine == -1) {
        firstMissedLine = count;
      }
    } else {
      if (hitCount > 0) {
        ++hitLines;
      }
    }
    ++count;
  }
  codeLines += hitLines;
  NSString *statString = [NSString stringWithFormat:
    @"Executed %.2f%% of %d lines (%d executed, %d executable, %d total lines)", 
    (float)hitLines/(float)codeLines * 100.0f, codeLines, hitLines, codeLines, 
    [data_ count]];
  [statistics_ setStringValue:statString];
  
  // We want no cell spacing to make it look normal
  [codeView_ setIntercellSpacing:NSMakeSize(0.0,0.0)];
  
  // Create up our scroller, it will be owned by the tableview.
  CoverStoryScroller *scroller = [[[CoverStoryScroller alloc] init] autorelease];
  NSScrollView *scrollView = [codeView_ enclosingScrollView];
  [scrollView setVerticalScroller:scroller];
  [scroller setCoverageData:data_];
  [scroller setEnabled:YES]; 
  
  // Scroll to the first missed line if we have one.
  if (firstMissedLine != -1) {
    float value = (float)firstMissedLine / (float)[data_ count];
    float middleOffset = (NSHeight([scrollView documentVisibleRect]) * 0.5);
    float contentHeight = NSHeight([[scrollView documentView] bounds]);
    value = value * contentHeight - middleOffset;
    [[scrollView documentView] scrollPoint:NSMakePoint(0, value)];
  }
}

- (BOOL)readFromData:(NSData *)data 
              ofType:(NSString *)typeName 
               error:(NSError **)outError {
  // Scan in our data and create up out CoverStoryCoverageData objects.
  // TODO(dmaclach): make this routine a little more "error tolerant"
  [data_ removeAllObjects];
  NSString *string = [[[NSString alloc] initWithData:data 
                                            encoding:NSUTF8StringEncoding] autorelease];
  NSScanner *scanner = [NSScanner scannerWithString:string];
  [scanner setCharactersToBeSkipped:nil];
  while (![scanner isAtEnd]) {
    NSString *segment;
    BOOL goodScan = [scanner scanUpToString:@":" intoString:&segment];
    [scanner setScanLocation:[scanner scanLocation] + 1];
    SInt32 hitCount = 0;
    if (goodScan) {
      hitCount = [segment intValue];
      if (hitCount == 0) {
        if ([segment characterAtIndex:[segment length] - 1] != '#') {
          hitCount = -1;
        }
      }
    }
    goodScan = [scanner scanUpToString:@":" intoString:&segment];
    [scanner setScanLocation:[scanner scanLocation] + 1];
    NSCharacterSet *linefeeds = [NSCharacterSet characterSetWithCharactersInString:@"\n\r"];
    goodScan = [scanner scanUpToCharactersFromSet:linefeeds
                                       intoString:&segment];
    if (!goodScan) {
      segment = @"";
    }
    [scanner setScanLocation:[scanner scanLocation] + 1];
    [data_ addObject:[CoverStoryCoverageData coverageDataWithLine:segment 
                                                         hitCount:hitCount]];
  }
  
  // The first five lines are not data we want to show to the user
  if ([data_ count] > 5) {
    // The first line contains the path to our source.
    sourcePath_ = [[[[data_ objectAtIndex:0] line] substringFromIndex:7] retain];
    [data_ removeObjectsInRange:NSMakeRange(0,5)];
  }
  return YES;
}

- (int)numberOfRowsInTableView:(NSTableView *)tableView {
  return [data_ count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn 
            row:(int)row {
  return [data_ objectAtIndex:row];
}

- (NSString*)sourcePath {
  return sourcePath_;
}

- (IBAction)openSource:(id)sender {
  [[NSWorkspace sharedWorkspace] openFile:sourcePath_];
}

@end
