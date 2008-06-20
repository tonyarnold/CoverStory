//
//  CoverStoryCoverageDataTest.m
//  CoverStory
//
//  Created by Thomas Van Lenten on 6/19/08.
//  Copyright 2008 Google Inc. All rights reserved.
//

#import "GTMSenTestCase.h"
#import "CoverStoryCoverageData.h"

@interface CoverStoryCoverageDataTest : SenTestCase 
@end

@implementation CoverStoryCoverageDataTest

#pragma mark CoverStoryCoverageLineData

- (void)test1LineDataBasics {
  struct TestDataRecord {
    NSString *line;
    SInt32 hitCount;
    SInt32 complexity;
  } testData[] = {
    { nil, 0, 0 },
    { nil, 1, 1 },
    { @"line", 0, 0 },
    { @"line2", 10, 2 },
    { @"line3", kCoverStoryNotExecutedMarker, 0 },
    { @"line4", kCoverStoryNonFeasibleMarker, 0 },
  };
  for (size_t x = 0; x < sizeof(testData)/sizeof(struct TestDataRecord); ++x) {
    CoverStoryCoverageLineData *data =
      [CoverStoryCoverageLineData coverageLineDataWithLine:testData[x].line
                                                  hitCount:testData[x].hitCount];
    STAssertNotNil(data, nil);
    STAssertEqualObjects([data line], testData[x].line, @"index %u", x);
    STAssertEquals([data hitCount], testData[x].hitCount, @"index %u", x);
    [data setComplexity:testData[x].complexity];
    STAssertEquals([data complexity], testData[x].complexity, @"index %u", x);
    
    STAssertGreaterThan([[data description] length], 5U, @"index %u", x);
    
  }
}

- (void)test2LineDataAddHits {
  struct TestDataRecord {
    SInt32 hitCount1;
    SInt32 hitCount2;
    SInt32 hitCountSum;
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
                                                  hitCount:testData[x].hitCount1];
    STAssertNotNil(data, nil);
    [data addHits:testData[x].hitCount2];
    STAssertEquals([data hitCount], testData[x].hitCountSum, @"index %u", x);
  }
}

#pragma mark CoverStoryCoverageFileData

- (void)test3FileDataBasics {
  NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
  STAssertNotNil(testBundle, nil);
  
  struct TestDataRecord {
    NSString *name;
    NSString *sourcePath;
    int maxComplexity;
    SInt32 numberTotalLines;
    SInt32 numberCodeLines;
    SInt32 numberHitCodeLines;
    SInt32 numberNonFeasibleLines;
    float coverage;
  } testData[] = {
    { @"Foo1a", @"Foo.m", 0, 11, 8, 6, 0, 75.0 },
    { @"Foo1b", @"Foo.m", 0, 11, 8, 6, 0, 75.0 },
    { @"Foo2", @"Bar.m", 0, 15, 4, 2, 5, 50.0 },
    { @"Foo3", @"mcctest.c", 7, 64, 18, 0, 0, 0.0 },
  };
  for (size_t x = 0; x < sizeof(testData)/sizeof(struct TestDataRecord); ++x) {
    NSString *path = [testBundle pathForResource:testData[x].name
                                          ofType:@"gcov"];
    STAssertNotNil(path, @"index %u", x);
    CoverStoryCoverageFileData *data =
      [CoverStoryCoverageFileData coverageFileDataFromPath:path
                                           messageReceiver:nil];
    STAssertNotNil(data, @"index %u", x);
    STAssertEquals([[data lines] count],
                   (unsigned)testData[x].numberTotalLines,
                   @"index %u", x);
    STAssertEquals([data maxComplexity],
                   testData[x].maxComplexity,
                   @"index %u", x);
    STAssertEqualObjects([data sourcePath],
                   testData[x].sourcePath,
                   @"index %u", x);
    STAssertEquals([data numberTotalLines],
                   testData[x].numberTotalLines,
                   @"index %u", x);
    STAssertEquals([data numberCodeLines],
                   testData[x].numberCodeLines,
                   @"index %u", x);
    STAssertEquals([data numberHitCodeLines],
                   testData[x].numberHitCodeLines,
                   @"index %u", x);
    STAssertEquals([data numberNonFeasibleLines],
                   testData[x].numberNonFeasibleLines,
                   @"index %u", x);
    STAssertEqualObjects([data coverage],
                         [NSNumber numberWithFloat:testData[x].coverage],
                         @"index %u", x);
    
    STAssertGreaterThan([[data description] length], 5U, @"index %u", x);
  }
}

- (void)test4FileDataAddFileData {
  // TODO: write this one
  // test each of the fail paths
  // test that the working sum does as expected w/ NF, and non executable lines
  // (ifdefs)
}

#pragma mark CoverStoryCoverageSet

// TODO: write these tests

@end
