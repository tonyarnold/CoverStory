//
//  CoverStoryCoverageData.m
//  CoverStory
//
//  Created by dmaclach on 12/24/06.
//  Copyright 2006-2009 Google Inc.
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


@interface CoverStoryCoverageFileData (PrivateMethods)
- (void)updateCounts;
@end

@implementation CoverStoryCoverageFileData

+ (id)coverageFileDataFromData:(NSData *)data {
  return [[[self alloc] initWithData:data] autorelease];
}
  
- (id)initWithData:(NSData *)data {
  self = [super init];
  if (self != nil) {
    lines_ = [[NSMutableArray alloc] init];
    
    // Scan in our data and create up out CoverStoryCoverageLineData objects.
    // TODO(dmaclach): make this routine a little more "error tolerant"

    // Most Mac source is UTF8 or Western(MacRoman), so we'll try those and then
    // punt.
    NSString *string = [[[NSString alloc] initWithData:data 
                                              encoding:NSUTF8StringEncoding] autorelease];
    if (string == nil) {
      string = [[[NSString alloc] initWithData:data 
                                      encoding:NSMacOSRomanStringEncoding] autorelease];    }
    if (string == nil) {
      NSLog(@"failed to process data as UTF8 or MacOSRoman, currently don't try other encodings");
      [self release];
      self = nil;
    } else {
      
      NSCharacterSet *linefeeds = [NSCharacterSet characterSetWithCharactersInString:@"\n\r"];
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
              hitCount = -1;
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
      } else {
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
  NSEnumerator *dataEnum = [lines_ objectEnumerator];
  CoverStoryCoverageLineData* dataPoint;
  while ((dataPoint = [dataEnum nextObject]) != nil) {
    int hitCount = [dataPoint hitCount];
    switch (hitCount) {
      case -1:
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

- (float)coverage {
  float result = (float)hitLines_/(float)codeLines_ * 100.0f;
  return result;
}

- (BOOL)addFileData:(CoverStoryCoverageFileData *)fileData {
  // must be for the same paths
  if (![[fileData sourcePath] isEqual:sourcePath_])
    return NO;

  // make sure the source file lines actually match
  if ([fileData numberTotalLines] != [self numberTotalLines])
    return NO;
  NSArray *newLines = [fileData lines];
  for (int x = 0, max = [newLines count] ; x < max ; ++x ) {
    CoverStoryCoverageLineData *lineNew = [newLines objectAtIndex:x];
    CoverStoryCoverageLineData *lineMe = [lines_ objectAtIndex:x];

    // string match, if either says -1, they both have to say -1
    if (![[lineNew line] isEqual:[lineMe line]]) {
      NSLog(@"failed to merge lines, code doesn't match, index %d - '%@' vs '%@'",
            x, [lineNew line], [lineMe line]);
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
            @"%@: %d total lines, %d lines of code, %d lines hit",
            sourcePath_, [self numberTotalLines], [self numberCodeLines],
            [self numberHitCodeLines]];
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

- (BOOL)addFileData:(CoverStoryCoverageFileData *)fileData {
  CoverStoryCoverageFileData *currentData =
    [fileDatas_ objectForKey:[fileData sourcePath]];
  if (currentData) {
    // we need to merge them
    // (this is needed for headers w/ inlines where if you process >1 gcno/gcda
    // then you could get that header reported >1 time)
    return [currentData addFileData:fileData];
  }
  
  [fileDatas_ setObject:fileData forKey:[fileData sourcePath]];
  return YES;
}

- (NSArray *)sourcePaths {
  return [fileDatas_ allKeys];
}

- (CoverStoryCoverageFileData *)fileDataForSourcePath:(NSString *)path {
  return [fileDatas_ objectForKey:path];
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

- (void)addHits:(SInt32)newHits {
  // we could be processing big and little endian runs, and w/ ifdefs one set of
  // lines would be ignored in one run, but not in the other. so...  if we were
  // a not hit line, we just take the new hits, otherwise we add any real hits
  // to our count.
  if (hitCount_ == -1) {
    hitCount_ = newHits;
  } else if (newHits > 0) {
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
