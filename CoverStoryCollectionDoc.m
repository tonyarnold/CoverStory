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
#import "CoverStoryDocument.h"

@interface CoverStoryCollectionDoc (PrivateMethods)
- (BOOL)processCoverageForFolder:(NSString *)path;
- (BOOL)processCoverageForPath:(NSString *)path;
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
  NSString *path = [self fileName];
  return [self processCoverageForPath:path];
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
  // cycle through the directory finding the .gcno files
  NSFileManager *fm = [NSFileManager defaultManager];
  NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:path];
  NSString *subPath = nil;
  while ((subPath = [enumerator nextObject]) != nil) {
    if ([subPath hasSuffix:@".gcno"]) {
      NSString *fullPath = [path stringByAppendingPathComponent:subPath];
      if (![self processCoverageForPath:fullPath]) {
        // TODO: better error handling
        NSLog(@"failed to process file: %@", fullPath);
      }
    }
  }
  return YES;
}

- (BOOL)processCoverageForPath:(NSString *)path {
  
  NSString *tempDir = NSTemporaryDirectory();
  tempDir = [tempDir stringByAppendingPathComponent:[path lastPathComponent]];
  NSString *pathDir = [path stringByDeletingLastPathComponent];
  if (!tempDir || !pathDir) return NO;

  BOOL result = NO;
  GTMScriptRunner *runner = [GTMScriptRunner runnerWithBash];
  if (!runner) return NO;

  // run gcov
  NSString *script =
    [NSString stringWithFormat:
     @"/bin/mkdir -p \"%@\" && cd \"%@\" && /usr/bin/gcov -o \"%@\" \"%@\"\n",
     tempDir, tempDir, pathDir, path];

  NSString *stdErr = nil;
  NSString *stdOut = [runner run:script standardError:&stdErr];
  if (([stdOut length] == 0) || ([stdErr length] > 0)) {
    // TODO - provide a real way to get this to the users
    NSLog(@"failed to run gcov, stderr: %@", stdErr);
    goto bail_out;
  }

  // collect the gcov files
  NSFileManager *fm = [NSFileManager defaultManager];
  NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:tempDir];
  NSString *subPath = nil;
  while ((subPath = [enumerator nextObject]) != nil) {
    if ([subPath hasSuffix:@".gcov"]) {
      NSString *fullPath = [tempDir stringByAppendingPathComponent:subPath];
      NSData *data = [NSData dataWithContentsOfFile:fullPath];
      if (data) {
        // load it and add it to out set
        CoverStoryCoverageFileData *fileData =
          [CoverStoryCoverageFileData coverageFileDataFromData:data];
        if (fileData) {
          [dataSet_ addFileData:fileData];
          result = YES;
        } else {
          NSLog(@"failed to pull data from gcov file, usually means source wasn't UTF8 (%@)",
                [fullPath lastPathComponent]);
        }
      } else {
        // TODO: report this out
        NSLog(@"failed to load data from gcov file: %@", fullPath);
      }
    }
  }

bail_out:
  // just run an rm as part of the cleanup
  [runner run:[NSString stringWithFormat:@"/bin/rm -rf \"%@\"\n", tempDir]];

  return result;
}

@end
