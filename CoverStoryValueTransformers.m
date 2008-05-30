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
  SInt32 count = [data hitCount];

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

// Transformer for changing Line Data to Complexity.
// Used for first column of source code table.
@interface CoverageLineDataToComplexityTransformer : NSValueTransformer
@end

@implementation CoverageLineDataToComplexityTransformer

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
  // Draw the hitcount/complexity
  SInt32 count = [data complexity];
  
  NSString *displayString = @"";
  NSDictionary *attributes = nil;
  if (count != 0) {
    NSMutableParagraphStyle *pStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
    [pStyle setAlignment:NSRightTextAlignment];
    [pStyle setMinimumLineHeight:13];
    
    attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                  pStyle, NSParagraphStyleAttributeName,
                  nil];
    
    displayString = [NSString stringWithFormat:@"%d", count];
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
  SInt32 hitCount = [data hitCount];
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

// Transformer for changing file data to complexity.
// Used for second column of files table.
@interface CoverageFileDataToComplexityTransformer : NSValueTransformer
@end

@implementation CoverageFileDataToComplexityTransformer

const float kBadComplexity = 50.0f;
const float kGoodComplexity = 5.0f;  // keeps things up to about 15 still green

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
  SInt32 maxComplexity = [data maxComplexity];
  NSString *coverageString = [NSString stringWithFormat:@"%d", maxComplexity];
  float redHue = 0;
  float greenHue = 120.0/360.0;
  float hue = 0;
  float saturation = 1.0f;
  float brightness = 0.75f;
  if (maxComplexity > kBadComplexity) {
    hue = redHue;
  } else if (maxComplexity > kGoodComplexity) {
    // The higher the complexity, the less green we want, so subtract from 1.0
    // to invert the fraction of "bad".
    float percentComplex =
      ((maxComplexity - kGoodComplexity) / (kBadComplexity - kGoodComplexity));
    hue = redHue + (greenHue * (1.0f - percentComplex));
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
  SInt32 totalLines = 0;
  SInt32 hitLines   = 0;
  SInt32 codeLines  = 0;
  SInt32 nonfeasible  = 0;
  
  id<CoverStoryLineCoverageProtocol> data;
  while ((data = [arrayEnum nextObject])) {
    totalLines += [data numberTotalLines];
    hitLines += [data numberHitCodeLines];
    codeLines += [data numberCodeLines];
    nonfeasible += [data numberNonFeasibleLines];
  }
  float coverage = 0.0;
  if (codeLines > 0) {
    coverage = (float)hitLines / (float)codeLines * 100.0;
  }
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
  if (!value) return @"";
  NSAssert1([value respondsToSelector:@selector(objectEnumerator)],
            @"Only handle collections : %@", value);
  NSEnumerator *arrayEnum = [value objectEnumerator];
  SInt32 hitLines   = 0;
  SInt32 codeLines  = 0;
  
  id<CoverStoryLineCoverageProtocol> data;
  while ((data = [arrayEnum nextObject])) {
    hitLines += [data numberHitCodeLines];
    codeLines += [data numberCodeLines];
  }
  float coverage = 0.0;
  if (codeLines > 0) {
    coverage = (float)hitLines / (float)codeLines * 100.0;
  }
  
  return [NSString stringWithFormat:@"%.2f%% of %d lines", coverage, codeLines];
}

@end
