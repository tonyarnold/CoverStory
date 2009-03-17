//
//  CoverStoryValueTransformers.m
//  CoverStory
//
//  Created by Dave MacLachlan on 2008/03/10.
//  Copyright 2008 Google Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CoverStoryCoverageData.h"
#import "CoverStoryPreferenceKeys.h"
#import "CoverStoryDocument.h"

// Transformer for changing Line Data to Hit Counts.
// Used for first column of source code table.
@interface CoverageLineDataToHitCountTransformer : NSValueTransformer
@end

@implementation CoverageLineDataToHitCountTransformer

+ (Class)transformedValueClass {
  return [NSAttributedString class];
}

+ (BOOL)allowsReverseTransformation {
  return NO;
}

- (id)transformedValue:(id)value {
  NSAssert([value isKindOfClass:[CoverStoryCoverageLineData class]], 
           @"Only handle CoverStoryCoverageLineData");
  CoverStoryCoverageLineData *data = (CoverStoryCoverageLineData*)value;
  // Draw the hitcount
  NSInteger count = [data hitCount];

  NSString *displayString = @"";
  NSDictionary *attributes = nil;
  if (count != kCoverStoryNotExecutedMarker) {
    NSMutableParagraphStyle *pStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
    [pStyle setAlignment:NSRightTextAlignment];
    [pStyle setMinimumLineHeight:13];
    NSColor *color = nil;
    
    if (count == 0) {
      color = [NSColor redColor];
    } else {
      color = [NSColor colorWithDeviceWhite:0.4 alpha:1.0];
    }
    
    attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                    pStyle, NSParagraphStyleAttributeName,
                    color, NSForegroundColorAttributeName, 
                    nil];
    
    if (count == kCoverStoryNonFeasibleMarker) {
      displayString = @"--"; // for non-feasible lines
    } else if (count < 999) {
      displayString = [NSString stringWithFormat:@"%d", count];
    } else {
      displayString = @"99+";
    }
  }
  return [[[NSAttributedString alloc] initWithString:displayString
                                          attributes:attributes] autorelease];
}

@end

// Transformer for changing Line Data to source lines.
// Used for second column of source code table.
@interface CoverageLineDataToSourceLineTransformer : NSValueTransformer
@end

@implementation CoverageLineDataToSourceLineTransformer

+ (void)initialize {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSDictionary *lineTransformerDefaults =
    [NSDictionary dictionaryWithObjectsAndKeys:
     [NSArchiver archivedDataWithRootObject:[NSColor redColor]], 
     kCoverStoryMissedLineColorKey,
     [NSArchiver archivedDataWithRootObject:[NSColor grayColor]],
     kCoverStoryUnexecutableLineColorKey,
     [NSArchiver archivedDataWithRootObject:[NSColor grayColor]],
     kCoverStoryNonFeasibleLineColorKey,
     [NSArchiver archivedDataWithRootObject:[NSColor blackColor]],
     kCoverStoryExecutedLineColorKey,
     nil];
  
  [defaults registerDefaults:lineTransformerDefaults];
}

+ (Class)transformedValueClass {
  return [NSAttributedString class];
}

+ (BOOL)allowsReverseTransformation {
  return NO;
}

- (NSColor *)defaultColorNamed:(NSString*)name {
  NSColor *color = nil;
  if (name) {
    NSUserDefaultsController *defaults
      = [NSUserDefaultsController sharedUserDefaultsController];
    id values = [defaults values];
    NSData *colorData = [values valueForKey:name];
    if (colorData) {
      color = (NSColor *)[NSUnarchiver unarchiveObjectWithData:colorData];
    }
  }
  return color;
}

