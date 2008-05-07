//
//  CoverStoryCoverageData.m
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

#import "CoverStoryCoverageData.h"
#import "GTMRegex.h"

// this will return something we need to free
char *mcc(const char* untf8String);

@interface CoverStoryCoverageFileData (PrivateMethods)
- (void)updateCounts;
- (BOOL)calculateComplexityWithMessageReceiver:(id<CoverStoryCoverageProcessingProtocol>)receiver;
- (NSString*)generateSource;
- (BOOL)scanMccLineFromScanner:(NSScanner*)scanner
                         start:(int*)start 
                           end:(int*)end 
                    complexity:(int*)complexity;
@end

@implementation CoverStoryCoverageFileData

+ (id)coverageFileDataFromPath:(NSString *)path
               messageReceiver:(id<CoverStoryCoverageProcessingProtocol>)receiver {
  return [[[self alloc] initWithPath:path
                     messageReceiver:receiver] autorelease];
}
  
- (id)initWithPath:(NSString *)path
   messageReceiver:(id<CoverStoryCoverageProcessingProtocol>)receiver {
  if ((self = [super init])) {
    lines_ = [[NSMutableArray alloc] init];
    
    // Scan in our data and create up out CoverStoryCoverageLineData objects.
    // TODO(dmaclach): make this routine a little more "error tolerant"

    // Let NSString try to handle the encoding when opening
    NSStringEncoding encoding;
    NSError *error;
    NSString *string = [NSString stringWithContentsOfFile:path
                                             usedEncoding:&encoding
                                                    error:&error];
    if (!string) {
      // Sadly, NSString doesn't detect/handle NSMacOSRomanStringEncoding very
      // well, so we have to manually try Roman.  math.h in the system headers
      // is in MacRoman easily causes us error w/o this extra code.
      // (we don't care about the error here, we'll just report the parent
      // error)
      string = [NSString stringWithContentsOfFile:path
                                         encoding:NSMacOSRomanStringEncoding
                                            error:NULL];
    }
    if (!string) {
      [receiver coverageErrorForPath:path message:@"failed to open file %@", error];
      [self release];
      self = nil;
    } else {
      NSCharacterSet *linefeeds = [NSCharacterSet characterSetWithCharactersInString:@"\n\r"];
      GTMRegex *nfLineRegex = [GTMRegex regexWithPattern:@".*//[[:blank:]]*COV_NF_LINE.*"];
      GTMRegex *nfRangeStartRegex = [GTMRegex regexWithPattern:@".*//[[:blank:]]*COV_NF_START.*"];
      GTMRegex *nfRangeEndRegex  = [GTMRegex regexWithPattern:@".*//[[:blank:]]*COV_NF_END.*"];
      BOOL inNonFeasibleRange = NO;
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
              hitCount = kCoverStoryNotExecutedMarker;
            }
          }
        }
        goodScan = [scanner scanUpToString:@":" intoString:&segment];
        [scanner setScanLocation:[scanner scanLocation] + 1];
        goodScan = [scanner scanUpToCharactersFromSet:linefeeds
                                           intoString:&segment];
        if (!goodScan) {
          segment = @"";
        }
        [scanner setScanLocation:[scanner scanLocation] + 1];
        // handle the non feasible markers
        if (inNonFeasibleRange) {
          // if the line was gonna count, mark it as non feasible (we only mark
          // the lines that would have counted so the total number of non
          // feasible lines isn't too high (otherwise comment lines, blank
          // lines, etc. count as non feasible).
          if (hitCount != kCoverStoryNotExecutedMarker) {
            hitCount = kCoverStoryNonFeasibleMarker;
          }
          // if it has the end marker, clear our state
          if ([nfRangeEndRegex matchesString:segment]) {
            inNonFeasibleRange = NO;
          }
        } else {
          // if it matches the line marker, don't count it
          if ([nfLineRegex matchesString:segment]) {
            hitCount = kCoverStoryNonFeasibleMarker;
          }
          // if it matches the start marker, don't count it and set state
          else if ([nfRangeStartRegex matchesString:segment]) {
            // if the line was gonna count, mark it as non feasible (we only mark
            // the lines that would have counted so the total number of non
            // feasible lines isn't too high (otherwise comment lines, blank
            // lines, etc. count as non feasible).
            if (hitCount != kCoverStoryNotExecutedMarker) {
              hitCount = kCoverStoryNonFeasibleMarker;
            }
            inNonFeasibleRange = YES;
          }
        }
        [lines_ addObject:[CoverStoryCoverageLineData coverageLineDataWithLine:segment 
                                                                      hitCount:hitCount]];
      }
      
      // The first five lines are not data we want to show to the user
      if ([lines_ count] > 5) {
        // The first line contains the path to our source.
        sourcePath_ = [[[[lines_ objectAtIndex:0] line] substringFromIndex:7] retain];
        [lines_ removeObjectsInRange:NSMakeRange(0,5)];
        // get out counts
        [self updateCounts];
        [self calculateComplexityWithMessageReceiver:receiver];
      } else {
        [receiver coverageErrorForPath:path message:@"illegal file format"];

        // something bad
        [self release];
        self = nil;
      }
    }
  }
  
  return self;
}

