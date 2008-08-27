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

// helper for building the string to make sure rounding doesn't get us
static float codeCoverage(NSInteger codeLines, NSInteger hitCodeLines,
                          NSString **outCoverageString) {
  float coverage = 0.0;
  if (codeLines > 0) {
    coverage = (float)hitCodeLines/(float)codeLines * 100.0f;
  }
  if (outCoverageString) {
    *outCoverageString = [NSString stringWithFormat:@"%.1f", coverage];
    // make sure we never round to 100% if it's not 100%
    if ([*outCoverageString isEqual:@"100.0"]) {
      if (hitCodeLines == codeLines) {
        *outCoverageString = @"100";
      } else {
        *outCoverageString = @"99.9";
      }
    }
  }
  return coverage;
}

@implementation NSEnumerator (CodeCoverage)
- (void)coverageTotalLines:(NSInteger *)outTotal
                 codeLines:(NSInteger *)outCode
              hitCodeLines:(NSInteger *)outHitCode
          nonFeasibleLines:(NSInteger *)outNonFeasible
            coverageString:(NSString **)outCoverageString
                  coverage:(float *)outCoverage {
  // collect the data
  NSInteger sumTotal = 0;
  NSInteger sumCode = 0;
  NSInteger sumHitCode = 0;
  NSInteger sumNonFeasible = 0;
  id<CoverStoryLineCoverageProtocol> data;
  while ((data = [self nextObject])) {
    NSInteger localTotal = 0;
    NSInteger localCode = 0;
    NSInteger localHitCode = 0;
    NSInteger localNonFeasible = 0;
    [data coverageTotalLines:&localTotal
                   codeLines:&localCode
                hitCodeLines:&localHitCode
            nonFeasibleLines:&localNonFeasible
              coverageString:NULL
                    coverage:NULL];
    sumTotal += localTotal;
    sumCode += localCode;
    sumHitCode += localHitCode;
    sumNonFeasible += localNonFeasible;
  }

  if (outTotal) {
    *outTotal = sumTotal;
  }
  if (outCode) {
    *outCode = sumCode;
  }
  if (outHitCode) {
    *outHitCode = sumHitCode;
  }
  if (outNonFeasible) {
    *outNonFeasible = sumNonFeasible;
  }
  if (outCoverageString || outCoverage) {
    float coverage = codeCoverage(sumCode, sumHitCode, outCoverageString);
    if (outCoverage) {
      *outCoverage = coverage;
    }
  }
}
@end

