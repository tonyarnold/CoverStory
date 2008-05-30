//
//  CoverStoryApplicationDelegate.m
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

#import "CoverStoryApplicationDelegate.h"
#import "CoverStoryDocumentController.h"
#import "CoverStoryPreferenceKeys.h"
#import "CoverStoryFilePredicate.h"
#import "CoverStoryDocument.h"

@implementation CoverStoryApplicationDelegate
- (void)applicationWillFinishLaunching:(NSNotification *)notification {
  // Transformers need to be registered on Tiger
  id transformerNames[] = {
    @"CoverageLineDataToHitCountTransformer",
    @"CoverageLineDataToSourceLineTransformer",
    @"CoverageFileDataToSourcePathTransformer",
    @"CoverageFileDataToCoveragePercentageTransformer",
    @"LineCoverageToCoverageSummaryTransformer",
    @"LineCoverageToCoverageShortSummaryTransformer",
    @"FileLineCoverageToCoverageSummaryTransformer",
    @"CoverageLineDataToComplexityTransformer",
    @"CoverageFileDataToComplexityTransformer",
    @"CoverageTypeToFileCoverageHeaderTransformer"
  };
  for (size_t i = 0; i < sizeof(transformerNames) / sizeof(id); ++i) {
    Class class = NSClassFromString(transformerNames[i]);
    [NSValueTransformer setValueTransformer:[[class alloc] init]
                                    forName:transformerNames[i]];
  }
  
  // Most code uses initialize to get the defaults in, but these two classes
  // won't have initialize called until a window gets created, so we force their
  // defaults in now so the prefs and menus will have the right states.
  [CoverStoryFilePredicate registerDefaults];
  [CoverStoryDocument registerDefaults];
  
  // Set our document controller up as the shared document controller
  // so we don't ge NSDocumentController instead.
  [[[CoverStoryDocumentController alloc] init] autorelease];
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)theApplication {
  return NO;
}

- (IBAction)hideSDKSources:(id)sender {
  // Doesn't do anything, just exists so that prefs will toggle via bindings.
  // Seems weird to need it, but hey.
}
- (IBAction)hideUnittestSources:(id)sender {
  // Same comment as hideSDKSources
}
- (IBAction)showComplexity:(id)sender {
  // Same comment as hideSDKSources
}
@end
