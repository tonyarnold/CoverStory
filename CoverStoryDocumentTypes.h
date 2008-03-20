/*
 *  CoverStoryDocumentTypes.h
 *  CoverStory
 *
 *  Created by Dave MacLachlan on 2008/03/10.
 *  Copyright 2008 Google Inc. All rights reserved.
 *
 */


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
