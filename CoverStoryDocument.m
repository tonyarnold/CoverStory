//
//  CoverStoryDocument.m
//  CoverStory
//
//  Created by dmaclach on 12/20/06.
//  Copyright 2006-2007 Google Inc.
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

#import "CoverStoryDocument.h"
#import "CoverStoryCoverageData.h"
#import "CoverStoryDocumentTypes.h"
#import "CoverStoryPreferenceKeys.h"
#import "GCovVersionManager.h"
#import "GTMScriptRunner.h"
#import "GTMNSFileManager+Path.h"
#import "GTMNSEnumerator+Filter.h"
#import "GTMNSString+HTML.h"
#import "GTMLocalizedString.h"

const NSInteger kCoverStorySDKToolbarTag = 1026;
const NSInteger kCoverStoryUnittestToolbarTag = 1027;

@interface NSTableView (CoverStoryTableView)
- (void)cs_setSortKeyOfColumn:(NSString *)columnName
                           to:(NSString *)sortKeyName;
- (void)cs_setValueTransformerOfColumn:(NSString *)columnName
                                    to:(NSString *)transformerName;
- (void)cs_setHeaderOfColumn:(NSString*)columnName
                          to:(NSString*)name;
@end

@interface NSWindow (CoverStoryExportToHTML)
// Script command that we want NSWindow to handle
- (id)cs_handleExportHTMLScriptCommand:(NSScriptCommand *)command;
@end

typedef enum {
  kCSMessageTypeError,
  kCSMessageTypeWarning,
  kCSMessageTypeInfo
} CSMessageType;

@interface CoverStoryDocument (PrivateMethods)
- (void)openFolderInThread:(NSString*)path;
- (void)openFileInThread:(NSString*)path;
- (void)setOpenThreadState:(BOOL)threadRunning;
- (BOOL)processCoverageForFolder:(NSString *)path;
#if USE_NSOPERATION
- (void)cleanupTempDir:(NSString *)tempDir;
- (void)loadCoveragePath:(NSString *)fullPath;
#endif
- (BOOL)processCoverageForFiles:(NSArray *)filenames
                       inFolder:(NSString *)folderPath;
- (BOOL)addFileData:(CoverStoryCoverageFileData *)fileData;
- (void)addMessageFromThread:(NSString *)message
                        path:(NSString*)path
                 messageType:(CSMessageType)msgType;
- (void)addMessageFromThread:(NSString *)message
                 messageType:(CSMessageType)msgType;
- (void)addMessage:(NSDictionary *)msgInfo;
- (BOOL)isClosed;
- (void)moveSelection:(NSUInteger)offset;
@end

static NSString *const kPrefsToWatch[] = {
  kCoverStorySystemSourcesPatternsKey,
  kCoverStoryUnittestSourcesPatternsKey,
  kCoverStoryRemoveCommonSourcePrefix,
  kCoverStoryMissedLineColorKey,
  kCoverStoryUnexecutableLineColorKey,
  kCoverStoryNonFeasibleLineColorKey,
  kCoverStoryExecutedLineColorKey
};

@implementation CoverStoryDocument

+ (void)registerDefaults {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSDictionary *documentDefaults =
    [NSDictionary dictionaryWithObjectsAndKeys:
     [NSNumber numberWithInt:kCoverStoryFilterStringTypeWildcardPattern],
     kCoverStoryFilterStringTypeKey,
     [NSNumber numberWithBool:YES],
     kCoverStoryRemoveCommonSourcePrefix,
     nil];

  [defaults registerDefaults:documentDefaults];
}

- (NSString*)valuesKey:(NSString*)key {
  return [NSString stringWithFormat:@"values.%@", key];
}

- (id)init {
  if ((self = [super init])) {

    dataSet_ = [[CoverStoryCoverageSet alloc] init];

    NSString *path;
    NSFileWrapper *wrapper;
    NSBundle *mainBundle = [NSBundle mainBundle];

    path        = [mainBundle pathForResource:@"error" ofType:@"png"];
    wrapper     = [[[NSFileWrapper alloc] initWithPath:path] autorelease];
    errorIcon_  = [[NSTextAttachment alloc] initWithFileWrapper:wrapper];

    path         = [mainBundle pathForResource:@"warning" ofType:@"png"];
    wrapper      = [[[NSFileWrapper alloc] initWithPath:path] autorelease];
    warningIcon_ = [[NSTextAttachment alloc] initWithFileWrapper:wrapper];

    path         = [mainBundle pathForResource:@"info" ofType:@"png"];
    wrapper      = [[[NSFileWrapper alloc] initWithPath:path] autorelease];
    infoIcon_    = [[NSTextAttachment alloc] initWithFileWrapper:wrapper];

    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    hideSDKSources_ = [ud boolForKey:kCoverStoryHideSystemSourcesKey];
    hideUnittestSources_ = [ud boolForKey:kCoverStoryHideUnittestSourcesKey];

#if USE_NSOPERATION
    opQueue_ = [[NSOperationQueue alloc] init];
#endif
  }
  return self;
}

- (void)dealloc {
  NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
  for (size_t i = 0; i < sizeof(kPrefsToWatch) / sizeof(NSString*); ++i) {
    [defaults removeObserver:self
                  forKeyPath:[self valuesKey:kPrefsToWatch[i]]];
  }
  [dataSet_ release];
  [filterString_ release];
  [currentAnimation_ release];
  [commonPathPrefix_ release];
#if USE_NSOPERATION
  [opQueue_ release];
#endif
#if DEBUG
  [startDate_ release];
#endif
  [super dealloc];
}


- (void)awakeFromNib {
  // expand the search field to start out (odds are we've already started to
  // load something, but the annimation is done by a selector invoke on the main
  // thread so it will happen after we've been called.)
  NSRect searchFieldFrame = [searchField_ frame];
  animationWidth_ = searchFieldFrame.origin.x - [spinner_ frame].origin.x;
  searchFieldFrame.origin.x -= animationWidth_;
  searchFieldFrame.size.width += animationWidth_;
  [searchField_ setFrame:searchFieldFrame];

  [sourceFilesController_ addObserver:self
                           forKeyPath:NSSelectionIndexesBinding
                              options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                              context:nil];

  NSUserDefaultsController *defaults = [NSUserDefaultsController sharedUserDefaultsController];
  for (size_t i = 0; i < sizeof(kPrefsToWatch) / sizeof(NSString*); ++i) {
    [defaults addObserver:self
               forKeyPath:[self valuesKey:kPrefsToWatch[i]]
                  options:NSKeyValueObservingOptionNew
                  context:nil];
  }

  [self observeValueForKeyPath:NSSelectionIndexesBinding
                      ofObject:sourceFilesController_
                        change:nil
                       context:nil];

  NSSortDescriptor *ascending = [[[NSSortDescriptor alloc] initWithKey:@"coverage"
                                                             ascending:YES] autorelease];
  [sourceFilesController_ setSortDescriptors:[NSArray arrayWithObject:ascending]];

  // TODO(dmaclach): move this into the xib since we don't have a toggle anymore
  [codeTableView_ cs_setValueTransformerOfColumn:@"hitCount"
                                              to:@"CoverageLineDataToHitCountTransformer"];
  [sourceFilesTableView_ cs_setValueTransformerOfColumn:@"coverage"
                                                     to:@"CoverageFileDataToCoveragePercentageTransformer"];
  [sourceFilesTableView_ cs_setSortKeyOfColumn:@"coverage" to:@"coverage"];
  [sourceFilesTableView_ cs_setHeaderOfColumn:@"coverage" to:@"%"];
}