@interface CoverStoryCoverageFileData (PrivateMethods)
- (void)updateCounts;
- (BOOL)calculateComplexityWithMessageReceiver:(id<CoverStoryCoverageProcessingProtocol>)receiver;
- (NSString*)generateSource;
- (BOOL)scanMccLineFromScanner:(NSScanner*)scanner
                         start:(NSInteger*)start
                           end:(NSInteger*)end
                    complexity:(NSInteger*)complexity;
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
      // is in MacRoman easily causes us errors w/o this extra code.
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
      GTMRegex *nfLineRegex = [GTMRegex regexWithPattern:@"//[[:blank:]]*COV_NF_LINE"];
      GTMRegex *nfRangeStartRegex = [GTMRegex regexWithPattern:@"//[[:blank:]]*COV_NF_START"];
      GTMRegex *nfRangeEndRegex  = [GTMRegex regexWithPattern:@"//[[:blank:]]*COV_NF_END"];
      BOOL inNonFeasibleRange = NO;
      NSScanner *scanner = [NSScanner scannerWithString:string];
      [scanner setCharactersToBeSkipped:nil];
      while (![scanner isAtEnd]) {
        NSString *segment;
        // scan in hit count
        BOOL goodScan = [scanner scanUpToString:@":" intoString:&segment];
        [scanner setScanLocation:[scanner scanLocation] + 1];
        NSInteger hitCount = 0;
        if (goodScan) {
          hitCount = [segment intValue];
          if (hitCount == 0) {
            if ([segment characterAtIndex:[segment length] - 1] != '#') {
              hitCount = kCoverStoryNotExecutedMarker;
            }
          }
        }
        // scan in line number
        goodScan = [scanner scanUpToString:@":" intoString:&segment];
        [scanner setScanLocation:[scanner scanLocation] + 1];
        // scan in the code line
        goodScan = [scanner scanUpToCharactersFromSet:linefeeds
                                           intoString:&segment];
        if (!goodScan) {
          segment = @"";
        }
        // skip over the end of line marker (CR, LF, CRLF), and it's possible
        // on the end of the file that there is none of them.
        [scanner scanCharactersFromSet:linefeeds intoString:NULL];
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
          if ([nfRangeEndRegex matchesSubStringInString:segment]) {
            inNonFeasibleRange = NO;
          }
        } else {
          // if it matches the line marker, don't count it
          if ([nfLineRegex matchesSubStringInString:segment]) {
            hitCount = kCoverStoryNonFeasibleMarker;
          }
          // if it matches the start marker, don't count it and set state
          else if ([nfRangeStartRegex matchesSubStringInString:segment]) {
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
        // The first line contains the path to our source.  Most projects use
        // paths relative to the project, so just incase they walk into a
        // neighbor directory, resolve them.
        NSString *srcPath = [[[lines_ objectAtIndex:0] line] substringFromIndex:7];
        sourcePath_ = [[srcPath stringByStandardizingPath] retain];
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
                         start:(NSInteger*)start
                           end:(NSInteger*)end
                    complexity:(NSInteger*)complexity {
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

- (NSString *)sourcePath {
  return sourcePath_;
}

- (NSNumber *)coverage {
  float result = 0.0f;
  [self coverageTotalLines:NULL
                 codeLines:NULL
              hitCodeLines:NULL
          nonFeasibleLines:NULL
            coverageString:NULL
                  coverage:&result];
  return [NSNumber numberWithFloat:result];
}

- (void)coverageTotalLines:(NSInteger *)outTotal
                 codeLines:(NSInteger *)outCode
              hitCodeLines:(NSInteger *)outHitCode
          nonFeasibleLines:(NSInteger *)outNonFeasible
            coverageString:(NSString **)outCoverageString
                  coverage:(float *)outCoverage {
  if (outTotal) {
    *outTotal = [lines_ count];
  }
  if (outCode) {
    *outCode = codeLines_;
  }
  if (outHitCode) {
    *outHitCode = hitLines_;
  }
  if (outNonFeasible) {
    *outNonFeasible = nonfeasible_;
  }
  if (outCoverageString || outCoverage) {
    float coverage = codeCoverage(codeLines_, hitLines_, outCoverageString);
    if (outCoverage) {
      *outCoverage = coverage;
    }
  }
}

- (NSInteger)maxComplexity {
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
  NSArray *newLines = [fileData lines];
  if ([newLines count] != [lines_ count]) {
    if (receiver) {
      [receiver coverageErrorForPath:sourcePath_
                             message:@"coverage source (%@) has different line count '%d' vs '%d'",
       [fileData sourcePath], [newLines count], [lines_ count]];
    }
    return NO;
  }
  for (NSUInteger x = 0, max = [newLines count] ; x < max ; ++x ) {
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
  for (NSUInteger x = 0, max = [newLines count] ; x < max ; ++x ) {
    CoverStoryCoverageLineData *lineNew = [newLines objectAtIndex:x];
    CoverStoryCoverageLineData *lineMe = [lines_ objectAtIndex:x];
    [lineMe addHits:[lineNew hitCount]];
  }

  // then add the number
  [self updateCounts];
  return YES;
}

- (void *)userData {
  return userData_;
}

- (void)setUserData:(void *)userData {
  userData_ = userData;
}

- (NSString *)description {
  return [NSString stringWithFormat:
            @"%@: %d total lines, %d lines non-feasible, %d lines of code, %d lines hit",
            sourcePath_, [lines_ count], nonfeasible_, codeLines_, hitLines_];
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

- (CoverStoryCoverageFileData *)fileDataForSourcePath:(NSString *)path {
  return [fileDatas_ objectForKey:path];
}

- (void)coverageTotalLines:(NSInteger *)outTotal
                 codeLines:(NSInteger *)outCode
              hitCodeLines:(NSInteger *)outHitCode
          nonFeasibleLines:(NSInteger *)outNonFeasible
            coverageString:(NSString **)outCoverageString
                  coverage:(float *)outCoverage {
  // use the enum helper
  NSEnumerator *enumerator = [fileDatas_ objectEnumerator];
  [enumerator coverageTotalLines:outTotal
                       codeLines:outCode
                    hitCodeLines:outHitCode
                nonFeasibleLines:outNonFeasible
                  coverageString:outCoverageString
                        coverage:outCoverage];
}

- (void *)userData {
  return userData_;
}

- (void)setUserData:(void *)userData {
  userData_ = userData;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"%@ <%p>: %u items in set",
          [self class], self, [fileDatas_ count]];
}

@end


@implementation CoverStoryCoverageLineData

+ (id)coverageLineDataWithLine:(NSString*)line hitCount:(NSInteger)hitCount {
  return [[[self alloc] initWithLine:line hitCount:hitCount] autorelease];
}

- (id)initWithLine:(NSString*)line hitCount:(NSInteger)hitCount {
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

- (NSInteger)hitCount {
  return hitCount_;
}

- (void)setComplexity:(NSInteger)complexity {
  complexity_ = complexity;
}

- (NSInteger)complexity {
  return complexity_;
}

- (void)addHits:(NSInteger)newHits {
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

@end
