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
    // nothing yet
  }
  return self;
}

- (void)dealloc {
  [fileData_ release];
  [super dealloc];
}

- (NSString *)windowNibName {
  return @"CoverStoryDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController {
  // Now that our nib is loaded, we can figure out statistics and set up
  // our scroller correctly
  
  // Find the first missed line
  int firstMissedLine = -1;
  int count = 0;
  NSEnumerator *dataEnum = [[fileData_ lines] objectEnumerator];
  CoverStoryCoverageLineData* dataPoint;
  while ((dataPoint = [dataEnum nextObject]) && (firstMissedLine == -1)) {
    int hitCount = [dataPoint hitCount];
    if (hitCount == 0) {
      firstMissedLine = count;
    }
    ++count;
  }
  SInt32 totalLines = [fileData_ numberTotalLines];
  SInt32 hitLines   = [fileData_ numberHitCodeLines];
  SInt32 codeLines  = [fileData_ numberCodeLines];
  SInt32 nonfeasible  = [fileData_ numberNonFeasibleLines];
  NSString *statString = nil;
  if (nonfeasible) {
    statString = [NSString stringWithFormat:
      @"Executed %.2f%% of %d lines (%d executed, %d executable, %d non-feasible, %d total lines)", 
         [fileData_ coverage], codeLines, hitLines, codeLines, nonfeasible, totalLines];
  } else {
    statString = [NSString stringWithFormat:
      @"Executed %.2f%% of %d lines (%d executed, %d executable, %d total lines)", 
         [fileData_ coverage], codeLines, hitLines, codeLines, totalLines];
  }
  [statistics_ setStringValue:statString];
  
  // We want no cell spacing to make it look normal
  [codeView_ setIntercellSpacing:NSMakeSize(0.0,0.0)];
  
  // Create up our scroller, it will be owned by the tableview.
  CoverStoryScroller *scroller = [[[CoverStoryScroller alloc] init] autorelease];
  NSScrollView *scrollView = [codeView_ enclosingScrollView];
  [scrollView setVerticalScroller:scroller];
  [scroller setCoverageData:[fileData_ lines]];
  [scroller setEnabled:YES]; 
  
  // Scroll to the first missed line if we have one.
  if (firstMissedLine != -1) {
    float value = (float)firstMissedLine / (float)totalLines;
    float middleOffset = (NSHeight([scrollView documentVisibleRect]) * 0.5);
    float contentHeight = NSHeight([[scrollView documentView] bounds]);
    value = value * contentHeight - middleOffset;
    [[scrollView documentView] scrollPoint:NSMakePoint(0, value)];
  }
}

- (BOOL)readFromData:(NSData *)data 
              ofType:(NSString *)typeName 
               error:(NSError **)outError {
  fileData_ = [[CoverStoryCoverageFileData coverageFileDataFromData:data] retain];
  return (fileData_ != nil);
}

- (int)numberOfRowsInTableView:(NSTableView *)tableView {
  return [fileData_ numberTotalLines];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn 
            row:(int)row {
  return [[fileData_ lines] objectAtIndex:row];
}

- (NSString *)sourcePath {
  return [fileData_ sourcePath];
}

- (IBAction)openSource:(id)sender {
  [[NSWorkspace sharedWorkspace] openFile:[self sourcePath]];
}

- (BOOL)isDocumentEdited {
  return NO;
}

- (void)setFileData:(CoverStoryCoverageFileData *)fileData {
  [fileData_ autorelease];
  fileData_ = [fileData retain];
  // we don't actually have to get the UI to reinit, because we only call this
  // from CoverStoreCollectionDoc and windowControllerDidLoadNib gets called
  // after this call.
}


@end