- (NSString *)windowNibName {
  return @"CoverStoryDocument";
}

- (NSArray *)fileDatas {
  return [dataSet_ fileDatas];
}

// Called as a performSelectorOnMainThread, so must check to make sure
// we haven't been closed.
- (BOOL)addFileData:(CoverStoryCoverageFileData *)fileData {
  if ([self isClosed]) return NO;
  ++numFileDatas_;
  BOOL isGood = [dataSet_ addFileData:fileData messageReceiver:self];
  return isGood;
}

- (BOOL)readFromFileWrapper:(NSFileWrapper *)fileWrapper
                     ofType:(NSString *)typeName
                      error:(NSError **)outError {
  BOOL isGood = NO;
  numFileDatas_ = 0;
#if DEBUG
  [startDate_ release];
  startDate_ = [[NSDate date] retain];
#endif

  // the wrapper doesn't have the full path, but it's already set on us, so
  // use that instead.
  NSString *path = [[self fileURL] path];
  if ([fileWrapper isDirectory]) {
    NSString *message =
      [NSString stringWithFormat:@"Scanning for coverage data in '%@'",
       path];
    [self addMessageFromThread:message messageType:kCSMessageTypeInfo];
    [NSThread detachNewThreadSelector:@selector(openFolderInThread:)
                             toTarget:self
                           withObject:path];
    isGood = YES;
  } else if ([typeName isEqualToString:@kGCOVTypeName]) {
    NSString *message =
      [NSString stringWithFormat:@"Reading gcov data '%@'",
       path];
    [self addMessageFromThread:message messageType:kCSMessageTypeInfo];
    // load it and add it to our set
    CoverStoryCoverageFileData *fileData =
      [CoverStoryCoverageFileData coverageFileDataFromPath:path
                                                  document:self
                                           messageReceiver:self];
    if (fileData) {
      isGood = [self addFileData:fileData];
    } else {
      [self addMessageFromThread:@"Failed to load gcov data"
                            path:path
                     messageType:kCSMessageTypeError];
    }
  } else {
    NSString *message =
      [NSString stringWithFormat:@"Processing coverage data in '%@'",
       path];
    [self addMessageFromThread:message messageType:kCSMessageTypeInfo];
    [NSThread detachNewThreadSelector:@selector(openFileInThread:)
                             toTarget:self
                           withObject:path];
    isGood = YES;
  }
  return isGood;
}

- (void)openSelectedSource {
  BOOL didOpen = NO;
  NSArray *fileSelection = [sourceFilesController_ selectedObjects];
  CoverStoryCoverageFileData *fileData = [fileSelection objectAtIndex:0];
  NSString *path = [fileData sourcePath];
  NSIndexSet *selectedRows = [codeTableView_ selectedRowIndexes];
  if ([selectedRows count]) {
    NSString *scriptPath = [[NSBundle mainBundle] pathForResource:@"openscript"
                                                           ofType:@"scpt"
                                                      inDirectory:@"Scripts"];
    if (scriptPath) {
      GTMScriptRunner *runner = [GTMScriptRunner runnerWithInterpreter:@"/usr/bin/osascript"];
      [runner runScript:scriptPath
               withArgs:[NSArray arrayWithObjects:
                         path,
                         [NSString stringWithFormat:@"%d", [selectedRows firstIndex] + 1],
                         [NSString stringWithFormat:@"%d", [selectedRows lastIndex] + 1],
                         nil]];
    }
  }
  if (!didOpen) {
    [[NSWorkspace sharedWorkspace] openFile:path];
  }
}

- (BOOL)isDocumentEdited {
  return NO;
}

- (void)openFolderInThread:(NSString*)path {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  [self setOpenThreadState:YES];
  @try {
    [self processCoverageForFolder:path];
  }
  @catch (NSException *e) {
    NSString *msg =
      [NSString stringWithFormat:@"Internal error while processing directory (%@ - %@).",
                                 [e name], [e reason]];
    [self addMessageFromThread:msg path:path messageType:kCSMessageTypeError];
  }
#if USE_NSOPERATION
  // wait for all the operations to finish
  [opQueue_ waitUntilAllOperationsAreFinished];
#endif

  // signal that we're done
  [self performSelectorOnMainThread:@selector(finishedLoadingFileDatas:)
                         withObject:@"ignored"
                      waitUntilDone:NO];
  [self setOpenThreadState:NO];

  // Clean up NSTask Zombies.
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
  [pool release];
}

- (void)openFileInThread:(NSString*)path {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  [self setOpenThreadState:YES];
  NSString *folderPath = [path stringByDeletingLastPathComponent];
  NSString *filename = [path lastPathComponent];
  @try {
    [self processCoverageForFiles:[NSArray arrayWithObject:filename]
                         inFolder:folderPath];
  }
  @catch (NSException *e) {
    NSString *msg =
    [NSString stringWithFormat:@"Internal error while processing file (%@ - %@).",
     [e name], [e reason]];
    [self addMessageFromThread:msg path:path messageType:kCSMessageTypeError];
  }
#if USE_NSOPERATION
  // wait for all the operations to finish
  [opQueue_ waitUntilAllOperationsAreFinished];
#endif

  // signal that we're done
  [self performSelectorOnMainThread:@selector(finishedLoadingFileDatas:)
                         withObject:@"ignored"
                      waitUntilDone:NO];
  [self setOpenThreadState:NO];

  // Clean up NSTask Zombies.
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
  [pool release];
}

- (BOOL)processCoverageForFolder:(NSString *)path {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  // cycle through the directory...
  NSFileManager *fm = [NSFileManager defaultManager];
  NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:path];
  // ...filter to .gcda files...
  NSEnumerator *enumerator2 =
    [enumerator gtm_filteredEnumeratorByMakingEachObjectPerformSelector:@selector(hasSuffix:)
                                                             withObject:@".gcda"];
  // ...turn them all into full paths...
  NSEnumerator *enumerator3 =
    [enumerator2 gtm_enumeratorByTarget:path
                  performOnEachSelector:@selector(stringByAppendingPathComponent:)];
  // .. and collect them all.
  NSArray *allFilePaths = [enumerator3 allObjects];
  NSUInteger pathCount = [allFilePaths count];
  if (pathCount == 0) {
    [self addMessageFromThread:@"Found no gcda files to process."
                   messageType:kCSMessageTypeWarning];
  } else if (pathCount == 1) {
    [self addMessageFromThread:@"Found 1 gcda file to process."
                   messageType:kCSMessageTypeInfo];
  } else {
    NSString *message =
      [NSString stringWithFormat:@"Found %u gcda files to process.", pathCount];
    [self addMessageFromThread:message
                   messageType:kCSMessageTypeInfo];
  }

  // we want to batch process them by chunks w/in a given directory.  so sort
  // and then break them off into chunks.
  allFilePaths = [allFilePaths sortedArrayUsingSelector:@selector(compare:)];
  NSEnumerator *pathEnum = [allFilePaths objectEnumerator];
  NSString *filename;
  if ((filename = [pathEnum nextObject])) {
    // seed our collecting w/ the first item
    NSString *currentFolder = [filename stringByDeletingLastPathComponent];
    NSMutableArray *currentFileList =
      [NSMutableArray arrayWithObject:[filename lastPathComponent]];

    // now spin the loop
    while ((filename = [pathEnum nextObject])) {
      // see if it has the same parent folder
      if ([[filename stringByDeletingLastPathComponent] isEqualTo:currentFolder]) {
        // add it
        NSAssert([currentFileList count] > 0, @"file list should NOT be empty");
        [currentFileList addObject:[filename lastPathComponent]];
      } else {
        // process what's in the list
        if (![self processCoverageForFiles:currentFileList
                                  inFolder:currentFolder]) {
          NSString *message =
            [NSString stringWithFormat:@"failed to process files: %@",
             currentFileList];
          [self addMessageFromThread:message path:currentFolder
                         messageType:kCSMessageTypeError];
        }
        // restart the collecting w/ this filename
        currentFolder = [filename stringByDeletingLastPathComponent];
        [currentFileList removeAllObjects];
        [currentFileList addObject:[filename lastPathComponent]];
      }

      // Bail if we get closed
      if ([self isClosed]) {
        [pool release];
        return YES;
      }
    }
    // process whatever what we were collecting when we hit the end
    if (![self processCoverageForFiles:currentFileList
                              inFolder:currentFolder]) {
      NSString *message =
        [NSString stringWithFormat:@"failed to process files: %@",
         currentFileList];
      [self addMessageFromThread:message
                            path:currentFolder
                     messageType:kCSMessageTypeError];
    }
  }
  [pool release];
  return YES;
}

