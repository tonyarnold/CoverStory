//
//  CoverStoryApplication.m
//  CoverStory
//
//  Copyright 2009 Google Inc.
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

#import <Cocoa/Cocoa.h>

@interface CoverStoryApplication : NSApplication
@end

@implementation CoverStoryApplication
- (id)handleOpenScriptCommand:(NSScriptCommand *)command {
  NSArray *files = [command directParameter];
  if ([files isMemberOfClass:[NSURL class]]) {
    files = [NSArray arrayWithObject:files];
  }
  NSDocumentController *docController 
    = [NSDocumentController sharedDocumentController];
  NSMutableArray *documents = [NSMutableArray arrayWithCapacity:[files count]];
  NSError *error = nil;
  for(NSURL *fileURL in files){
    CoverStoryDocument *doc 
      = [docController openDocumentWithContentsOfURL:fileURL
                                             display:YES 
                                               error:&error];
    if (error) {
      [command setScriptErrorNumber:(int)[error code]];
      [command setScriptErrorString:[error localizedDescription]];
      break;
    }
    [documents addObject:doc];
  }
  
  // If we are opened via a script we want to wait until we are fully
  // opened before returning. This prevents people from working on
  // us in a half opened state.
  NSRunLoop *loop = [NSRunLoop currentRunLoop];
  BOOL stillOpening = YES;
  while (stillOpening) {
    stillOpening = NO;
    for (CoverStoryDocument *doc in documents) {
      if (![doc completelyOpened]) {
        stillOpening = YES;
        break;
      }
    }
    if (stillOpening) {
      [loop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    }
  }
  
  if ([documents count] == 1) {
    documents = [documents objectAtIndex:0];
  }
  return documents;
}
@end