- (void)dealloc {
  [lines_ release];
  [sourcePath_ release];

  [super dealloc];
}

- (void)updateCounts {
  hitLines_ = 0;
  codeLines_ = 0;
  nonfeasible_ = 0;
  NSEnumerator *dataEnum = [lines_ objectEnumerator];
  CoverStoryCoverageLineData* dataPoint;
  while ((dataPoint = [dataEnum nextObject]) != nil) {
    int hitCount = [dataPoint hitCount];
    switch (hitCount) {
      case kCoverStoryNonFeasibleMarker:
        ++nonfeasible_;
        break;
      case kCoverStoryNotExecutedMarker:
        // doesn't count;
        break;
      case 0:
        // line of code that wasn't hit
        ++codeLines_;
        break;
      default:
        // line of code w/ hits
        ++hitLines_;
        ++codeLines_;
        break;
    }
  }
}

- (NSString*)generateSource {
  NSMutableString *source = [NSMutableString string];
  NSEnumerator *dataEnum = [lines_ objectEnumerator];
  CoverStoryCoverageLineData* dataPoint;
  while ((dataPoint = [dataEnum nextObject]) != nil) {
    [source appendFormat:@"%@\n", [dataPoint line]];
  }
  return source;
}  
  
- (BOOL)scanMccLineFromScanner:(NSScanner*)scanner
                         start:(int*)start 
                           end:(int*)end 
                    complexity:(int*)complexity {
  if (!start || !end || !complexity || !scanner) return NO;
  if (![scanner scanString:@"Line:" intoString:NULL]) return NO;
  if (![scanner scanInt:start]) return NO;
  if (![scanner scanString:@"To:" intoString:NULL]) return NO;
  if (![scanner scanInt:end]) return NO;
  if (![scanner scanString:@"Complexity:" intoString:NULL]) return NO;
  if (![scanner scanInt:complexity]) return NO;
  // Risk
  if (![scanner scanUpToString:@"Line:" intoString:NULL]) return NO;
  return YES;
}
  
- (BOOL)calculateComplexityWithMessageReceiver:(id<CoverStoryCoverageProcessingProtocol>)receiver {
  maxComplexity_ = 0;
  NSString *source = [self generateSource];
  NSString *val = nil;
  
  char *mccOutput = mcc([source UTF8String]);
  if (mccOutput) {
    val = [[[NSString alloc] initWithBytesNoCopy:mccOutput
                                          length:strlen(mccOutput)
                                        encoding:NSUTF8StringEncoding
                                    freeWhenDone:YES] autorelease];
  }
    
  if (!val) {
    [receiver coverageErrorForPath:[self sourcePath] 
                           message:@"Code complexity analysis failed"];
    return NO;
  }
  NSScanner *complexityScanner = [NSScanner scannerWithString:val];
  int lastEndLine = 0;
  while (![complexityScanner isAtEnd]) {
    int startLine;
    int endLine;
    int complexity;
    if ([self scanMccLineFromScanner:complexityScanner
                               start:&startLine
                                 end:&endLine
                          complexity:&complexity]) {
      if (complexity > maxComplexity_) {
        maxComplexity_ = complexity;
      }
      [[lines_ objectAtIndex:(startLine - 1)] setComplexity:complexity];
      lastEndLine = endLine;
    } else {
      [receiver coverageErrorForPath:[self sourcePath] 
                             message:@"Code complexity analysis unable to parse "
                                      "file somewhere after line %d", lastEndLine];
      return NO;
    }
  }
  return YES;
}