- (NSString *)tempDirName {
  // go w/ temp dir if anything goes wrong
  NSString *result = NSTemporaryDirectory();
  // throw a guid on it so if we're scanning >1 place at a time, each gets
  // it's own sandbox.
  CFUUIDRef uuidRef = CFUUIDCreate(NULL);
  if (uuidRef) {
    CFStringRef uuidStr = CFUUIDCreateString(NULL, uuidRef);
    if (uuidStr) {
      result = [result stringByAppendingPathComponent:(NSString*)uuidStr];
      CFRelease(uuidStr);
    } else {
      NSLog(@"failed to convert our CFUUIDRef into a CFString");
    }
    CFRelease(uuidRef);
  } else {
    NSLog(@"failed to generate a CFUUIDRef");
  }
  return result;
}

#if USE_NSOPERATION
- (void)cleanupTempDir:(NSString *)tempDir {
  @try {
    // nuke our temp dir tree
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm removeFileAtPath:tempDir handler:nil]) {
      [self addMessageFromThread:@"failed to remove our tempdir"
                            path:tempDir
                     messageType:kCSMessageTypeError];
    }
  }
  @catch (NSException * e) {
    NSString *msg
      = [NSString stringWithFormat:@"Internal error trying to cleanup tempdir (%@ - %@).",
         [e name], [e reason]];
    [self addMessageFromThread:msg messageType:kCSMessageTypeError];
  }
}

- (void)loadCoveragePath:(NSString *)fullPath {
  @try {
    // load it and add it to our set
    CoverStoryCoverageFileData *fileData
      = [CoverStoryCoverageFileData coverageFileDataFromPath:fullPath
                                             messageReceiver:self];
    if (fileData) {
      [self performSelectorOnMainThread:@selector(addFileData:)
                             withObject:fileData
                          waitUntilDone:NO];
    }
  }
  @catch (NSException * e) {
    NSString *msg
      = [NSString stringWithFormat:@"Internal error trying load coverage data (%@ - %@).",
         [e name], [e reason]];
    [self addMessageFromThread:msg messageType:kCSMessageTypeError];
  }
}
#endif

