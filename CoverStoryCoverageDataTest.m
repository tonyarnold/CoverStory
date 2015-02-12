//
//  CoverStoryCoverageDataTest.m
//  CoverStory
//
//  Created by Thomas Van Lenten on 6/19/08.
//  Copyright 2008 Google Inc. All rights reserved.
//

@import XCTest;
#import "CoverStoryCoverageData.h"

@interface CoverStoryCoverageDataTest : XCTestCase 
@end

@implementation CoverStoryCoverageDataTest

#pragma mark CoverStoryCoverageLineData

- (void)test1LineDataBasics {
  struct TestDataRecord {
    NSString *line;
    NSInteger hitCount;
  } testData[] = {
    { nil, 0 },
    { nil, 1 },
    { @"line", 0 },
    { @"line2", 10 },
    { @"line3", kCoverStoryNotExecutedMarker },
    { @"line4", kCoverStoryNonFeasibleMarker },
  };
  for (size_t x = 0; x < sizeof(testData)/sizeof(struct TestDataRecord); ++x) {
    CoverStoryCoverageLineData *data =
      [CoverStoryCoverageLineData coverageLineDataWithLine:testData[x].line
                                                  hitCount:testData[x].hitCount
                                              coverageFile:nil];
    XCTAssertNotNil(data);
    XCTAssertEqualObjects([data line], testData[x].line, @"index %zu", x);
    XCTAssertEqual([data hitCount], testData[x].hitCount, @"index %zu", x);

    XCTAssertGreaterThan([[data description] length], 5);
  }
}

- (void)test2LineDataAddHits {
  struct TestDataRecord {
    NSInteger hitCount1;
    NSInteger hitCount2;
    NSInteger hitCountSum;
  } testData[] = {
    { 0, 0, 0 },
    { 0, 1, 1 },
    { 1, 0, 1 },
    { 1, 1, 2 },

    { 0, kCoverStoryNotExecutedMarker, 0 },
    { kCoverStoryNotExecutedMarker, 0, 0 },
    { kCoverStoryNotExecutedMarker, kCoverStoryNotExecutedMarker, kCoverStoryNotExecutedMarker },
    { 1, kCoverStoryNotExecutedMarker, 1 },
    { kCoverStoryNotExecutedMarker, 1, 1 },

    { kCoverStoryNonFeasibleMarker, kCoverStoryNonFeasibleMarker, kCoverStoryNonFeasibleMarker },
  };
  for (size_t x = 0; x < sizeof(testData)/sizeof(struct TestDataRecord); ++x) {
    CoverStoryCoverageLineData *data =
      [CoverStoryCoverageLineData coverageLineDataWithLine:@"line"
                                                  hitCount:testData[x].hitCount1
                                              coverageFile:nil];
    XCTAssertNotNil(data);
    [data addHits:testData[x].hitCount2];
    XCTAssertEqual([data hitCount], testData[x].hitCountSum, @"index %zu", x);
  }
}

#pragma mark CoverStoryCoverageFileData

- (void)test3FileDataBasics {
  NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
  XCTAssertNotNil(testBundle);
  
  struct TestDataRecord {
    NSString *name;
    NSString *sourcePath;
    NSInteger numberTotalLines;
    NSInteger numberCodeLines;
    NSInteger numberHitCodeLines;
    NSInteger numberNonFeasibleLines;
    float coverage;
  } testData[] = {
    { @"Foo1a", @"Foo.m", 11, 8, 6, 0, 75.0f },
    { @"Foo1b", @"Foo.m", 11, 8, 6, 0, 75.0f },
    { @"Foo2", @"Bar.m", 15, 4, 2, 5, 50.0f },
    { @"Foo3", @"mcctest.c", 64, 18, 0, 0, 0.0f },
    { @"NoEndingNewline", @"Baz.m", 11, 8, 6, 0, 75.0f },
  };
  for (size_t x = 0; x < sizeof(testData)/sizeof(struct TestDataRecord); ++x) {
    NSString *path = [testBundle pathForResource:testData[x].name
                                          ofType:@"gcov"];
    XCTAssertNotNil(path, @"index %zu", x);
    CoverStoryCoverageFileData *data =
      [CoverStoryCoverageFileData coverageFileDataFromPath:path
                                                  document:nil
                                           messageReceiver:nil];
    XCTAssertNotNil(data, @"index %zu", x);
    XCTAssertEqual([[data lines] count],
                   (NSUInteger)testData[x].numberTotalLines,
                   @"index %zu", x);
    XCTAssertEqualObjects([data sourcePath],
                   testData[x].sourcePath,
                   @"index %zu", x);
    NSInteger totalLines = 0;
    NSInteger codeLines = 0;
    NSInteger hitCodeLines = 0;
    NSInteger nonFeasible = 0;
    NSString *coverageString = nil;
    float coverage = 0.0f;
    [data coverageTotalLines:&totalLines
                   codeLines:&codeLines
                hitCodeLines:&hitCodeLines
            nonFeasibleLines:&nonFeasible
              coverageString:&coverageString
                    coverage:&coverage];
    XCTAssertEqual(totalLines, testData[x].numberTotalLines, @"index %zu", x);
    XCTAssertEqual(codeLines, testData[x].numberCodeLines, @"index %zu", x);
    XCTAssertEqual(hitCodeLines, testData[x].numberHitCodeLines, @"index %zu", x);
    XCTAssertEqual(nonFeasible, testData[x].numberNonFeasibleLines, @"index %zu", x);
    XCTAssertEqualWithAccuracy(coverage, testData[x].coverage, 0x001f, @"index %zu", x);
    XCTAssertNotNil(coverageString, @"index %zu", x);
    
    XCTAssertGreaterThan([[data description] length], 5);
  }
}

