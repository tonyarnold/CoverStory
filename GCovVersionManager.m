//
//  GCovVersionManager.m
//  CoverStory
//
//  Created by Thomas Van Lenten on 6/2/10.
//  Copyright 2010 Google Inc. All rights reserved.
//

#import "GCovVersionManager.h"
#import "GTMObjectSingleton.h"
#import "GTMNSEnumerator+Filter.h"

@interface GCovVersionManager (PrivateMethods)
+ (NSMutableDictionary*)collectVersionsInFolder:(NSString *)path;
@end

@implementation GCovVersionManager

GTMOBJECT_SINGLETON_BOILERPLATE(GCovVersionManager, defaultManager);

- (id)init {
  if ((self = [super init])) {
    // Start with what is in /usr/bin
    NSMutableDictionary *map = [[self class] collectVersionsInFolder:@"/usr/bin"];
    // Override it with what is in the Developer directory's /usr/bin.
    // TODO: Should really use xcode-select -print-path as the starting point.
    [map addEntriesFromDictionary:[[self class] collectVersionsInFolder:@"/Developer/usr/bin"]];
    versionMap_ = [map copy];
  }
  return self;
}

- (void) dealloc {
  [versionMap_ release];
  [super dealloc];
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

+ (NSMutableDictionary*)collectVersionsInFolder:(NSString *)path {
  NSMutableDictionary *result = [NSMutableDictionary dictionary];
  NSFileManager *fm = [NSFileManager defaultManager];
  NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:path];
  // ...filter to gcov* apps...
  NSEnumerator *enumerator2 =
    [enumerator gtm_filteredEnumeratorByMakingEachObjectPerformSelector:@selector(hasPrefix:)
                                                             withObject:@"gcov"];
  // ...turn them all into full paths...
  NSEnumerator *enumerator3 =
    [enumerator2 gtm_enumeratorByTarget:path
                  performOnEachSelector:@selector(stringByAppendingPathComponent:)];
  // ...walk over them validating they are good to use.
  NSString *gcovPath;
  while ((gcovPath = [enumerator3 nextObject])) {
    // Must be executable.
    if (![fm isExecutableFileAtPath:gcovPath]) {
      continue;
    }

    // Extract the version.
    NSString *name = [gcovPath lastPathComponent];
    NSString *version = nil;
    if ([name isEqual:@"gcov"]) {
      // It's the default
      version = @"";
    } else {
      NSString *remainder = [name substringFromIndex:4];
      if ([remainder characterAtIndex:0] != '-') {
        NSLog(@"gcov binary name in odd format: %@", gcovPath);
      } else {
        version = [remainder substringFromIndex:1];
      }
    }

    if (version) {
      [result setObject:gcovPath forKey:version];
    }
  }

  return result;
}

@end