- (BOOL)processCoverageForFiles:(NSArray *)filenames
                       inFolder:(NSString *)folderPath {

  if (([filenames count] == 0) || ([folderPath length] == 0)) {
    return NO;
  }

  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  NSString *tempDir = [self tempDirName];
  NSEnumerator *fileNamesEnum = [filenames objectEnumerator];
  NSString *filename;
  // make sure all the filenames are just leaves
  while ((filename = [fileNamesEnum nextObject])) {
    NSRange range = [filename rangeOfString:@"/"];
    if (range.location != NSNotFound) {
      [self addMessageFromThread:@"skipped because filename had a slash"
                            path:[folderPath stringByAppendingPathComponent:filename]
                     messageType:kCSMessageTypeError];
      [pool release];
      return NO;
    }
  }

  // make sure it ends in a slash
  if (![folderPath hasSuffix:@"/"]) {
    folderPath = [folderPath stringByAppendingString:@"/"];
  }
  
  // Figure out what version of gcov to use.
  // NOTE: To be 100% correct, we should check *each* file and split them into
  // sets based on what version of gcov will be invoked.  But we're assuming
  // most people will only set the gcc version of a per Xcode target level (at
  // the lowest).
  GCovVersionManager *gcovVerMgr = [GCovVersionManager defaultManager];
  NSString *aFullPath =
    [folderPath stringByAppendingPathComponent:[filenames objectAtIndex:0]];
  NSString *gcovPath = [gcovVerMgr gcovForGCovFile:aFullPath];

  // we write all the full file paths into a file w/ null chars after each
  // so we can feed it into xargs -0
  NSMutableData *fileList = [NSMutableData data];
  NSData *folderPathUTF8 = [folderPath dataUsingEncoding:NSUTF8StringEncoding];
  if (!folderPathUTF8 || !fileList) {
    [pool release];
    return NO;
  }
  char nullByte = 0;
  fileNamesEnum = [filenames objectEnumerator];
  while ((filename = [fileNamesEnum nextObject])) {
    NSData *filenameUTF8 = [filename dataUsingEncoding:NSUTF8StringEncoding];
    if (!filenameUTF8) {
      [pool release];
      return NO;
    }
    [fileList appendData:folderPathUTF8];
    [fileList appendData:filenameUTF8];
    [fileList appendBytes:&nullByte length:1];
  }

  GTMScriptRunner *runner = [GTMScriptRunner runnerWithBash];
  if (!runner) {
    [pool release];
    return NO;
  }

  BOOL result = NO;
  
  // make a scratch directory
  NSFileManager *fm = [NSFileManager defaultManager];
  if ([fm createDirectoryAtPath:tempDir
    withIntermediateDirectories:YES
                     attributes:nil
                          error:NULL]) {
#if USE_NSOPERATION
    // create our cleanup op since it will use the other ops as dependencies
    NSInvocationOperation *cleanupOp
      = [[[NSInvocationOperation alloc] initWithTarget:self
                                              selector:@selector(cleanupTempDir:)
                                                object:tempDir] autorelease];
#endif

    // now write out our file
    NSString *fileListPath = [tempDir stringByAppendingPathComponent:@"filelists.txt"];
    if (fileListPath && [fileList writeToFile:fileListPath atomically:YES]) {
      // run gcov (it writes to current directory, so we cd into our dir first)
      // we use xargs to batch up the files into as few of runs of gcov as
      // possible.  (we could use -P [num_cpus] to do things in parallell)
      NSString *script
        = [NSString stringWithFormat:@"cd \"%@\" && /usr/bin/xargs -0 \"%@\" -l -o \"%@\" < \"%@\"",
           tempDir, gcovPath, folderPath, fileListPath];

      NSString *stdErr = nil;
      NSString *stdOut = [runner run:script standardError:&stdErr];
      if (([stdOut length] == 0) || ([stdErr length] > 0)) {
        // we don't actually care about stdout since it's just the files
        // that did work.
        NSEnumerator *enumerator = [[stdErr componentsSeparatedByString:@"\n"] objectEnumerator];
        NSString *message;
        while ((message = [enumerator nextObject])) {
          NSRange range = [message rangeOfString:@":"];
          NSString *path = nil;
          if (range.length != 0) {
            path = [message substringToIndex:range.location];
            message = [message substringFromIndex:NSMaxRange(range)];
          }
          [self addMessageFromThread:message
                                path:path
                         messageType:kCSMessageTypeError];
        }
      }

      // since we batch process, we might have gotten some data even w/ an error
      // so we check anyways for data

      // collect the gcov files
      NSArray *resultPaths = [fm gtm_filePathsWithExtension:@"gcov"
                                                inDirectory:tempDir];
      NSEnumerator *resultPathsEnum = [resultPaths objectEnumerator];
      NSString *fullPath;
      while ((fullPath = [resultPathsEnum nextObject]) && ![self isClosed]) {
#if USE_NSOPERATION
        NSInvocationOperation *op
          = [[[NSInvocationOperation alloc] initWithTarget:self
                                                  selector:@selector(loadCoveragePath:)
                                                    object:fullPath] autorelease];
        // cleanup can't be done until all our other ops are done
        [cleanupOp addDependency:op];

        // queue it up
        [opQueue_ addOperation:op];
        result = YES;
#else
        // load it and add it to our set
        CoverStoryCoverageFileData *fileData =
          [CoverStoryCoverageFileData coverageFileDataFromPath:fullPath
                                                      document:self
                                               messageReceiver:self];
        if (fileData) {
          [self performSelectorOnMainThread:@selector(addFileData:)
                                 withObject:fileData
                              waitUntilDone:NO];
          result = YES;
        }
#endif
      }
    } else {

      [self addMessageFromThread:@"failed to write out the file lists"
                            path:fileListPath
                     messageType:kCSMessageTypeError];
    }

#if USE_NSOPERATION
    // now put in the cleanup operation
    [opQueue_ addOperation:cleanupOp];
#else
    // nuke our temp dir tree
    NSError *error = nil;
    if (![fm removeItemAtPath:tempDir error:&error]) {
      NSString *message
        = [NSString stringWithFormat:@"failed to remove our tempdir (%@)",
           error];
      [self addMessageFromThread:message
                            path:tempDir
                     messageType:kCSMessageTypeError];
    }
#endif
  }

  [pool release];
  return result;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
  if ([object isEqualTo:sourceFilesController_] &&
      [keyPath isEqualToString:NSSelectionIndexesBinding]) {
    NSArray *selectedObjects = [object selectedObjects];
    CoverStoryCoverageFileData *data = nil;
    if ([selectedObjects count]) {
      data = (CoverStoryCoverageFileData*)[selectedObjects objectAtIndex:0];
    }
    if (data) {
      // Update our scroll bar
      [codeTableView_ setCoverageData:[data lines]];

      // Jump to first missing code block
      [self moveSelection:1];
    }
  } else if ([object isEqualTo:[NSUserDefaultsController sharedUserDefaultsController]]) {
    if ([keyPath isEqualToString:[self valuesKey:kCoverStorySystemSourcesPatternsKey]]) {
      if (hideSDKSources_) {
        // if we're hiding them then update because the pattern changed
        [sourceFilesController_ rearrangeObjects];
      }
    } else if ([keyPath isEqualToString:[self valuesKey:kCoverStoryUnittestSourcesPatternsKey]]) {
      if (hideUnittestSources_) {
        // if we're hiding them then update because the pattern changed
        [sourceFilesController_ rearrangeObjects];
      }
    } else if ([keyPath isEqualToString:[self valuesKey:kCoverStoryRemoveCommonSourcePrefix]]) {
      // we to recalc the common prefix, so trigger a rearrange
      [sourceFilesController_ rearrangeObjects];
    } else {
      NSString *const kColorsToWatch[] = {
        kCoverStoryMissedLineColorKey,
        kCoverStoryUnexecutableLineColorKey,
        kCoverStoryNonFeasibleLineColorKey,
        kCoverStoryExecutedLineColorKey
      };
      for (size_t i = 0; i < sizeof(kColorsToWatch) / sizeof(NSString*); ++i) {
        if ([keyPath isEqualToString:[self valuesKey:kColorsToWatch[i]]]) {
          [codeTableView_ reloadData];
        }
      }
    }
  }
}

- (NSString *)filterString {
  return filterString_;
}

- (void)setFilterString:(NSString *)string {
  if (filterString_ != string) {
    [filterString_ release];
    filterString_ = [string copy];
    [sourceFilesController_ rearrangeObjects];
  }
}

- (void)setFilterStringType:(CoverStoryFilterStringType)type {
  [[NSUserDefaults standardUserDefaults] setInteger:type
                                             forKey:kCoverStoryFilterStringTypeKey];
  [sourceFilesController_ rearrangeObjects];
}

- (IBAction)setUseWildcardPattern:(id)sender {
  [self setFilterStringType:kCoverStoryFilterStringTypeWildcardPattern];
}

- (IBAction)setUseRegularExpression:(id)sender {
  [self setFilterStringType:kCoverStoryFilterStringTypeRegularExpression];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
  typedef struct {
    CoverStoryFilterStringType type;
    SEL selector;
  } FilterSelectorMap;
  FilterSelectorMap map[] = {
    { kCoverStoryFilterStringTypeWildcardPattern, @selector(setUseWildcardPattern:) },
    { kCoverStoryFilterStringTypeRegularExpression, @selector(setUseRegularExpression:) },
  };

  CoverStoryFilterStringType type;
  type = [[NSUserDefaults standardUserDefaults] integerForKey:kCoverStoryFilterStringTypeKey];
  BOOL isGood = NO;
  SEL action = [menuItem action];
  for (size_t i = 0; i <= sizeof(map) / sizeof(FilterSelectorMap); ++i) {
    if (action == map[i].selector) {
      isGood = YES;
      [menuItem setState:map[i].type == type ? NSOnState : NSOffState];
      break;
    }
  }
  if (!isGood) {
    NSInteger tag = [menuItem tag];
    NSString *label = nil;
    if (tag == kCoverStorySDKToolbarTag) {
      if (hideSDKSources_) {
        label = NSLocalizedString(@"Show SDK Source Files", nil);
      } else {
        label = NSLocalizedString(@"Hide SDK Source Files", nil);
      }
    } else if (tag == kCoverStoryUnittestToolbarTag) {
      if (hideUnittestSources_) {
        label = NSLocalizedString(@"Show Unittest Source Files", nil);
      } else {
        label = NSLocalizedString(@"Hide Unittest Source Files", nil);
      }
    }
    if (label) {
      isGood = YES;
      [menuItem setTitle:label];
    }
  }
  if (!isGood) {
    if (action == @selector(saveDocumentTo:)) {
      isGood = [self completelyOpened];
    } else {
      isGood = [super validateMenuItem:menuItem];
    }
  }
  return isGood;
}

// On enter we just want to open the selected lines of source
- (void)tableViewHandleEnter:(NSTableView *)tableView {
  NSAssert(tableView == codeTableView_, @"Unexpected tableView");
  [self openSelectedSource];
}

