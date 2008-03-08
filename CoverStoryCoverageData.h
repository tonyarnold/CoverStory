//
//  CoverStoryCoverageData.h
//  CoverStory
//
//  Created by dmaclach on 12/24/06.
//  Copyright 2006-2008 Google Inc.
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

// Keeps track of the data for a whole source file.

@interface CoverStoryCoverageFileData : NSObject<NSCopying> {
 @private
  NSMutableArray *lines_; // of CoverStoryCoverageLineData
  SInt32 hitLines_;
  SInt32 codeLines_;
  SInt32 nonfeasible_;
  NSString *sourcePath_;
}

+ (id)coverageFileDataFromData:(NSData *)data;
- (id)initWithData:(NSData *)data;
- (NSArray *)lines;
- (SInt32)numberTotalLines;
- (SInt32)numberCodeLines; // doesn't include non-feasible
- (SInt32)numberHitCodeLines;
- (SInt32)numberNonFeasibleLines;
- (float)coverage;
- (NSString *)sourcePath;
- (BOOL)addFileData:(CoverStoryCoverageFileData *)fileData;
@end


// Keeps track of a set of source files.

@interface CoverStoryCoverageSet : NSObject {
@private
  NSMutableDictionary *fileDatas_;
}
- (BOOL)addFileData:(CoverStoryCoverageFileData *)fileData;
- (NSArray *)sourcePaths;
- (CoverStoryCoverageFileData *)fileDataForSourcePath:(NSString *)path;
- (SInt32)numberTotalLines;
- (SInt32)numberCodeLines; // doesn't include non-feasible
- (SInt32)numberHitCodeLines;
- (SInt32)numberNonFeasibleLines;
- (float)coverage;
@end
                    
                     
// Keeps track of the number of times a line of code has been hit. There is
// one CoverStoryCoverageLineData object per line of code in the file. Note that
// a hitcount of -1 means that the line is not executed, and -2 means the source
// had non-feasible markers.

@interface CoverStoryCoverageLineData : NSObject<NSCopying> {
 @private
  SInt32 hitCount_;  // how many times this line has been hit
  NSString *line_;  //  the line
}

+ (id)coverageLineDataWithLine:(NSString*)line hitCount:(UInt32)hitCount;
- (id)initWithLine:(NSString*)line hitCount:(UInt32)hitCount;
- (NSString*)line;
- (SInt32)hitCount;
- (void)addHits:(SInt32)newHits;
@end
