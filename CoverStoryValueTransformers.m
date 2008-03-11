//
//  CoverStoryValueTransformers.m
//  CoverStory
//
//  Created by Dave MacLachlan on 2008/03/10.
//  Copyright 2008 Google Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CoverStoryCoverageData.h"

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
  SInt32 hitCount = [data hitCount];
  NSString *displayString = @"";
  NSDictionary *attributes = nil;
  if (hitCount != -1) {
    NSMutableParagraphStyle *pStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
    [pStyle setAlignment:NSRightTextAlignment];
    NSColor *color = nil;
    if (hitCount == 0.0) {
      color = [NSColor redColor];
    } else {
      color = [NSColor colorWithDeviceWhite:0.4 alpha:1.0];
    }
    
    attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                    pStyle, NSParagraphStyleAttributeName, 
                    color, NSForegroundColorAttributeName, 
                    nil];
    if (hitCount == -2) {
      displayString = @"--"; // for non-feasible lines
    } else if (hitCount < 999) {
      displayString = [NSString stringWithFormat:@"%d", hitCount];
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
  NSString *line = [data line];
  SInt32 hitCount = [data hitCount];
  NSColor *textColor;
  if (hitCount == 0) {
    textColor = [NSColor redColor];
  } else if (hitCount < 0) {
    textColor = [NSColor grayColor];
  } else {
    textColor = [NSColor blackColor];
  }
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
  float coverage = [[data coverage] floatValue];
  NSString *coverageString = [NSString stringWithFormat:@"%.1f", coverage];
  float redHue = 0;
  float greenHue = 120.0/360.0;
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
// Used for tooltips and top of window summaries.
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
  NSAssert([value conformsToProtocol:@protocol(CoverStoryLineCoverageProtocol)], 
           @"Only handle CoverStoryLineCoverageProtocol");
  id<CoverStoryLineCoverageProtocol> data = (id<CoverStoryLineCoverageProtocol>)value;
  SInt32 totalLines = [data numberTotalLines];
  SInt32 hitLines   = [data numberHitCodeLines];
  SInt32 codeLines  = [data numberCodeLines];
  SInt32 nonfeasible  = [data numberNonFeasibleLines];
  float coverage = [[data coverage] floatValue];
  NSString *statString = nil;
  if (nonfeasible) {
    statString = [NSString stringWithFormat:
                  @"Executed %.2f%% of %d lines (%d executed, %d executable, "
                  "%d non-feasible, %d total lines)", coverage, codeLines, 
                  hitLines, codeLines, nonfeasible, totalLines];
  } else {
    statString = [NSString stringWithFormat:
                  @"Executed %.2f%% of %d lines (%d executed, %d executable, "
                  "%d total lines)", coverage, codeLines, hitLines, 
                  codeLines, totalLines];
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
  NSAssert([value conformsToProtocol:@protocol(CoverStoryLineCoverageProtocol)], 
           @"Only handle CoverStoryLineCoverageProtocol");
  id<CoverStoryLineCoverageProtocol> data = (id<CoverStoryLineCoverageProtocol>)value;
  SInt32 codeLines  = [data numberCodeLines];
  float coverage = [[data coverage] floatValue];
  return [NSString stringWithFormat:@"%.2f%% of %d lines", coverage, codeLines];
}

@end