- (void)moveUpAndModifySelection:(id)sender {
  [self moveSelection:-1];
}

- (void)moveDownAndModifySelection:(id)sender {
  [self moveSelection:1];
}

// On up or down key we want to select the next block of code that has
// zero coverage.
- (void)moveSelection:(NSUInteger)offset {

  // If no source, bail
  NSArray *selection = [sourceFilesController_ selectedObjects];
  if (![selection count]) return;

  // Start with the current selection
  CoverStoryCoverageFileData *fileData = [selection objectAtIndex:0];
  NSArray *lines = [fileData lines];
  NSIndexSet *currentSel = [codeTableView_ selectedRowIndexes];

  // Choose direction based on key and set offset and stopping conditions
  // as well as start.
  NSUInteger stoppingCond = 0;
  NSRange range = NSMakeRange(0, 0);

  if (offset > 0) {
    stoppingCond = [lines count] - 1;
    if ([lines count] == 0) {
      stoppingCond = 0;
    }
  }
  NSUInteger startLine = 0;
  if ([currentSel count]) {
    NSUInteger first = [currentSel firstIndex];
    NSUInteger last = [currentSel lastIndex];
    range = NSMakeRange(first, last - first);
    startLine = offset == 1 ? last : first;
  }

  // From start, look for first line in our given direction that has
  // zero hits
  NSUInteger i;
  for (i = startLine + offset; i != stoppingCond; i += offset) {
    CoverStoryCoverageLineData *lineData = [lines objectAtIndex:i];
    if ([lineData hitCount] == 0) {
      break;
    }
  }

  // Check to see if we hit end of page (or beginning depending which way
  // we went
  if (i != stoppingCond) {
    // Now select "forward" everything that is zero
    NSUInteger j;
    for (j = i; j != stoppingCond; j += offset) {
      CoverStoryCoverageLineData *lineData = [lines objectAtIndex:j];
      if ([lineData hitCount] != 0) {
        break;
      }
    }

    // Now if we started in a block, select "backwards"
    NSUInteger k;
    stoppingCond = offset == 1 ? 0 : [lines count] - 1;
    offset *= -1;
    for (k = i; k != stoppingCond; k+= offset) {
      CoverStoryCoverageLineData *lineData = [lines objectAtIndex:k];
      if ([lineData hitCount] != 0) {
        k -= offset;
        break;
      }
    }

    // Update our selection
    range = k > j ? NSMakeRange(j + 1, k - j) : NSMakeRange(k, j - k);

    [codeTableView_ selectRowIndexes:[NSIndexSet indexSetWithIndexesInRange:range]
                byExtendingSelection:NO];
  }
  [codeTableView_ scrollRowToVisible:NSMaxRange(range)];
  [codeTableView_ scrollRowToVisible:range.location];
}


- (void)setSortKeyOfTableView:(NSTableView *)tableView
                       column:(NSString *)columnName
                           to:(NSString *)sortKeyName {
  NSTableColumn *column = [tableView tableColumnWithIdentifier:columnName];
  NSSortDescriptor *oldDesc = [column sortDescriptorPrototype];
  NSSortDescriptor *descriptor
    = [[[NSSortDescriptor alloc] initWithKey:sortKeyName
                                   ascending:[oldDesc ascending]] autorelease];
  [column setSortDescriptorPrototype:descriptor];
}

- (void)reloadData:(id)sender {
  if (openingInThread_) {
    // starting a reload keeps pushing to the existing data, so block it until
    // we're done.
    [self addMessageFromThread:@"Still loading data, can't start a reload."
                   messageType:kCSMessageTypeWarning];
    return;
  }
  [self willChangeValueForKey:@"dataSet_"];
  [dataSet_ release];
  dataSet_ = [[CoverStoryCoverageSet alloc] init];
  [self didChangeValueForKey:@"dataSet_"];

  // clear the message view before we start
  // add the message, color, and scroll
  [messageView_ setString:@""];

  NSError *error = nil;
  if (![self readFromURL:[self fileURL]
                  ofType:[self fileType]
                   error:&error]) {
    [self addMessageFromThread:@"couldn't reload file"
                          path:[[self fileURL] path]
                   messageType:kCSMessageTypeError];
  }
}

- (IBAction)toggleMessageDrawer:(id)sender {
  [drawer_ toggle:self];
}

- (void)setCommonPathPrefix:(NSString *)newPrefix {
  [commonPathPrefix_ autorelease];
  // we cheat, and if the pref is set, we just make sure we return no prefix
  if ([[NSUserDefaults standardUserDefaults] boolForKey:kCoverStoryRemoveCommonSourcePrefix]) {
    commonPathPrefix_ = [newPrefix copy];
  } else {
    commonPathPrefix_ = nil;
  }
}

- (NSString *)commonPathPrefix {
  return commonPathPrefix_;
}

// Moves our searchfield to display our spinner and starts it spinning.
// Called as a performSelectorOnMainThread, so must check to make sure
// we haven't been closed.
- (void)displayAndAnimateSpinner:(NSNumber*)start {
  if ([self isClosed]) return;
  if (spinner_) {
    // force any running animation to end
    if (currentAnimation_) {
      [currentAnimation_ stopAnimation];
      [currentAnimation_ release];
      currentAnimation_ = nil;
    }
    BOOL starting = [start boolValue];
    NSString *effect;
    NSRect rect = [searchField_ frame];
    if (starting) {
      rect.origin.x += animationWidth_;
      rect.size.width -= animationWidth_;
      effect = NSViewAnimationFadeInEffect;
    } else {
      rect.origin.x -= animationWidth_;
      rect.size.width += animationWidth_;
      effect = NSViewAnimationFadeOutEffect;
    }
    NSValue *endFrameRectValue = [NSValue valueWithRect:rect];
    NSDictionary *searchAnimation = [NSDictionary dictionaryWithObjectsAndKeys:
                                     searchField_, NSViewAnimationTargetKey,
                                     endFrameRectValue, NSViewAnimationEndFrameKey,
                                     nil];
    NSDictionary *spinnerAnimation = [NSDictionary dictionaryWithObjectsAndKeys:
                                      spinner_, NSViewAnimationTargetKey,
                                      effect, NSViewAnimationEffectKey,
                                      nil];

    NSArray *animations;
    if (starting) {
      animations = [NSArray arrayWithObjects:
                    searchAnimation,
                    spinnerAnimation,
                    nil];
    } else {
      animations = [NSArray arrayWithObjects:
                    spinnerAnimation,
                    searchAnimation,
                    nil];
    }
    currentAnimation_ =
      [[NSViewAnimation alloc] initWithViewAnimations:animations];
    [currentAnimation_ setDelegate:self];
    [currentAnimation_ startAnimation];
    if (starting) {
      [spinner_ startAnimation:self];
    } else {

      [spinner_ stopAnimation:self];
    }
  }
}

- (void)animationDidEnd:(NSAnimation *)animation {
  if (animation == currentAnimation_) {
    // clear out our reference
    [currentAnimation_ release];
    currentAnimation_ = nil;
  }
}

