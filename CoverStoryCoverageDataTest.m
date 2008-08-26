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
    NSInteger hitCount;
    NSInteger complexity;
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
    NSInteger numberTotalLines;
    NSInteger numberCodeLines;
    NSInteger numberHitCodeLines;
    NSInteger numberNonFeasibleLines;
    float coverage;
  } testData[] = {
    { @"Foo1a", @"Foo.m", 0, 11, 8, 6, 0, 75.0 },
    { @"Foo1b", @"Foo.m", 0, 11, 8, 6, 0, 75.0 },
    { @"Foo2", @"Bar.m", 0, 15, 4, 2, 5, 50.0 },
    { @"Foo3", @"mcctest.c", 7, 64, 18, 0, 0, 0.0 },
    { @"NoEndingNewline", @"Baz.m", 0, 11, 8, 6, 0, 75.0 },
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
    STAssertEquals(totalLines, testData[x].numberTotalLines, @"index %u", x);
    STAssertEquals(codeLines, testData[x].numberCodeLines, @"index %u", x);
    STAssertEquals(hitCodeLines, testData[x].numberHitCodeLines, @"index %u", x);
    STAssertEquals(nonFeasible, testData[x].numberNonFeasibleLines, @"index %u", x);
    STAssertEqualsWithAccuracy(coverage, testData[x].coverage, 0x001f, @"index %u", x);
    STAssertNotNil(coverageString, @"index %u", x);
    
    STAssertGreaterThan([[data description] length], 5U, @"index %u", x);
  }
}

- (void)test4FileDataLineEndings {
  NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
  STAssertNotNil(testBundle, nil);
  
  struct TestDataRecord {
    NSString *name;
    NSString *sourcePath;
    int maxComplexity;
    NSInteger numberTotalLines;
    NSInteger numberCodeLines;
    NSInteger numberHitCodeLines;
    NSInteger numberNonFeasibleLines;
    float coverage;
  } testData[] = {
    { @"testCR", @"Foo.m", 0, 11, 8, 6, 0, 75.0 },
    { @"testLF", @"Foo.m", 0, 11, 8, 6, 0, 75.0 },
    { @"testCRLF", @"Foo.m", 0, 11, 8, 6, 0, 75.0 },
  };
  NSMutableSet *fileContentsSet = [NSMutableSet set];
  STAssertNotNil(fileContentsSet, nil);
  CoverStoryCoverageFileData *prevData = nil;
  for (size_t x = 0; x < sizeof(testData)/sizeof(struct TestDataRecord); ++x) {
    NSString *path = [testBundle pathForResource:testData[x].name
                                          ofType:@"gcov"];
    // load the file blob and store in a set to ensure they each have different
    // byte sequences (due to the end of line markers they are using)
    STAssertNotNil(path, @"index %u", x);
    NSData *fileContents = [NSData dataWithContentsOfFile:path];
    STAssertNotNil(fileContents, @"index %u", x);
    [fileContentsSet addObject:fileContents];
    STAssertEquals([fileContentsSet count], (unsigned)(x + 1),
                   @"failed to get a uniq file contents at index %u", x);
    // now process the file
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
    STAssertEquals(totalLines, testData[x].numberTotalLines, @"index %u", x);
    STAssertEquals(codeLines, testData[x].numberCodeLines, @"index %u", x);
    STAssertEquals(hitCodeLines, testData[x].numberHitCodeLines, @"index %u", x);
    STAssertEquals(nonFeasible, testData[x].numberNonFeasibleLines, @"index %u", x);
    STAssertEqualsWithAccuracy(coverage, testData[x].coverage, 0x001f, @"index %u", x);
    STAssertNotNil(coverageString, @"index %u", x);
    
    // compare this to the previous to make sure we got the same thing (the
    // file all match except for newlines).
    if (prevData) {
      NSArray *prevDataLines = [prevData lines];
      NSArray *dataLines = [data lines];
      STAssertNotNil(prevDataLines, @"index %u", x);
      STAssertNotNil(dataLines, @"index %u", x);
      STAssertEquals([prevDataLines count], [dataLines count], @"index %u", x);
      for (unsigned int y = 0 ; y < [dataLines count] ; ++y) {
        CoverStoryCoverageLineData *prevDataLine = [prevDataLines objectAtIndex:y];
        CoverStoryCoverageLineData *dataLine = [prevDataLines objectAtIndex:y];
        STAssertNotNil(prevDataLine, @"index %u - %u", y, x);
        STAssertNotNil(dataLine, @"index %u - %u", y, x);
        STAssertEqualObjects([prevDataLine line], [dataLine line],
                             @"line contents didn't match at index %u - %u", y, x);
        STAssertEquals([prevDataLine hitCount], [dataLine hitCount],
                       @"line hits didn't match at index %u - %u", y, x);
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
