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
#import "CoverStoryDocument.h"

// helper for building the string to make sure rounding doesn't get us
static float codeCoverage(NSInteger codeLines, NSInteger hitCodeLines,
                          NSString **outCoverageString) {
  float coverage = 0.0f;
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

@interface CoverStoryCoverageFileData ()
@property (readwrite, nonatomic, assign) NSInteger hitLines;
@property (readwrite, nonatomic, assign) NSInteger codeLines;
@property (readwrite, nonatomic, assign) NSInteger nonfeasible;

- (void)updateCounts;
- (NSArray *)queuedWarnings;
@end

@interface CoverStoryCoverageSet ()
@property (readonly, nonatomic, strong) NSMutableArray *fileDatas;
@end

@interface CoverStoryCoverageFileData ()
@property (readwrite, nonatomic, assign) CoverStoryDocument *document;
@property (readwrite, nonatomic, copy) NSString *sourcePath;
@property (readwrite, nonatomic, strong) NSArray *lines;
@end

@interface CoverStoryCoverageFileData (ScriptingMethods)
- (NSScriptObjectSpecifier *)objectSpecifierForLineData:(CoverStoryCoverageLineData*)data;
@end

@interface CoverStoryCoverageLineData ()
@property (readwrite, nonatomic, assign) NSInteger hitCount;
@end

@interface CoverStoryCoverageLineData (ScriptingMethods)
@end

@implementation CoverStoryCoverageFileData

@synthesize document = document_;
@synthesize sourcePath = sourcePath_;
@synthesize lines = lines_;
@synthesize hitLines = hitLines_;
@synthesize codeLines = codeLines_;
@synthesize nonfeasible = nonfeasible_;
@dynamic coverage;


+ (id)coverageFileDataFromPath:(NSString *)path
                      document:(CoverStoryDocument *)document
               messageReceiver:(id<CoverStoryCoverageProcessingProtocol>)receiver {
  return [[self alloc] initWithPath:path
                            document:document
                     messageReceiver:receiver];
}

- (id)initWithPath:(NSString *)path
          document:(CoverStoryDocument *)document
   messageReceiver:(id<CoverStoryCoverageProcessingProtocol>)receiver {
  if ((self = [super init])) {
    document_ = document;
    lines_ = [[NSMutableArray alloc] init];
    // The dirty secret: we queue up warnings and don't report them in realtime.
    // Why?  if we report them now, then if the directory with multiple arches
    // we'll send the warning for each arch, and if the file occures in more
    // then one set of gcda/gcno (say for headers w/ inlines), the we'll report
    // each time we read that header.  So instead we queue them, and don't
    // send them over to the receiver until it's added to a set, and only if
    // it's new, this way we're sure we only send them once.
    warnings_ = [[NSMutableArray alloc] init];

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
      self = nil;
    } else {
      NSCharacterSet *linefeeds = [NSCharacterSet characterSetWithCharactersInString:@"\n\r"];
        NSRegularExpression *nfLineRegex = [NSRegularExpression regularExpressionWithPattern:@"//[[:blank:]]*COV_NF_LINE" options:0 error:nil];
        NSRegularExpression *nfRangeStartRegex = [NSRegularExpression regularExpressionWithPattern:@"//[[:blank:]]*COV_NF_START" options:0 error:nil];
        NSRegularExpression *nfRangeEndRegex = [NSRegularExpression regularExpressionWithPattern:@"//[[:blank:]]*COV_NF_END" options:0 error:nil];
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
        if (goodScan) {
          [scanner setScanLocation:[scanner scanLocation] + 1];
          // scan in the code line
          goodScan = [scanner scanUpToCharactersFromSet:linefeeds
                                             intoString:&segment];
        }
        if (!goodScan) {
          segment = @"";
        }
        // skip over the end of line marker (CR, LF, CRLF), and it's possible
        // on the end of the file that there is none of them.
        [scanner scanCharactersFromSet:linefeeds intoString:NULL];
        // handle the non feasible markers
        if (inNonFeasibleRange) {
          if (hitCount > 0) {
            NSString *warning =
              [NSString stringWithFormat:@"Line %lu is in a Non Feasible block,"
                                          " but was executed.",
                                         (unsigned long)[lines_ count] - 4];
            [warnings_ addObject:warning];
          }
          // if the line was gonna count, mark it as non feasible (we only mark
          // the lines that would have counted so the total number of non
          // feasible lines isn't too high (otherwise comment lines, blank
          // lines, etc. count as non feasible).
          if (hitCount != kCoverStoryNotExecutedMarker) {
            hitCount = kCoverStoryNonFeasibleMarker;
          }
          // if it has the end marker, clear our state
          if ([nfRangeEndRegex numberOfMatchesInString:segment options:0 range:NSMakeRange(0, segment.length)] > 0) {
            inNonFeasibleRange = NO;
          }
        } else {
          // if it matches the line marker, don't count it
          if ([nfLineRegex numberOfMatchesInString:segment options:0 range:NSMakeRange(0, segment.length)] > 0) {
            if (hitCount > 0) {
              NSString *warning =
                [NSString stringWithFormat:@"Line %lu is marked as a Non"
                                            " Feasible line, but was executed.",
                                           (unsigned long)[lines_ count] - 4];
              [warnings_ addObject:warning];
            }
            hitCount = kCoverStoryNonFeasibleMarker;
          }
          // if it matches the start marker, don't count it and set state
          else if ([nfRangeStartRegex numberOfMatchesInString:segment options:0 range:NSMakeRange(0, segment.length)] > 0) {
            if (hitCount > 0) {
              NSString *warning =
                [NSString stringWithFormat:@"Line %lu is in a Non Feasible"
                                            " block, but was executed.",
                                           (unsigned long)[lines_ count] - 4];
              [warnings_ addObject:warning];
            }
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
        [lines_ addObject:[CoverStoryCoverageLineData coverageLineDataWithLine:segment hitCount:hitCount coverageFile:self]];
      }

      // The first five lines are not data we want to show to the user
      if ([lines_ count] > 5) {
        // The first line contains the path to our source.  Most projects use
        // paths relative to the project, so just incase they walk into a
        // neighbor directory, resolve them.
        NSString *srcPath = [[[lines_ objectAtIndex:0] line] substringFromIndex:7];
        sourcePath_ = [srcPath stringByStandardizingPath];
        [lines_ removeObjectsInRange:NSMakeRange(0,5)];
        // get out counts
        [self updateCounts];
      } else {
        [receiver coverageErrorForPath:path message:@"illegal file format"];

        // something bad
        self = nil;
      }
    }
  }

  return self;
}


- (id)copyWithZone:(NSZone *)zone {
  return self;
}

- (BOOL)isEqual:(id)object {
  BOOL equal = NO;
  if ([object isKindOfClass:[self class]]) {
    equal = [[object sourcePath] isEqual:[self sourcePath]];
  }
  return equal;
}

- (NSUInteger)hash {
  return [sourcePath_ hash];
}

- (void)updateCounts {
  NSInteger hitLines = 0;
  NSInteger codeLines = 0;
  NSInteger nonfeasible = 0;
  for (CoverStoryCoverageLineData *dataPoint in lines_) {
    NSInteger hitCount = [dataPoint hitCount];
    switch (hitCount) {
      case kCoverStoryNonFeasibleMarker:
        ++nonfeasible;
        break;
      case kCoverStoryNotExecutedMarker:
        // doesn't count;
        break;
      case 0:
        // line of code that wasn't hit
        ++codeLines;
        break;
      default:
        // line of code w/ hits
        ++hitLines;
        ++codeLines;
        break;
    }
  }
  [self setCodeLines:codeLines];
  [self setHitLines:hitLines];
  [self setNonfeasible:nonfeasible];
}

- (NSArray *)queuedWarnings {
  return warnings_;
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
    *outCode = [self codeLines];
  }
  if (outHitCode) {
    *outHitCode = [self hitLines];
  }
  if (outNonFeasible) {
    *outNonFeasible = [self nonfeasible];
  }
  if (outCoverageString || outCoverage) {
    float coverage = codeCoverage(codeLines_, hitLines_, outCoverageString);
    if (outCoverage) {
      *outCoverage = coverage;
    }
  }
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
                             message:@"coverage source (%@) has different line count '%lu' vs '%lu'",
                                     [fileData sourcePath],
                                     (unsigned long)[newLines count],
                                     (unsigned long)[lines_ count]];
    }
    return NO;
  }
  for (NSUInteger x = 0, max = [newLines count] ; x < max ; ++x ) {
    CoverStoryCoverageLineData *lineNew = [newLines objectAtIndex:x];
    CoverStoryCoverageLineData *lineMe = [lines_ objectAtIndex:x];

    // string match the lines (since the Non Feasible support is via comments,
    // this makes sure they also match)
    if (![[lineNew line] isEqual:[lineMe line]]) {
      if (receiver) {
        [receiver coverageErrorForPath:sourcePath_
                               message:@"coverage source (%@) line %lu doesn't match, '%@' vs '%@'",
         [fileData sourcePath], (unsigned long)x, [lineNew line], [lineMe line]];
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

- (NSString *)description {
  return [NSString stringWithFormat:
          @"%@: %lu total lines, %ld lines non-feasible, "
          @"%ld lines of code, %ld lines hit",
          sourcePath_, (unsigned long)[lines_ count],
          (long)nonfeasible_, (long)codeLines_, (long)hitLines_];
}


@end

@implementation CoverStoryCoverageSet

@synthesize fileDatas = fileDatas_;

- (id)init {
  if ((self = [super init])) {
    fileDatas_ = [[NSMutableArray alloc] init];
  }
  return self;
}


- (BOOL)addFileData:(CoverStoryCoverageFileData *)fileData
    messageReceiver:(id<CoverStoryCoverageProcessingProtocol>)receiver {
  BOOL wasGood = NO;
  NSUInteger idx = [fileDatas_ indexOfObject:fileData];
  if (idx != NSNotFound) {
    CoverStoryCoverageFileData *currentData = [fileDatas_ objectAtIndex:idx];
    // we need to merge them
    // (this is needed for headers w/ inlines where if you process >1 gcno/gcda
    // then you could get that header reported >1 time)
    wasGood = [currentData addFileData:fileData messageReceiver:receiver];
  } else {
    // it's new, save it
    NSUInteger index = [fileDatas_ count];
    [self willChange:NSKeyValueChangeInsertion
     valuesAtIndexes:[NSIndexSet indexSetWithIndex:index]
              forKey:@"fileDatas"];
    [fileDatas_ insertObject:fileData atIndex:index];
    [self didChange:NSKeyValueChangeInsertion
     valuesAtIndexes:[NSIndexSet indexSetWithIndex:index]
              forKey:@"fileDatas"];

    // send the queued up warnings since this is the first time we've seen the
    // file.
    // TODO: this is really a hack, we would be better (since these currently
    // are line specific) is to extend the structure to allow warnings to be
    // hung on the line data along w/ the hit counts.  Then w/in the UI indicate
    // how many warnings are on a file in the files list, and in the source
    // display show the warnings inline (sorta like Xcode 3).  The other option
    // would be to keep this basic structure, but be able to relay info w/ the
    // warning so our warning/error ui could take clicks and open to the right
    // file/line so the user can take action on the message.
    for (NSString *warning in [fileData queuedWarnings]) {
      [receiver coverageWarningForPath:[fileData sourcePath]
                               message:@"%@", warning];
    }
    wasGood = YES;
  }
  return wasGood;
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

- (void)removeAllData {
  NSRange fullRange = NSMakeRange(0, [fileDatas_ count]);
  NSIndexSet *fullSet = [NSIndexSet indexSetWithIndexesInRange:fullRange];
  [self willChange:NSKeyValueChangeRemoval
   valuesAtIndexes:fullSet
            forKey:@"fileDatas"];
  [fileDatas_ removeAllObjects];
  [self didChange:NSKeyValueChangeRemoval
   valuesAtIndexes:fullSet
            forKey:@"fileDatas"];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"%@ <%p>: %lu items in set",
          [self class], self, (unsigned long)[fileDatas_ count]];
}

@end


@implementation CoverStoryCoverageLineData

@synthesize hitCount = hitCount_;
@synthesize line = line_;
@synthesize coverageFile = coverageFile_;

+ (id)coverageLineDataWithLine:(NSString*)line
                      hitCount:(NSInteger)hitCount
                  coverageFile:(CoverStoryCoverageFileData *)coverageFile {
  return [[self alloc] initWithLine:line
                            hitCount:hitCount
                        coverageFile:coverageFile];
}

- (id)initWithLine:(NSString*)line
          hitCount:(NSInteger)hitCount
      coverageFile:(CoverStoryCoverageFileData *)coverageFile {
  if ((self = [super init])) {
    hitCount_ = hitCount;
    line_ = [line copy];
    coverageFile_ = coverageFile;
  }
  return self;
}


- (void)addHits:(NSInteger)newHits {
  // we could be processing big and little endian runs, and w/ ifdefs one set of
  // lines would be ignored in one run, but not in the other. so...  if we were
  // a not hit line, we just take the new hits, otherwise we add any real hits
  // to our count.
  if (self.hitCount == kCoverStoryNotExecutedMarker) {
    self.hitCount = newHits;
  } else if (newHits > 0) {
    NSAssert1(self.hitCount >= 0,
              @"how was it not feasible in only one version? (hitCount_ = %ld)",
              (long)hitCount_);
    self.hitCount += newHits;
  }
}

- (NSString*)description {
  return [NSString stringWithFormat:@"%ld %@", (long)self.hitCount, self.line];
}

@end

@implementation CoverStoryCoverageFileData (ScriptingMethods)
- (NSScriptObjectSpecifier *)objectSpecifier {
  NSScriptObjectSpecifier *containerSpec = [[self document] objectSpecifier];
  NSScriptClassDescription *containterClassDesc
    = [containerSpec keyClassDescription];
  NSString *name = [self sourcePath];
  return [[NSNameSpecifier alloc] initWithContainerClassDescription:containterClassDesc
                                                  containerSpecifier:containerSpec
                                                                 key:@"fileDatas"
                                                                name:name];
}

- (NSScriptObjectSpecifier *)objectSpecifierForLineData:(CoverStoryCoverageLineData*)data {
  NSScriptObjectSpecifier *containerSpec = [self objectSpecifier];
  NSScriptClassDescription *containterClassDesc
    = [containerSpec keyClassDescription];
  NSInteger index = [[self lines] indexOfObject:data];
  return [[NSIndexSpecifier alloc] initWithContainerClassDescription:containterClassDesc
                                                   containerSpecifier:containerSpec
                                                                  key:@"lines"
                                                                index:index];
}
@end

@implementation CoverStoryCoverageLineData (ScriptingMethods)
- (NSScriptObjectSpecifier *)objectSpecifier {
  return [[self coverageFile] objectSpecifierForLineData:self];
}

// For scripting, we don't want to return any negative hit counts
- (NSInteger)adjustedHitCount {
  NSInteger hitCount = [self hitCount];
  if (hitCount < 0) hitCount = 0;
  return hitCount;
}

- (NSString *)coverageType {
  NSInteger hitCount = [self hitCount];
  NSString *type = nil;
  switch (hitCount) {
    case 0:
      type = @"missed";
      break;
    case kCoverStoryNotExecutedMarker:
      type = @"non-executable";
      break;
    case kCoverStoryNonFeasibleMarker:
      type = @"non-feasible";
      break;
    default:
      type = @"executed";
      break;
  }
  return type;
}

@end