- (NSArray *)lines {
  return lines_;
}

- (void)setLines:(NSArray *)lines {
  [lines_ autorelease];
  lines_ = [lines mutableCopy];
}

- (NSString *)sourcePath {
  return sourcePath_;
}

- (void)setSourcePath:(NSString *)sourcePath {
  [sourcePath_ autorelease];
  sourcePath_ = [sourcePath copy];
}

- (SInt32)numberTotalLines {
  return [lines_ count];
}

- (SInt32)numberCodeLines {
  return codeLines_;
}

- (SInt32)numberHitCodeLines {
  return hitLines_;
}

- (SInt32)numberNonFeasibleLines {
  return nonfeasible_;
}

- (NSNumber *)coverage {
  float result = 0.0;
  if (codeLines_ > 0.0) {
    result = (float)hitLines_/(float)codeLines_ * 100.0f;
  }
  return [NSNumber numberWithFloat:result];
}

- (int)maxComplexity {
  return maxComplexity_;
}

- (BOOL)addFileData:(CoverStoryCoverageFileData *)fileData
    messageReceiver:(id<CoverStoryCoverageProcessingProtocol>)receiver {
  // must be for the same paths
  if (![[fileData sourcePath] isEqual:sourcePath_]) {
    if (receiver) {
      [receiver coverageErrorForPath:sourcePath_ 
                             message:@"coverage is for different source path:%@", 
       [fileData sourcePath]];
    }
    return NO;
  }

  // make sure the source file lines actually match
  if ([fileData numberTotalLines] != [self numberTotalLines]) {
    if (receiver) {
      [receiver coverageErrorForPath:sourcePath_ 
                             message:@"coverage source (%@) has different line count '%d' vs '%d'",
       [fileData sourcePath], [fileData numberTotalLines], [self numberTotalLines]];
    }
    return NO;
  }
  NSArray *newLines = [fileData lines];
  for (int x = 0, max = [newLines count] ; x < max ; ++x ) {
    CoverStoryCoverageLineData *lineNew = [newLines objectAtIndex:x];
    CoverStoryCoverageLineData *lineMe = [lines_ objectAtIndex:x];

    // string match, if either says kCoverStoryNotExecutedMarker, 
    // they both have to say kCoverStoryNotExecutedMarker
    if (![[lineNew line] isEqual:[lineMe line]]) {
      if (receiver) {
        [receiver coverageErrorForPath:sourcePath_
                               message:@"coverage source (%@) line %d doesn't match, '%@' vs '%@'",
         [fileData sourcePath], x, [lineNew line], [lineMe line]];
      }
      return NO;
    }
    // we don't check if the lines weren't hit between the two because we could
    // be processing big and little endian runs, and w/ ifdefs one set of lines
    // would be ignored in one run, but not in the other.
  }
  
  // spin though once more summing the counts
  for (int x = 0, max = [newLines count] ; x < max ; ++x ) {
    CoverStoryCoverageLineData *lineNew = [newLines objectAtIndex:x];
    CoverStoryCoverageLineData *lineMe = [lines_ objectAtIndex:x];
    [lineMe addHits:[lineNew hitCount]];
  }
    
  // then add the number
  [self updateCounts];
  return YES;
}

- (NSString *)description {
  return [NSString stringWithFormat:
            @"%@: %d total lines, %d lines non-feasible, %d lines of code, %d lines hit",
            sourcePath_, [self numberTotalLines], [self numberNonFeasibleLines],
            [self numberCodeLines], [self numberHitCodeLines]];
}

- (id)copyWithZone:(NSZone *)zone {
  id newCopy = [[[self class] allocWithZone:zone] init];
  [newCopy setLines:lines_];
  [newCopy setSourcePath:sourcePath_];
  [newCopy updateCounts];
  return newCopy;
}

@end

@implementation CoverStoryCoverageSet