- (void)test4FileDataLineEndings {
  NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
  XCTAssertNotNil(testBundle);
  
  struct TestDataRecord {
    NSString *name;
    NSString *sourcePath;
    NSInteger numberTotalLines;
    NSInteger numberCodeLines;
    NSInteger numberHitCodeLines;
    NSInteger numberNonFeasibleLines;
    float coverage;
  } testData[] = {
    { @"testCR", @"Foo.m", 11, 8, 6, 0, 75.0f },
    { @"testLF", @"Foo.m", 11, 8, 6, 0, 75.0f },
    { @"testCRLF", @"Foo.m", 11, 8, 6, 0, 75.0f },
  };
  NSMutableSet *fileContentsSet = [NSMutableSet set];
  XCTAssertNotNil(fileContentsSet);
  CoverStoryCoverageFileData *prevData = nil;
  for (size_t x = 0; x < sizeof(testData)/sizeof(struct TestDataRecord); ++x) {
    NSString *path = [testBundle pathForResource:testData[x].name
                                          ofType:@"gcov"];
    // load the file blob and store in a set to ensure they each have different
    // byte sequences (due to the end of line markers they are using)
    XCTAssertNotNil(path, @"index %zu", x);
    NSData *fileContents = [NSData dataWithContentsOfFile:path];
    XCTAssertNotNil(fileContents, @"index %zu", x);
    [fileContentsSet addObject:fileContents];
    XCTAssertEqual([fileContentsSet count], (NSUInteger)(x + 1),
                   @"failed to get a uniq file contents at index %zu", x);
    // now process the file
    CoverStoryCoverageFileData *data =
      [CoverStoryCoverageFileData coverageFileDataFromPath:path
                                                  document:nil
                                           messageReceiver:nil];
    XCTAssertNotNil(data, @"index %zu", x);
    XCTAssertEqual([[data lines] count],
                   (NSUInteger)testData[x].numberTotalLines,
                   @"index %zu", x);
    XCTAssertEqualObjects([data sourcePath],
                         testData[x].sourcePath,
                         @"index %zu", x);
    NSInteger totalLines = 0;
    NSInteger codeLines = 0;
    NSInteger hitCodeLines = 0;
    NSInteger nonFeasible = 0;
    NSString *coverageString = nil;
    float coverage = 0.0f;
    [data coverageTotalLines:&totalLines
                   codeLines:&codeLines
                hitCodeLines:&hitCodeLines
            nonFeasibleLines:&nonFeasible
              coverageString:&coverageString
                    coverage:&coverage];
    XCTAssertEqual(totalLines, testData[x].numberTotalLines, @"index %zu", x);
    XCTAssertEqual(codeLines, testData[x].numberCodeLines, @"index %zu", x);
    XCTAssertEqual(hitCodeLines, testData[x].numberHitCodeLines, @"index %zu", x);
    XCTAssertEqual(nonFeasible, testData[x].numberNonFeasibleLines, @"index %zu", x);
    XCTAssertEqualWithAccuracy(coverage, testData[x].coverage, 0x001f, @"index %zu", x);
    XCTAssertNotNil(coverageString, @"index %zu", x);
    
    // compare this to the previous to make sure we got the same thing (the
    // file all match except for newlines).
    if (prevData) {
      NSArray *prevDataLines = [prevData lines];
      NSArray *dataLines = [data lines];
      XCTAssertNotNil(prevDataLines, @"index %zu", x);
      XCTAssertNotNil(dataLines, @"index %zu", x);
      XCTAssertEqual([prevDataLines count], [dataLines count], @"index %zu", x);
      for (unsigned int y = 0 ; y < [dataLines count] ; ++y) {
        CoverStoryCoverageLineData *prevDataLine = [prevDataLines objectAtIndex:y];
        CoverStoryCoverageLineData *dataLine = [prevDataLines objectAtIndex:y];
        XCTAssertNotNil(prevDataLine, @"index %u - %zu", y, x);
        XCTAssertNotNil(dataLine, @"index %u - %zu", y, x);
        XCTAssertEqualObjects([prevDataLine line], [dataLine line],
                             @"line contents didn't match at index %u - %zu", y, x);
        XCTAssertEqual([prevDataLine hitCount], [dataLine hitCount],
                       @"line hits didn't match at index %u - %zu", y, x);
      }
    }
    prevData = data;
  }
}

- (void)test5FileDataAddFileData {
  // TODO: write this one
  // test each of the fail paths
  // test that the working sum does as expected w/ NF, and non executable lines
  // (ifdefs)
}

#pragma mark CoverStoryCoverageSet

// TODO: write these tests

@end
