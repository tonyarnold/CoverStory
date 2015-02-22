//
// CoverStoryDocumentTypes.h
// CoverStory
//
//  Created by Dave MacLachlan on 2008/03/10.
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


// These are the various document types used by CoverStory.
// Included in both Obj-C and plist sources.

// A little magic to get CPP to turn things into cstrings for the code but have
// the strings raw for the plists.  The reason we need this is if we just put
// them in quotes (cstrings) then we'd get those quotes in the plists, which we
// don't want.
#define STRINGIFY(x) #x
#define TO_STRING(x) STRINGIFY(x)

#define kGCNOTypeNameRaw GNU Compiler Notes File
#define kGCDATypeNameRaw GNU Compiler Data Arcs File
#define kGCOVTypeNameRaw GNU Compiler Coverage File
#define kGCNOTypeName TO_STRING(kGCNOTypeNameRaw)
#define kGCDATypeName TO_STRING(kGCDATypeNameRaw)
#define kGCOVTypeName TO_STRING(kGCOVTypeNameRaw)