- (id)init {
  self = [super init];
  if (self != nil) {
    fileDatas_ = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)dealloc {
  [fileDatas_ release];
  
  [super dealloc];
}

- (BOOL)addFileData:(CoverStoryCoverageFileData *)fileData
    messageReceiver:(id<CoverStoryCoverageProcessingProtocol>)receiver {
  CoverStoryCoverageFileData *currentData =
    [fileDatas_ objectForKey:[fileData sourcePath]];
  if (currentData) {
    // we need to merge them
    // (this is needed for headers w/ inlines where if you process >1 gcno/gcda
    // then you could get that header reported >1 time)
    return [currentData addFileData:fileData messageReceiver:receiver];
  }
  
  [fileDatas_ setObject:fileData forKey:[fileData sourcePath]];
  return YES;
}

- (NSArray *)fileDatas {
  return [fileDatas_ allValues];
}

- (NSArray *)sourcePaths {
  return [fileDatas_ allKeys];
}

- (CoverStoryCoverageFileData *)fileDataForSourcePath:(NSString *)path {
  return [fileDatas_ objectForKey:path];
}

- (SInt32)numberTotalLines {
  SInt32 total = 0;
  NSEnumerator *enumerator = [fileDatas_ objectEnumerator];
  CoverStoryCoverageFileData *fileData = nil;
  while ((fileData = [enumerator nextObject]) != nil) {
    total += [fileData numberTotalLines];
  }
  return total;
}

- (SInt32)numberCodeLines {
  SInt32 total = 0;
  NSEnumerator *enumerator = [fileDatas_ objectEnumerator];
  CoverStoryCoverageFileData *fileData = nil;
  while ((fileData = [enumerator nextObject]) != nil) {
    total += [fileData numberCodeLines];
  }
  return total;
}

- (SInt32)numberHitCodeLines {
  SInt32 total = 0;
  NSEnumerator *enumerator = [fileDatas_ objectEnumerator];
  CoverStoryCoverageFileData *fileData = nil;
  while ((fileData = [enumerator nextObject]) != nil) {
    total += [fileData numberHitCodeLines];
  }
  return total;
}

- (SInt32)numberNonFeasibleLines {
  SInt32 total = 0;
  NSEnumerator *enumerator = [fileDatas_ objectEnumerator];
  CoverStoryCoverageFileData *fileData = nil;
  while ((fileData = [enumerator nextObject]) != nil) {
    total += [fileData numberNonFeasibleLines];
  }
  return total;
}

- (NSNumber *)coverage {
  float numberCodeLines = [self numberCodeLines];
  float result = 0.0f;
  if (numberCodeLines > 0.0) {
    result = (float)[self numberHitCodeLines]/numberCodeLines * 100.0f;
  }
  return [NSNumber numberWithFloat:result];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"%@ <%p>: %u items in set",
          [self class], self, [fileDatas_ count]];
}

@end


@implementation CoverStoryCoverageLineData

+ (id)coverageLineDataWithLine:(NSString*)line hitCount:(UInt32)hitCount {
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

- (void)setComplexity:(SInt32)complexity {
  complexity_ = complexity;
}

- (SInt32)complexity {
  return complexity_;
}

- (void)addHits:(SInt32)newHits {
  // we could be processing big and little endian runs, and w/ ifdefs one set of
  // lines would be ignored in one run, but not in the other. so...  if we were
  // a not hit line, we just take the new hits, otherwise we add any real hits
  // to our count.
  if (hitCount_ == kCoverStoryNotExecutedMarker) {
    NSAssert1((newHits == kCoverStoryNotExecutedMarker) || (newHits >= 0),
              @"how was it not feasible in only one version? (newHits = %d)",
              newHits);
    hitCount_ = newHits;
  } else if (newHits > 0) {
    NSAssert1(hitCount_ >= 0,
              @"how was it not feasible in only one version? (hitCount_ = %d)",
              hitCount_);
    hitCount_ += newHits;
  }
}

- (NSString*)description {
  return [NSString stringWithFormat:@"%d %@", hitCount_, line_];
}

- (id)copyWithZone:(NSZone *)zone {
  return [[[self class] alloc] initWithLine:line_ hitCount:hitCount_];
}

@end
