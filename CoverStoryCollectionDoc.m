//
//  CoverStoryCollectionDoc.m
//  CoverStory
//
//  Created by thomasvl on 2/26/08.
//  Copyright 2008 Google Inc.
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

#import "CoverStoryCollectionDoc.h"
#import "CoverStoryCoverageData.h"
#import "GTMScriptRunner.h"
#import "GTMNSFileManager+Path.h"
#import "GTMNSEnumerator+Filter.h"
#import "CoverStoryDocument.h"

@interface CoverStoryCollectionDoc (PrivateMethods)
- (BOOL)processCoverageForFolder:(NSString *)path;
- (BOOL)processCoverageForFiles:(NSArray *)filenames
                       inFolder:(NSString *)folderPath;
@end

@implementation CoverStoryCollectionDoc
- (id)init {
  self = [super init];
  if (self) {
    dataSet_ = [[CoverStoryCoverageSet alloc] init];
  }
  return self;
}

- (void)dealloc {
  [dataSet_ release];
  [sourceList_ release];
  [super dealloc];
}

- (NSString *)windowNibName {
  return @"CoverStoryCollectionDoc";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController {
  // Now that our nib is loaded, finish our setup
  
  // fetch the sorted list of files
  [sourceList_ autorelease];
  sourceList_ =
   [[[dataSet_ sourcePaths] sortedArrayUsingSelector:@selector(compare:)] retain];
  
  // wire up double click
  [codeList_ setTarget:self];
  [codeList_ setDoubleAction:@selector(doubleClickRow:)];
  
  // fill in the states
  SInt32 totalLines = [dataSet_ numberTotalLines];
  SInt32 hitLines   = [dataSet_ numberHitCodeLines];
  SInt32 codeLines  = [dataSet_ numberCodeLines];
  SInt32 nonfeasible  = [dataSet_ numberNonFeasibleLines];
  NSString *statString = nil;
  if (nonfeasible) {
    statString = [NSString stringWithFormat:
      @"Executed %.2f%% of %d lines (%d executed, %d executable, %d non-feasible, %d total lines)", 
        [dataSet_ coverage], codeLines, hitLines, codeLines, nonfeasible, totalLines];
  } else {
    statString = [NSString stringWithFormat:
      @"Executed %.2f%% of %d lines (%d executed, %d executable, %d total lines)", 
        [dataSet_ coverage], codeLines, hitLines, codeLines, totalLines];
  }
  [statistics_ setStringValue:statString];
}

- (BOOL)readFromFileWrapper:(NSFileWrapper *)fileWrapper
                     ofType:(NSString *)typeName
                      error:(NSError **)outError {
  
  if ([fileWrapper isDirectory]) {
    // the wrapper doesn't have the full path, but it's already set on us, so
    // use that instead.
    NSString *path = [self fileName];
    return [self processCoverageForFolder:path];
  }

  // the wrapper doesn't have the full path, but it's already set on us, so use
  // that instead.
  NSString *fullPath = [self fileName];
  NSString *folderPath = [fullPath stringByDeletingLastPathComponent];
  NSString *filename = [fullPath lastPathComponent];
  return [self processCoverageForFiles:[NSArray arrayWithObject:filename]
                              inFolder:folderPath];
}

- (int)numberOfRowsInTableView:(NSTableView *)tableView {
  return [sourceList_ count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn 
            row:(int)row {
  NSString *sourcePath = [sourceList_ objectAtIndex:row];
  return [dataSet_ fileDataForSourcePath:sourcePath];
}

- (IBAction)doubleClickRow:(id)sender {
  int row = [codeList_ selectedRow];
  NSString *sourcePath = [sourceList_ objectAtIndex:row];
  CoverStoryCoverageFileData *fileData =
  [dataSet_ fileDataForSourcePath:sourcePath];
  NSDocumentController *dc = [NSDocumentController sharedDocumentController];
  // first see if we already have a document for this source doc
  NSDocument *doc = [dc documentForFileName:sourcePath];
  if (doc) {
    // raise the window(s)
    [doc showWindows];
    // do we need to worry about two coverage samples open w/ the same file, and
    // only getting one of them open because of this?
  } else {
    // not found, create one
    CoverStoryDocument *doc = [dc makeUntitledDocumentOfType:@"gcov File" error:nil];
    if (doc) {
      [doc setFileData:fileData];
      [doc setFileName:sourcePath]; // to give it something other then untitled...
      [dc addDocument:doc];
      [doc makeWindowControllers];
      [doc showWindows];
    }
  }
}

- (BOOL)isDocumentEdited {
  return NO;
}

@end

@implementation CoverStoryCollectionDoc (PrivateMethods)

- (BOOL)processCoverageForFolder:(NSString *)path {
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

  // we want to back process them by chunks w/in a given directory.  so sort
  // and then break them off into chunks.
  allFilePaths = [allFilePaths sortedArrayUsingSelector:@selector(compare:)];
  if ([allFilePaths count] >= 0) {

    // see our collecting w/ the first item
    NSString *filename = [allFilePaths objectAtIndex:0];
    NSString *currentFolder = [filename stringByDeletingLastPathComponent];
    NSMutableArray *currentFileList =
      [NSMutableArray arrayWithObject:[filename lastPathComponent]];

    // now spin the loop
    for (int x = 1 ; x < [allFilePaths count] ; ++x) {
      NSString *filename = [allFilePaths objectAtIndex:x];
      // see if it has the same parent folder
      if ([[filename stringByDeletingLastPathComponent] isEqualTo:currentFolder]) {
        // add it
        NSAssert([currentFileList count] > 0, @"file list should NOT be empty");
        [currentFileList addObject:[filename lastPathComponent]];
      } else {
        // process what's in the list
        if (![self processCoverageForFiles:currentFileList
                                  inFolder:currentFolder]) {
          // TODO: better error handling
          NSLog(@"from folder '%@' failed to process files: %@",
                currentFolder, currentFileList);
        }
        // restart the collecting w/ this filename
        currentFolder = [filename stringByDeletingLastPathComponent];
        [currentFileList removeAllObjects];
        [currentFileList addObject:[filename lastPathComponent]];
      }
    }
    // process whatever what we were collecting when we hit the end
    if (![self processCoverageForFiles:currentFileList
                              inFolder:currentFolder]) {
      // TODO: better error handling
      NSLog(@"from folder '%@' failed to process files: %@",
            currentFolder, currentFileList);
    }
  }
  return YES;
}

- (BOOL)processCoverageForFiles:(NSArray *)filenames
                       inFolder:(NSString *)folderPath {
  
  if (([filenames count] == 0) || ([folderPath length] == 0)) {
    return NO;
  }
  
  NSString *tempDir = NSTemporaryDirectory();
  tempDir = [tempDir stringByAppendingPathComponent:[folderPath lastPathComponent]];

  // make sure all the filenames are just leaves
  for (int x = 0 ; x < [filenames count] ; ++x) {
    NSString *filename = [filenames objectAtIndex:x];
    NSRange range = [filename rangeOfString:@"/"];
    if (range.location != NSNotFound) {
      // TODO - report this out better
      NSLog(@"filename '%@' had a slash", filename);
      return NO;
    }
  }
  
  // make sure it ends in a slash
  if (![folderPath hasSuffix:@"/"]) {
    folderPath = [folderPath stringByAppendingString:@"/"];
  }

  // we write all the full file paths into a file w/ null chars after each
  // so we can feed it into xargs -0
  NSMutableData *fileList = [NSMutableData data];
  NSData *folderPathUTF8 = [folderPath dataUsingEncoding:NSUTF8StringEncoding];
  if (!folderPathUTF8 || !fileList) return NO;
  char nullByte = 0;
  for (int x = 0 ; x < [filenames count] ; ++x) {
    NSString *filename = [filenames objectAtIndex:x];
    NSData *filenameUTF8 = [filename dataUsingEncoding:NSUTF8StringEncoding];
    if (!filenameUTF8) return NO;
    [fileList appendData:folderPathUTF8];
    [fileList appendData:filenameUTF8];
    [fileList appendBytes:&nullByte length:1];
  }
  
  BOOL result = NO;
  GTMScriptRunner *runner = [GTMScriptRunner runnerWithBash];
  if (!runner) return NO;
  
  // make a scratch directory
  NSFileManager *fm = [NSFileManager defaultManager];
  if ([fm gtm_createFullPathToDirectory:tempDir attributes:nil]) {

    // now write out our file
    NSString *fileListPath = [tempDir stringByAppendingPathComponent:@"filelists.txt"];
    if (fileListPath && [fileList writeToFile:fileListPath atomically:YES]) {
      // run gcov (it writes to current directory, so we cd into our dir first)
      // we use xargs to batch up the files into as few of runs of gcov as
      // possible.  (we could use -P [num_cpus] to do things in parallell)
      NSString *script =
      [NSString stringWithFormat:@"cd \"%@\" && /usr/bin/xargs -0 /usr/bin/gcov -l -o \"%@\" < \"%@\"",
       tempDir, folderPath, fileListPath];
      
      NSString *stdErr = nil;
      NSString *stdOut = [runner run:script standardError:&stdErr];
      if (([stdOut length] == 0) || ([stdErr length] > 0)) {
        // TODO - provide a real way to get this to the users
        NSLog(@"gcov failed from folder '%@' failed to process files: %@",
              folderPath, filenames);
        NSLog(@">>> stdout: %@", stdOut);
        NSLog(@">>> stderr: %@", stdErr);
      } 
    
      // swince we batch process, we might have gotten some data even w/ an error
      // so we check anyways for data
        
      // collect the gcov files
      NSArray *resultPaths = [fm gtm_filePathsWithExtension:@"gcov"
                                                inDirectory:tempDir];
      for (int x = 0 ; x < [resultPaths count] ; ++x) {
        NSString *fullPath = [resultPaths objectAtIndex:x];
        NSData *data = [NSData dataWithContentsOfFile:fullPath];
        if (data) {
          // load it and add it to out set
          CoverStoryCoverageFileData *fileData =
          [CoverStoryCoverageFileData coverageFileDataFromData:data];
          if (fileData) {
            [dataSet_ addFileData:fileData];
            result = YES;
          } else {
            NSLog(@"failed to pull data from gcov file (%@), usually means source isn't a currently handled encoding",
                  [fullPath lastPathComponent]);
          }
        } else {
          // TODO: report this out
          NSLog(@"failed to load data from gcov file: %@", fullPath);
        }
      }
    } else {
      // TODO: report this out
      NSLog(@"failed to write out the file lists (%@)", fileListPath);
    }
    
    // nuke our temp dir tree
    if (![fm removeFileAtPath:tempDir handler:nil]) {
      // TODO - provide a real way to get this to the users
      NSLog(@"failed to remove our tempdir (%@)", tempDir);
    }
  }
  
  return result;
}

@end