- (id)transformedValue:(id)value {
  NSAssert([value isKindOfClass:[CoverStoryCoverageLineData class]], 
           @"Only handle CoverStoryCoverageLineData");
  CoverStoryCoverageLineData *data = (CoverStoryCoverageLineData*)value;
  NSString *line = [data line];
  NSInteger hitCount = [data hitCount];
  NSString *colorName = nil;
  if (hitCount == 0) {
    colorName = kCoverStoryMissedLineColorKey;
  } else if (hitCount == kCoverStoryNotExecutedMarker) {
    colorName = kCoverStoryUnexecutableLineColorKey;
  } else if (hitCount == kCoverStoryNonFeasibleMarker) {
    colorName = kCoverStoryNonFeasibleLineColorKey;
  }
  else {
    colorName = kCoverStoryExecutedLineColorKey;
  }
  NSColor *textColor = [self defaultColorNamed:colorName];
  NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                              textColor, NSForegroundColorAttributeName, 
                              nil];
  return [[[NSAttributedString alloc] initWithString:line
                                          attributes:attributes] autorelease];
}

@end

// Transformer for changing file data to source paths.
// Used for first column of files table.
@interface CoverageFileDataToSourcePathTransformer : NSValueTransformer
@end

@implementation CoverageFileDataToSourcePathTransformer

+ (Class)transformedValueClass {
  return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
  return NO;
}

- (id)transformedValue:(id)value {
  NSAssert([value isKindOfClass:[CoverStoryCoverageFileData class]], 
           @"Only handle CoverStoryCoverageFileData");
  CoverStoryCoverageFileData *data = (CoverStoryCoverageFileData *)value;
  NSString *sourcePath = [data sourcePath];
  CoverStoryDocument *owningDoc = [data userData];
  NSString *commonPrefix = nil;
  if (owningDoc) {
    commonPrefix = [owningDoc commonPathPrefix];
  }
  NSUInteger commonPrefixLength = [commonPrefix length];
  if (commonPrefixLength > 0) {
    return [sourcePath substringFromIndex:commonPrefixLength];
  }
  return [sourcePath stringByAbbreviatingWithTildeInPath];
}

@end

// Transformer for changing file data to percentage covered.
// Used for second column of files table.
@interface CoverageFileDataToCoveragePercentageTransformer : NSValueTransformer
@end

@implementation CoverageFileDataToCoveragePercentageTransformer

const float kBadCoverage = 25.0f;
const float kGoodCoverage = 75.0f;

+ (Class)transformedValueClass {
  return [NSAttributedString class];
}

+ (BOOL)allowsReverseTransformation {
  return NO;
}

- (id)transformedValue:(id)value {
  NSAssert([value isKindOfClass:[CoverStoryCoverageFileData class]], 
           @"Only handle CoverStoryCoverageFileData");
  CoverStoryCoverageFileData *data = (CoverStoryCoverageFileData *)value;
  float coverage = 0.0f;
  NSString *coverageString = nil;
  [data coverageTotalLines:NULL
                 codeLines:NULL
              hitCodeLines:NULL
          nonFeasibleLines:NULL
            coverageString:&coverageString
                  coverage:&coverage];
  float redHue = 0;
  float greenHue = 120.0f/360.0f;
  float hue = 0;
  float saturation = 1.0f;
  float brightness = 0.75f;
  if (coverage < kBadCoverage) {
    hue = redHue;
  } else if (coverage < kGoodCoverage) {
    hue = redHue + (greenHue * (coverage - kBadCoverage) / (kGoodCoverage - kBadCoverage));
  } else {
    hue = greenHue;
  }
  NSColor *textColor = [NSColor colorWithCalibratedHue:hue
                                            saturation:saturation
                                            brightness:brightness
                                                 alpha:1.0];
  NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                              textColor, NSForegroundColorAttributeName, 
                              nil];
  return [[[NSAttributedString alloc] initWithString:coverageString
                                          attributes:attributes] autorelease];
}

@end

// Transformer for changing line coverage to summaries.
// Used for top of code window summaries.
@interface FileLineCoverageToCoverageSummaryTransformer : NSValueTransformer
@end

@implementation FileLineCoverageToCoverageSummaryTransformer

