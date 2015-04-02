//
//  GCovVersionManager.m
//  CoverStory
//
//  Created by Thomas Van Lenten on 6/2/10.
//  Copyright 2010 Google Inc. All rights reserved.
//

#import "GCovVersionManager.h"
#import "GTMNSEnumerator+Filter.h"
#import "CoverStory-Swift.h"

@implementation GCovVersionManager

+ (GCovVersionManager *)defaultManager { 
  static GCovVersionManager *obj;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    obj = [[self alloc] init];
  });
  return obj;
}

- (id)init {
  if ((self = [super init])) {
    // Start with what is in /usr/bin
    NSMutableDictionary *map = [[self class] collectVersionsInFolder:@"/usr/bin"];
    // Override it with what is in the Developer directory's /usr/bin.
    // TODO: Should really use xcode-select -print-path as the starting point.
    [map addEntriesFromDictionary:[[self class] collectVersionsInFolder:@"/Developer/usr/bin"]];
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if ([fm fileExistsAtPath:@"/Applications/Xcode.app" isDirectory:&isDir]
        && isDir) {
      [map addEntriesFromDictionary:
       [[self class] collectVersionsInFolder:@"/Applications/Xcode.app/Contents/Developer/usr/bin"]];
    }
    versionMap_ = [map copy];
  }
  return self;
}


- (NSString*)defaultGCovPath {
  return [versionMap_ objectForKey:@""];
}

- (NSArray*)installedVersions {
  return [versionMap_ allValues];
}

- (NSString*)versionFromGCovFile:(NSString*)path {
  NSString *result = nil;

  uint32 GCDA_HEADER = 'gcda';
  uint32 GCDA_HEADER_WRONG_ENDIAN = 'adcg';
  uint32 GCNO_HEADER = 'gcno';
  uint32 GCNO_HEADER_WRONG_ENDIAN = 'oncg';

  // Read in the file header and version number.
  if ([path length]) {
    const char* cPath = [path fileSystemRepresentation];
    if (cPath) {
      FILE *aFile = fopen(cPath, "r");
      if (aFile) {
        uint32 buffer[2];
        if (fread(buffer, sizeof(uint32), 2, aFile) == 2) {
          // Check the header.
          if ((buffer[0] == GCDA_HEADER) ||
              (buffer[0] == GCDA_HEADER_WRONG_ENDIAN) ||
              (buffer[0] == GCNO_HEADER) ||
              (buffer[0] == GCNO_HEADER_WRONG_ENDIAN)) {
            uint32 ver = buffer[1];
            BOOL flip = ((buffer[0] == GCDA_HEADER_WRONG_ENDIAN) ||
                         (buffer[0] == GCNO_HEADER_WRONG_ENDIAN));
            if (flip) {
              ver =
                ((ver & 0xff000000) >> 24) |
                ((ver & 0x00ff0000) >>  8) |
                ((ver & 0x0000ff00) <<  8) |
                ((ver & 0x000000ff) << 24);
            }

            uint32 major = ((ver & 0xff000000) >> 24) - '0';
            uint32 minor10s = ((ver & 0x00ff0000) >> 16) - '0';
            uint32 minor1s = ((ver & 0x0000ff00) >> 8) - '0';
            uint32 minor = minor10s * 10 + minor1s;
            result = [NSString stringWithFormat:@"%u.%u", major, minor];
          }
        }
        fclose(aFile);
      }
    }
  }
  return result;
}

- (NSString*)gcovForGCovFile:(NSString*)path {
  NSString *version = [self versionFromGCovFile:path];
  NSString *result = [versionMap_ objectForKey:version];
  if (!result) {
    result = [self defaultGCovPath];
  }
  return result;
}

@end
