//
//  CoverStoryDocumentController.m
//  CoverStory
//
//  Created by Dave MacLachlan on 2008/03/12.
//  Copyright 2008 Google Inc. All rights reserved.
//

#import "CoverStoryDocumentController.h"

@implementation CoverStoryDocumentController

// Allow us to open folders
- (int)runModalOpenPanel:(NSOpenPanel *)openPanel 
                forTypes:(NSArray *)extensions {
  [openPanel setCanChooseDirectories:YES];
  return [openPanel runModalForTypes:extensions];
}

@end
