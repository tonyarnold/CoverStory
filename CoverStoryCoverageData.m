//
//  CoverStoryCoverageData.m
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

#import "CoverStoryCoverageData.h"


@implementation CoverStoryCoverageData
+ (id)coverageDataWithLine:(NSString*)line hitCount:(UInt32)hitCount {
  return [[[self alloc] initWithLine:line hitCount:hitCount] autorelease];
}

- (id)initWithLine:(NSString*)line hitCount:(UInt32)hitCount {
  if ((self = [super init])) {
    hitCount_ = hitCount;
    line_ = [line copy];
  }
  return self;
}

- (void)dealloc {
  [line_ release];
  [super dealloc];
}

- (NSString*)line {
  return line_;
}

- (SInt32)hitCount {
  return hitCount_;
}

- (NSString*)description {
  return [NSString stringWithFormat:@"%d %@", hitCount_, line_];
}

- (id)copyWithZone:(NSZone *)zone {
  return [[[self class] alloc] initWithLine:line_ hitCount:hitCount_];
}

@end
