//
//  CoverStoryDocument.h
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


#import <Cocoa/Cocoa.h>

@interface CoverStoryDocument : NSDocument {
 @private
  IBOutlet NSTableView *codeView_;  // the table that shows the code
  IBOutlet NSTextField *statistics_;  // lines we display stats in
  NSMutableArray *data_;  // array of NSCoverageData
  NSString *sourcePath_;  // where did our source code come from
}

// Opens up the source code file that corresponds to the gcov file we are
// examining.
- (IBAction)openSource:(id)sender;
@end
