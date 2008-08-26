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
#import "GTMDefines.h"

enum {
  // Value for hitCount for lines that aren't executed
  kCoverStoryNotExecutedMarker = -1,
  // Value for hitCount for lines that are non-feasible
  kCoverStoryNonFeasibleMarker = -2
};

@protocol CoverStoryLineCoverageProtocol
- (void)coverageTotalLines:(NSInteger *)outTotal
                 codeLines:(NSInteger *)outCode // doesn't include non-feasible
              hitCodeLines:(NSInteger *)outHitCode
          nonFeasibleLines:(NSInteger *)outNonFeasible
            coverageString:(NSString **)outCoverageString
                  coverage:(float *)outCoverage; // use the string for display,
                                                 // this is just here for calcs
                                                 // and sorts
@end

@interface NSEnumerator (CodeCoverage)
- (void)coverageTotalLines:(NSInteger *)outTotal
                 codeLines:(NSInteger *)outCode
              hitCodeLines:(NSInteger *)outHitCode
          nonFeasibleLines:(NSInteger *)outNonFeasible
            coverageString:(NSString **)outCoverageString
                  coverage:(float *)outCoverage; // use the string for display,
                                                 // this is just here for calcs
                                                 // and sorts
@end

// methods to get feedback while the data is processed
@protocol CoverStoryCoverageProcessingProtocol
- (void)coverageErrorForPath:(NSString*)path message:(NSString *)format, ...;
@end

// Keeps track of the data for a whole source file.

@interface CoverStoryCoverageFileData : NSObject<CoverStoryLineCoverageProtocol> {
 @private
  NSMutableArray *lines_; // of CoverStoryCoverageLineData
  NSInteger hitLines_;
  NSInteger codeLines_;
  NSInteger nonfeasible_;
  NSInteger maxComplexity_;
  NSString *sourcePath_;
}

+ (id)coverageFileDataFromPath:(NSString *)path
               messageReceiver:(id<CoverStoryCoverageProcessingProtocol>)receiver;
- (id)initWithPath:(NSString *)path
   messageReceiver:(id<CoverStoryCoverageProcessingProtocol> )receiver;
- (NSArray *)lines;
- (NSInteger)maxComplexity;
- (NSNumber *)coverage; // this is only vended for the table to sort with
- (NSString *)sourcePath;
- (BOOL)addFileData:(CoverStoryCoverageFileData *)fileData
    messageReceiver:(id<CoverStoryCoverageProcessingProtocol>)receiver;
@end


// Keeps track of a set of source files.

@interface CoverStoryCoverageSet : NSObject<CoverStoryLineCoverageProtocol> {
@private
  NSMutableDictionary *fileDatas_;
}
- (BOOL)addFileData:(CoverStoryCoverageFileData *)fileData
    messageReceiver:(id<CoverStoryCoverageProcessingProtocol>)receiver;
- (NSArray *)fileDatas;
- (CoverStoryCoverageFileData *)fileDataForSourcePath:(NSString *)path;
@end
                    
                     
// Keeps track of the number of times a line of code has been hit. There is
// one CoverStoryCoverageLineData object per line of code in the file. 

@interface CoverStoryCoverageLineData : NSObject {
 @private
  NSInteger hitCount_;  // how many times this line has been hit
  NSInteger complexity_;
  NSString *line_;  //  the line
}

+ (id)coverageLineDataWithLine:(NSString*)line hitCount:(NSInteger)hitCount;
- (id)initWithLine:(NSString*)line hitCount:(NSInteger)hitCount;
- (NSString*)line;
- (NSInteger)hitCount;
- (void)addHits:(NSInteger)newHits;
- (void)setComplexity:(NSInteger)complexity;
- (NSInteger)complexity;
@end