- (void)finishedLoadingFileDatas:(id)ignored {
  if (numFileDatas_ == 0) {
    [self addMessageFromThread:@"No coverage data read."
                   messageType:kCSMessageTypeWarning];
  } else {
    if (numFileDatas_ == 1) {
      [self addMessageFromThread:@"Loaded one file of coverage data."
                     messageType:kCSMessageTypeInfo];
    } else {
      NSString *message =
        [NSString stringWithFormat:@"Successfully loaded %u coverage fragments.",
         numFileDatas_];
      [self addMessageFromThread:message
                     messageType:kCSMessageTypeInfo];
    }
    NSInteger totalLines = 0;
    NSInteger codeLines = 0;
    NSInteger hitLines = 0;
    NSInteger nonfeasible = 0;
    NSString *coverage = nil;
    [dataSet_ coverageTotalLines:&totalLines
                       codeLines:&codeLines
                    hitCodeLines:&hitLines
                nonFeasibleLines:&nonfeasible
                  coverageString:&coverage
                        coverage:NULL];
    NSString *summary = nil;
    if (nonfeasible > 0) {
      summary = [NSString stringWithFormat:
                 @"Full dataset executed %@%% of %d lines (%d executed, "
                 @"%d executable, %d non-feasible, %d total lines).",
                 coverage, codeLines, hitLines, codeLines, nonfeasible,
                 totalLines];
    } else {
      summary = [NSString stringWithFormat:
                 @"Full dataset executed %@%% of %d lines (%d executed, "
                 @"%d executable, %d total lines).",
                 coverage, codeLines, hitLines, codeLines, totalLines];
    }
    [self addMessageFromThread:summary
                   messageType:kCSMessageTypeInfo];
    [self addMessageFromThread:@"There is a tooltip on the total above the file"
                               @" list that shows numbers for the currently"
                               @" displayed set."
                   messageType:kCSMessageTypeInfo];
  }
#if DEBUG
  if (startDate_) {
    NSTimeInterval elapsed = -[startDate_ timeIntervalSinceNow];
    UInt32 secs = (UInt32)elapsed % 60;
    UInt32 mins = ((UInt32)elapsed / 60) % 60;
    NSString *elapsedStr
      = [NSString stringWithFormat:@"It took %u:%02u to process the data.",
         mins, secs];
    [self addMessageFromThread:elapsedStr messageType:kCSMessageTypeInfo];
  }
#endif  // DEBUG
}

- (void)setOpenThreadState:(BOOL)threadRunning {
  openingInThread_ = threadRunning;
  [self performSelectorOnMainThread:@selector(displayAndAnimateSpinner:)
                         withObject:[NSNumber numberWithBool:openingInThread_]
                      waitUntilDone:NO];
}

- (BOOL)completelyOpened {
  return !openingInThread_;
}

- (void)addMessageFromThread:(NSString *)message
                 messageType:(CSMessageType)msgType {
  NSDictionary *messageInfo =
    [NSDictionary dictionaryWithObjectsAndKeys:
     message, @"message",
     [NSNumber numberWithInt:msgType], @"msgType",
     nil];
  [self performSelectorOnMainThread:@selector(addMessage:)
                         withObject:messageInfo
                      waitUntilDone:NO];
}

- (void)addMessageFromThread:(NSString *)message
                        path:(NSString*)path
                 messageType:(CSMessageType)msgType {
  NSString *pathMessage = [NSString stringWithFormat:@"%@:%@", path, message];
  [self addMessageFromThread:pathMessage messageType:msgType];
}

- (void)coverageErrorForPath:(NSString*)path message:(NSString *)format, ... {
  // we use the data objects on other threads, so bounce to the main thread

  va_list list;
  va_start(list, format);
  NSString *message = [[NSString alloc] initWithFormat:format arguments:list];
  va_end(list);
  [self addMessageFromThread:message path:path messageType:kCSMessageTypeError];
}

- (void)coverageWarningForPath:(NSString*)path message:(NSString *)format, ... {
  // we use the data objects on other threads, so bounce to the main thread

  va_list list;
  va_start(list, format);
  NSString *message = [[NSString alloc] initWithFormat:format arguments:list];
  va_end(list);
  [self addMessageFromThread:message path:path messageType:kCSMessageTypeWarning];
}

- (void)close {
  documentClosed_ = YES;
  [super close];
}

- (BOOL)isClosed {
  return documentClosed_;
}

- (void)setHideSDKSources:(BOOL)hide {
  hideSDKSources_ = hide;
  [sourceFilesController_ rearrangeObjects];
}

- (void)setHideUnittestSources:(BOOL)hide {
  hideUnittestSources_ = hide;
  [sourceFilesController_ rearrangeObjects];
}

- (BOOL)hideSDKSources {
  return hideSDKSources_;
}

- (BOOL)hideUnittestSources {
  return hideUnittestSources_;
}

- (IBAction)toggleSDKSourcesShown:(id)sender {
  [self setHideSDKSources:![self hideSDKSources]];
}

- (IBAction)toggleUnittestSourcesShown:(id)sender {
  [self setHideUnittestSources:![self hideUnittestSources]];
}

-(BOOL)validateToolbarItem:(NSToolbarItem *)theItem {
  NSInteger tag = [theItem tag];
  BOOL value = NO;
  NSString *label = nil;
  NSString *iconName = nil;
  if (tag == kCoverStorySDKToolbarTag) {
    value = hideSDKSources_;
    label = NSLocalizedString(@"SDK Files", nil);
    iconName = @"SDK";
  } else if (tag == kCoverStoryUnittestToolbarTag) {
    value = hideUnittestSources_;
    label = NSLocalizedString(@"Unittest Files", nil);
    iconName = @"UnitTests";
  }
  if (label) {
    NSString *fullLabel = nil;
    NSString *fullIcon = nil;
    if (value) {
      fullLabel
        = [NSString stringWithFormat:GTMLocalizedString(@"Show %@", nil),
           label];
      fullIcon = [NSString stringWithFormat:@"%@", iconName];
    } else {
      fullLabel
        = [NSString stringWithFormat:GTMLocalizedString(@"Hide %@", nil),
           label];
      fullIcon = [NSString stringWithFormat:@"%@Hide", iconName];
    }
    [theItem setLabel:fullLabel];
    NSImage *image = [NSImage imageNamed:fullIcon];
    [theItem setImage:image];
  }
  return YES;
}

// Called as a performSelectorOnMainThread, so must check to make sure
// we haven't been closed.
- (void)addMessage:(NSDictionary *)msgInfo {
  if ([self isClosed]) return;

  NSString *message = [msgInfo objectForKey:@"message"];
  CSMessageType msgType = [[msgInfo objectForKey:@"msgType"] intValue];
  if (message) {
    // for non-info make sure the drawer is open
    if (msgType != kCSMessageTypeInfo) {
      [drawer_ open];
    }

    // make sure it ends in a newline
    if (![message hasSuffix:@"\n"]) {
      message = [message stringByAppendingString:@"\n"];
    }

    // add the message, color, and scroll
    size_t length = [[messageView_ string] length];
    NSRange appendRange = NSMakeRange(length, 0);
    NSTextAttachment *icon = nil;
    NSColor *textColor = nil;
    switch (msgType) {
      case kCSMessageTypeError:
        icon = errorIcon_;
        textColor = [NSColor redColor];
        break;
      case kCSMessageTypeWarning:
        icon = warningIcon_;
        textColor = [NSColor orangeColor];
        break;
      case kCSMessageTypeInfo:
        icon = infoIcon_;
        textColor = [NSColor blackColor];
        break;
    }
    NSMutableAttributedString *attrIconAndMessage
      = [[[NSAttributedString attributedStringWithAttachment:icon] mutableCopy] autorelease];
    NSAttributedString *attrMessage = [[[NSAttributedString alloc] initWithString:message] autorelease];
    [attrIconAndMessage appendAttributedString:attrMessage];

    NSMutableParagraphStyle *paraStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
    [paraStyle setFirstLineHeadIndent:0];
    [paraStyle setHeadIndent:12];
    NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
                           textColor, NSForegroundColorAttributeName,
                           paraStyle, NSParagraphStyleAttributeName,
                           nil];

    [attrIconAndMessage addAttributes:attrs range:NSMakeRange(0, [attrMessage length])];
    NSTextStorage *storage = [messageView_ textStorage];
    [storage replaceCharactersInRange:appendRange withAttributedString:attrIconAndMessage];
    if (msgType != kCSMessageTypeInfo) {  // only scroll to the warnings/errors
      NSRange visibleRange = NSMakeRange(appendRange.location, [attrIconAndMessage length]);
      [messageView_ scrollRangeToVisible:visibleRange];
    }
    [messageView_ display];
  }
}