+ (Class)transformedValueClass {
  return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
  return NO;
}

- (id)transformedValue:(id)value {
  NSAssert([value conformsToProtocol:@protocol(CoverStoryLineCoverageProtocol)], 
           @"Only handle CoverStoryLineCoverageProtocol");
  id<CoverStoryLineCoverageProtocol> data = (id<CoverStoryLineCoverageProtocol>)value;
  NSInteger totalLines = 0;
  NSInteger codeLines = 0;
  NSInteger hitLines = 0;
  NSInteger nonfeasible = 0;
  NSString *coverage = nil;
  [data coverageTotalLines:&totalLines
                 codeLines:&codeLines
              hitCodeLines:&hitLines
          nonFeasibleLines:&nonfeasible
            coverageString:&coverage
                  coverage:NULL];
  
  NSString *statString = nil;
  if (nonfeasible) {
    statString = [NSString stringWithFormat:
                  @"Executed %@%% of %d lines (%d executed, %d executable, "
                  "%d non-feasible, %d total lines)", coverage, codeLines, 
                  hitLines, codeLines, nonfeasible, totalLines];
  } else {
    statString = [NSString stringWithFormat:
                  @"Executed %@%% of %d lines (%d executed, %d executable, "
                  "%d total lines)", coverage, codeLines, hitLines, 
                  codeLines, totalLines];
  }
  return statString;
}

@end
  
// Transformer for changing line coverage to summaries.
// Used for tooltip
@interface LineCoverageToCoverageSummaryTransformer : NSValueTransformer
@end

@implementation LineCoverageToCoverageSummaryTransformer

+ (Class)transformedValueClass {
  return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
  return NO;
}

- (id)transformedValue:(id)value {
  if (!value) return @"";
  NSAssert1([value respondsToSelector:@selector(objectEnumerator)],
           @"Only handle collections : %@", value);
  NSEnumerator *arrayEnum = [value objectEnumerator];
  NSInteger sources = [value count];
  NSInteger totalLines = 0;
  NSInteger codeLines = 0;
  NSInteger hitLines = 0;
  NSInteger nonfeasible = 0;
  NSString *coverage = nil;
  [arrayEnum coverageTotalLines:&totalLines
                      codeLines:&codeLines
                   hitCodeLines:&hitLines
               nonFeasibleLines:&nonfeasible
                 coverageString:&coverage
                       coverage:NULL];
  NSString *statString = nil;
  if (nonfeasible) {
    statString = [NSString stringWithFormat:
                  @"Executed %@%% of %d lines (%d sources, %d executed, "
                  "%d executable, %d non-feasible, %d total lines)", coverage,
                  codeLines, sources, hitLines, codeLines, nonfeasible,
                  totalLines];
  } else {
    statString = [NSString stringWithFormat:
                  @"Executed %@%% of %d lines (%d sources, %d executed, "
                  "%d executable, %d total lines)", coverage, codeLines,
                  sources, hitLines, codeLines, totalLines];
  }
  return statString;
}

@end

// Transformer for changing line coverage to short summaries.
// Used at top of file list.
@interface LineCoverageToCoverageShortSummaryTransformer : NSValueTransformer
@end

@implementation LineCoverageToCoverageShortSummaryTransformer

+ (Class)transformedValueClass {
  return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
  return NO;
}

- (id)transformedValue:(id)value {
  if (!value) return @"";
  NSAssert1([value respondsToSelector:@selector(objectEnumerator)],
            @"Only handle collections : %@", value);
  NSEnumerator *arrayEnum = [value objectEnumerator];
  NSInteger codeLines = 0;
  NSString *coverage = nil;
  [arrayEnum coverageTotalLines:NULL
                      codeLines:&codeLines
                   hitCodeLines:NULL
               nonFeasibleLines:NULL
                 coverageString:&coverage
                       coverage:NULL];
  return [NSString stringWithFormat:@"%@%% of %d lines", coverage, codeLines];
}

@end
