//
//  GCovVersionManager.h
//  CoverStory
//
//  Created by Thomas Van Lenten on 6/2/10.
//  Copyright 2010 Google Inc.
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


@interface GCovVersionManager : NSObject {
 @private
  NSDictionary *versionMap_;
}

+ (GCovVersionManager*)defaultManager;

// Installed gcovs
- (NSString*)defaultGCovPath;
- (NSArray*)installedVersions;

// Extracting versions from gcda/gcno files.
- (NSString*)versionFromGCovFile:(NSString*)path;

// Figures out the version and returns the right gcov path, if a matching
// version number isn't found, uses the default.
- (NSString*)gcovForGCovFile:(NSString*)path;

@end