- (NSString *)htmlFileListTableData {
  NSArray *fileDatas = [sourceFilesController_ arrangedObjects];
  NSMutableString *filesHtml = [NSMutableString string];
  struct {
    CGFloat value;
    NSString *classString;
  } percentClassMap[] = {
    { 25., @"filelessthan25percent" },
    { 35., @"filelessthan35percent" },
    { 45., @"filelessthan45percent" },
    { 55., @"filelessthan55percent" },
    { 65., @"filelessthan65percent" },
    { 75., @"filelessthan75percent" },
  };
  for (CoverStoryCoverageFileData *fileData in fileDatas) {
    NSString *name
      = [[[fileData sourcePath] lastPathComponent] gtm_stringByEscapingForHTML];
    NSString *link = [name stringByAppendingPathExtension:@"html"];
    float percent;
    [fileData coverageTotalLines:NULL
                       codeLines:NULL
                    hitCodeLines:NULL
                nonFeasibleLines:NULL
                  coverageString:NULL
                        coverage:&percent];

    NSString *classString = @"filegoodcoveragepercent";
    for (size_t i = 0;
         i < sizeof(percentClassMap) / sizeof(percentClassMap[0]);
         ++i) {
      if (percent < percentClassMap[i].value) {
        classString = percentClassMap[i].classString;
        break;
      }
    }
    [filesHtml appendFormat:
     @"<tr class='fileline'>\n"
     @"<td class='filename'><a href='%@'>%@</a></td>\n"
     @"<td class='filepercent'><span class='%@'>%.2f</span></td>\n"
     @"</tr>\n", link, name, classString, percent];
  }
  return filesHtml;
}

- (NSString *)htmlSourceTableData:(CoverStoryCoverageFileData*)fileData {
  unichar nbsp = 0xA0;
  NSString *tabReplacement = [NSString stringWithFormat:@"%C ", nbsp];
  NSMutableString *sourceHtml = [NSMutableString string];
  for (CoverStoryCoverageLineData *line in [fileData lines]) {
    NSString *lineSource = [line line];
    lineSource
      = [lineSource stringByReplacingOccurrencesOfString:@"\t"
                                              withString:tabReplacement];
    lineSource
      = [lineSource stringByReplacingOccurrencesOfString:@"  "
                                              withString:tabReplacement];
    lineSource = [lineSource gtm_stringByEscapingForHTML];
    NSInteger hitCount = [line hitCount];
    NSString *hitCountString = nil;
    NSString *hitStyle = @"sourcelinehit";
    if (hitCount == kCoverStoryNotExecutedMarker) {
      hitStyle = @"sourcelineskipped";
      hitCountString = @"";
    } else if (hitCount == kCoverStoryNonFeasibleMarker) {
      hitStyle = @"sourcelinenonfeasible";
      hitCountString = @"";
    } else if (hitCount == 0) {
      hitStyle = @"sourcelinemissed";
    }
    if (!hitCountString) {
      hitCountString = [NSString stringWithFormat:@"%d", hitCount];
    }
    [sourceHtml appendFormat:
     @"<tr class='sourceline'>\n"
     @"<td class='sourcelinehitcount'>%@</td>\n"
     @"<td class='%@'>%@</td>\n"
     @"</tr>\n", hitCountString, hitStyle, lineSource];
  }
  return sourceHtml;
}

- (NSFileWrapper *)fileWrapperOfType:(NSString *)typeName
                               error:(NSError **)outError {
  NSString *fileList = [self htmlFileListTableData];
  NSArray *fileDatas = [sourceFilesController_ arrangedObjects];
  NSValueTransformer *transformer
    = [NSValueTransformer valueTransformerForName:@"LineCoverageToCoverageShortSummaryTransformer"];
  NSString *summary = [transformer transformedValue:fileDatas];
  summary = [summary gtm_stringByEscapingForHTML];
  transformer
    = [NSValueTransformer valueTransformerForName:@"FileLineCoverageToCoverageSummaryTransformer"];

  NSFileWrapper *finalWrapper
    = [[[NSFileWrapper alloc] initDirectoryWithFileWrappers:nil] autorelease];
  NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
  [formatter setDateStyle:kCFDateFormatterShortStyle];
  [formatter setTimeStyle:kCFDateFormatterShortStyle];
  NSString *date = [formatter stringFromDate:[NSDate date]];
  date = [date gtm_stringByEscapingForHTML];
  NSString *redirectURL = nil;
  for (CoverStoryCoverageFileData *fileData in fileDatas) {
    NSString *sourcePath = [fileData sourcePath];
    NSString *fileName = [sourcePath lastPathComponent];
    NSString *htmlFileName = [fileName stringByAppendingPathExtension:@"html"];
    NSString *coverageString = [transformer transformedValue:fileData];
    sourcePath = [sourcePath gtm_stringByEscapingForHTML];
    fileName = [fileName gtm_stringByEscapingForHTML];
    coverageString = [coverageString gtm_stringByEscapingForHTML];
    NSString *sourceHTML = [self htmlSourceTableData:fileData];
    NSString *htmlString
      = [NSString stringWithFormat:GTMLocalizedStringFromTable(@"HTMLExportTemplate",
                                                               @"HTMLExport", @""),
         fileName, fileName, sourcePath, date, summary, fileList,
         coverageString, sourceHTML];
    NSData *data = [htmlString dataUsingEncoding:NSUTF8StringEncoding];
    [finalWrapper addRegularFileWithContents:data
                           preferredFilename:htmlFileName];
    if (!redirectURL) {
      redirectURL = [NSString stringWithFormat:@"./%@", htmlFileName];
    }
  }
  if (redirectURL) {
    NSString *indexHTML
      = [NSString stringWithFormat:GTMLocalizedStringFromTable(@"HTMLIndexTemplate",
                                                               @"HTMLIndex", @""),
         redirectURL];
    NSData *indexData = [indexHTML dataUsingEncoding:NSUTF8StringEncoding];
    [finalWrapper addRegularFileWithContents:indexData
                           preferredFilename:@"index.html"];
  }
  NSString *cssPath = [[NSBundle mainBundle] pathForResource:@"coverstory"
                                                      ofType:@"css"];
  NSError *error = nil;
  NSString *cssString = [NSString stringWithContentsOfFile:cssPath
                                                  encoding:NSUTF8StringEncoding
                                                     error:&error];
  if (error) {
    [NSApp presentError:error];
  }
  if (cssString) {
    NSUserDefaultsController *defaults
      = [NSUserDefaultsController sharedUserDefaultsController];
    id values = [defaults values];
    struct {
      NSString *defaultName;
      NSString *replacee;
    } sourceLineColorMap[] = {
      { kCoverStoryMissedLineColorKey, @"$$SOURCE_LINE_MISSED_COLOR$$" },
      { kCoverStoryUnexecutableLineColorKey, @"$$SOURCE_LINE_SKIPPED_COLOR$$" },
      { kCoverStoryNonFeasibleLineColorKey, @"$$SOURCE_LINE_NONFEASIBLE_COLOR$$" },
      { kCoverStoryExecutedLineColorKey, @"$$SOURCE_LINE_HIT_COLOR$$" }
    };

    for (size_t i = 0;
         i < sizeof(sourceLineColorMap) / sizeof(sourceLineColorMap[0]);
         ++i) {
      NSData *colorData
        = [values valueForKey:sourceLineColorMap[i].defaultName];
      NSColor *color = nil;
      if (colorData) {
        color = (NSColor *)[NSUnarchiver unarchiveObjectWithData:colorData];
      }
      if (!color) {
        color = [NSColor blackColor];
      }
      color = [color colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
      CGFloat components[4];
      [color getComponents:components];
      int redInt = (int)(components[0] * 255);
      int greenInt = (int)(components[1] * 255);
      int blueInt = (int)(components[2] * 255);
      NSString *newColor
        = [NSString stringWithFormat:@"#%02X%02X%02X", redInt, greenInt, blueInt];
      NSString *replacee = sourceLineColorMap[i].replacee;
      cssString = [cssString stringByReplacingOccurrencesOfString:replacee
                                                       withString:newColor];
    }
    NSData *cssData = [cssString dataUsingEncoding:NSUTF8StringEncoding];
    [finalWrapper addRegularFileWithContents:cssData
                           preferredFilename:@"coverstory.css"];
  }
  NSString *jsPath = [[NSBundle mainBundle] pathForResource:@"coverstory"
                                                     ofType:@"js"];
  NSData *jsData = [NSData dataWithContentsOfFile:jsPath];
  [finalWrapper addRegularFileWithContents:jsData
                         preferredFilename:@"coverstory.js"];
  return finalWrapper;
}

- (id)handleExportHTMLScriptCommand:(NSScriptCommand *)command {
  NSURL *url = [[command arguments] objectForKey:@"File"];
  NSError *error = nil;
  if (![self writeToURL:url ofType:@"Folder" error:&error]) {
    [command setScriptErrorNumber:(int)[error code]];
    [command setScriptErrorString:[error localizedDescription]];
  }
  return nil;
}
@end

@implementation NSTableView (CoverStoryTableView)
- (void)cs_setValueTransformerOfColumn:(NSString *)columnName
                                    to:(NSString *)transformerName {
  NSTableColumn *column = [self tableColumnWithIdentifier:columnName];
  NSAssert1(column, @"No %@ column?", columnName);
  NSDictionary *bindingInfo = [column infoForBinding:NSValueBinding];
  NSAssert1(bindingInfo, @"No binding Info for column %@", columnName);
  [column unbind:NSValueBinding];
  NSMutableDictionary *bindingOptions = [[[bindingInfo objectForKey:NSOptionsKey] mutableCopy] autorelease];
  [bindingOptions setObject:transformerName
                     forKey:NSValueTransformerNameBindingOption];
  [bindingOptions setObject:[NSValueTransformer valueTransformerForName:transformerName]
                     forKey:NSValueTransformerBindingOption];
  [column bind:NSValueBinding
      toObject:[bindingInfo objectForKey:NSObservedObjectKey]
   withKeyPath:[bindingInfo objectForKey:NSObservedKeyPathKey]
       options:bindingOptions];
}

- (void)cs_setSortKeyOfColumn:(NSString *)columnName
                           to:(NSString *)sortKeyName {
  NSTableColumn *column = [self tableColumnWithIdentifier:columnName];
  NSAssert1(column, @"No %@ column?", columnName);
  NSSortDescriptor *oldDesc = [column sortDescriptorPrototype];
  BOOL ascending = oldDesc ? [oldDesc ascending] : YES;
  NSSortDescriptor *descriptor = [[[NSSortDescriptor alloc] initWithKey:sortKeyName
                                                              ascending:ascending]  autorelease];
  [column setSortDescriptorPrototype:descriptor];
}

- (void)cs_setHeaderOfColumn:(NSString*)columnName
                          to:(NSString*)name {
  NSTableColumn *column = [self tableColumnWithIdentifier:columnName];
  NSAssert1(column, @"No %@ column?", columnName);
  [[column headerCell] setTitle:name];
}
@end

@implementation CoverStoryArrayController
- (void)updateCommonPathPrefix {
  if (!owningDocument_) return;

  NSString *newPrefix = nil;

  // now figure out a new prefix
  NSArray *arranged = [self arrangedObjects];
  if ([arranged count] == 0) {
    // empty string
    newPrefix = @"";
  } else {
    // process the list to find the common prefix

    // start w/ the first path, and now loop throught them all, but give up
    // the moment he only common prefix is "/"
    NSArray *sourcePaths = [arranged valueForKey:@"sourcePath"];
    NSEnumerator *enumerator = [sourcePaths objectEnumerator];
    newPrefix = [enumerator nextObject];
    NSString *basePath;
    while (([newPrefix length] > 1) &&
           (basePath = [enumerator nextObject])) {
      newPrefix = [newPrefix commonPrefixWithString:basePath
                                            options:NSLiteralSearch];
    }
    // if you have two files of:
    //   /Foo/bar/spam.m
    //   /Foo/baz/wee.m
    // we end up here w/ "/Foo/ba" as the common prefix, but we don't want
    // to do that, so we make sure we end in a slash
    if (![newPrefix hasSuffix:@"/"]) {
      NSRange lastSlash = [newPrefix rangeOfString:@"/"
                                           options:NSBackwardsSearch];
      if (lastSlash.location == NSNotFound) {
        newPrefix = @"";
      } else {
        newPrefix = [newPrefix substringToIndex:NSMaxRange(lastSlash)];
      }
    }
    // if we just have the leading "/", use no prefix
    if ([newPrefix length] <= 1) {
      newPrefix = @"";
    }
  }
  // send it back to the document
  [owningDocument_ setCommonPathPrefix:newPrefix];
}

- (void)rearrangeObjects {
  // this fires when the filtering changes
  [super rearrangeObjects];
  [self updateCommonPathPrefix];
}
- (void)setContent:(id)content {
  // this fires as results are added during a load
  [super setContent:content];
  [self updateCommonPathPrefix];
}
@end

@implementation NSWindow (CoverStoryExportToHTML)
- (id)cs_handleExportHTMLScriptCommand:(NSScriptCommand *)command {
  id directParameter = [command evaluatedReceivers];
  CoverStoryDocument *document = (CoverStoryDocument *)[directParameter document];
  id value = nil;
  if ([document isMemberOfClass:[CoverStoryDocument class]]) {
    value = [document handleExportHTMLScriptCommand:command];
  } else {
    [command setScriptErrorNumber:errAECantHandleClass];
  }
  return value;
}
@end
