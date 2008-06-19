%{
//
//  mcc.l
//  CoverStory
//
//  Created by dmaclach on 03/22/08.
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
// Portions Copyright (c) 1989, 1990 James  A.   Roskind
// Based on the Roskind Grammer Last modified 7/4/91, Version 2.0
// I got it from:
// http://lahtermaher.org/pub/plan/c/iecc/file/c++grammar/cpp5.l
//
// Does a variant of McCabe cyclomatic complexity counting of C/C++/ObjC/ObjC++

#include <stdarg.h>

typedef struct {
  int nestingDepth;
  int totalNestingDepth;
  int complexityCount;
  int lineNum;
  int startLine;
  char debug;
  char *outputBuffer;
  size_t outputBufferLen;
  size_t outputBufferSize;
} ComplexityState;

#define YY_EXTRA_TYPE ComplexityState *

static void InitializeComplexityState(ComplexityState *state);
static void DestroyComplexityState(ComplexityState *state);

static void IncrementComplexityCount(yyscan_t yyscanner);
static void IncrementLineCount(yyscan_t yyscanner);
static void IncrementNesting(yyscan_t yyscanner, int curState);

static void DecrementNesting(yyscan_t yyscanner, int curState);

static void HandleComment(yyscan_t yyscanner);    
static void HandleOpenScope(yyscan_t yyscanner);
static const char* ScopeName(int scope);
  
// States
// OPENSCOPE - we have encountered a potential scoping keyword 
//             (namespace, class, enum, struct) but we've not sure if we
//             are declaring the scope, or defining it. If we hit a '{' before
//             a ';' we will be defining. Otherwise we are declaring.
// SCOPE     - we are defining a scoped area (namespace, class, enum, struct)
// BRACE     - we are in a non "scoped" area surrounded by {}.
%}
%array
%option stack
%option reentrant
%x OPENSCOPE
%s SCOPE
%s BRACE
identifier [a-zA-Z_][0-9a-zA-Z_]*

exponent_part [eE][-+]?[0-9]+
fractional_constant ([0-9]*"."[0-9]+)|([0-9]+".")
floating_constant (({fractional_constant}{exponent_part}?)|([0-9]+{exponent_part}))[FfLl]?

integer_suffix_opt ([uU]?[lL]?)|([lL][uU])
decimal_constant [1-9][0-9]*{integer_suffix_opt}
octal_constant "0"[0-7]*{integer_suffix_opt}
hex_constant "0"[xX][0-9a-fA-F]+{integer_suffix_opt}

simple_escape [abfnrtv'"?\\]
octal_escape  [0-7]{1,3}
hex_escape "x"[0-9a-fA-F]+

escape_sequence [\\]({simple_escape}|{octal_escape}|{hex_escape})
c_char [^'\\\n]|{escape_sequence}
s_char [^"\\\n]|{escape_sequence}


h_tab [\011]
form_feed [\014]
v_tab [\013]
c_return [\015]

horizontal_white [ ]|{h_tab}
blank_line {horizontal_white}|{v_tab}|{c_return}|{form_feed}

%%

"/*"                                          { /**/ HandleComment(yyscanner); }
"//".*                                        {}

<OPENSCOPE>{horizontal_white}+                {}
<OPENSCOPE>"\n"                               { IncrementLineCount(yyscanner); }
<OPENSCOPE>{identifier}                       {}
<OPENSCOPE>.                                  { 
                                                if (strcmp(yytext, "{") == 0) {
                                                  IncrementNesting(yyscanner, YY_START);
                                                } else {
                                                  yy_pop_state(yyscanner);
                                                  unput(yytext[0]);
                                                }
                                              }

{horizontal_white}+                           {}
({v_tab}|{c_return}|{form_feed})+             {}
{blank_line}*"\n"                             { IncrementLineCount(yyscanner); }

asm                                           {}
auto                                          {}
break                                         {}
case                                          { IncrementComplexityCount(yyscanner); }
char                                          {}
const                                         {}
continue                                      {}
default                                       { IncrementComplexityCount(yyscanner); }
define                                        {}
defined                                       {}
do                                            {}
double                                        {}
elif.*                                        {}
#else                                         {}
else                                          {}
endif                                         {}
enum                                          { HandleOpenScope(yyscanner); }
error                                         {}
extern                                        {}
float                                         {}
for                                           { IncrementComplexityCount(yyscanner); }
goto                                          {}
#if.*                                         {}
if                                            { IncrementComplexityCount(yyscanner); }
ifdef                                         {}
ifndef                                        {}
include                                       {}
import                                        {}
int                                           {}
line                                          {}
long                                          {}
mutable                                       {}
pragma                                        {}
register                                      {}
return                                        {}
short                                         {}
signed                                        {}
sizeof                                        {}
static                                        {}
struct                                        { HandleOpenScope(yyscanner); }
switch                                        {}
typedef                                       {}
undef                                         {}
union                                         { HandleOpenScope(yyscanner); }
unsigned                                      {}
void                                          {}
volatile                                      {}
warning                                       {}
wchar_t                                       {}
while                                         { IncrementComplexityCount(yyscanner); }

and                                           { IncrementComplexityCount(yyscanner); }
and_eq                                        {}
bitand                                        {}
bitor                                         {}
bool                                          {}
catch                                         { IncrementComplexityCount(yyscanner); }
class                                         { HandleOpenScope(yyscanner); }
compl                                         {}
const_cast                                    {}
delete                                        {}
dynamic_cast                                  {}
explicit                                      {}
export                                        {}
false                                         {}
friend                                        {}
inline                                        {}
namespace                                     { HandleOpenScope(yyscanner); }
new                                           {}
not                                           {}
or                                            { IncrementComplexityCount(yyscanner); }
or_eq                                         {}
operator                                      {}
protected                                     {}
private                                       {}
public                                        {}
reinterpret_cast                              {}
static_cast                                   {}
template                                      {}
this                                          {}
throw                                         {}
true                                          {}
try                                           {}
typeid                                        {}
typename                                      {}
using                                         {}
virtual                                       {}
xor                                           {}
xor_eq                                        {}
 
interface                                     { HandleOpenScope(yyscanner); }
protocol                                      {}
implementation                                {}
synchronized                                  {}
selector                                      {}
encode                                        {}
self                                          {}
super                                         {}
end                                           {}
package                                       {}
id                                            {}
in                                            {}
out                                           {}
inout                                         {}
bycopy                                        {}
byref                                         {}
oneway                                        {}
finally                                       {}

{identifier}                                  {}

{decimal_constant}                            {}
{octal_constant}                              {}
{hex_constant}                                {}
{floating_constant}                           {}


"L"?[']{c_char}+[']                           {}


"L"?["]{s_char}*["]                           {}


"("                                           {}
")"                                           {}
","                                           {}
"#"                                           {}
"##"                                          {}
"@"                                           {}
"{"                                           { IncrementNesting(yyscanner, YY_START); }
"}"                                           { DecrementNesting(yyscanner, YY_START); }
"["                                           {}
"]"                                           {}
"."                                           {}
"&"                                           {}
"*"                                           {}
"+"                                           {}
"-"                                           {}
"~"                                           {}
"!"                                           {}
"/"                                           {}
"%"                                           {}
"<"                                           {}
">"                                           {}
"^"                                           {}
"|"                                           {}
"?"                                           { IncrementComplexityCount(yyscanner); }
":"                                           {}
";"                                           {}
"="                                           {}
".*"                                          {}
"::"                                          {}
"->"                                          {}
"->*"                                         {}
"++"                                          {}
"--"                                          {}
"<<"                                          {}
">>"                                          {}
"<="                                          {}
">="                                          {}
"=="                                          {}
"!="                                          {}
"&&"                                          { IncrementComplexityCount(yyscanner); }
"||"                                          { IncrementComplexityCount(yyscanner); }
"*="                                          {}
"/="                                          {}
"%="                                          {}
"+="                                          {}
"-="                                          {}
"<<="                                         {}
">>="                                         {}
"&="                                          {}
"^="                                          {}
"|="                                          {}
"..."                                         {}

%%

void InitializeComplexityState(ComplexityState *state) {
  state->nestingDepth = 0;
  state->totalNestingDepth = 0;
  state->complexityCount = 1;
  state->lineNum = 1;
  state->startLine = 0;
  state->debug = 0;

  state->outputBufferLen = 0;
  state->outputBufferSize = 2048;
  state->outputBuffer = malloc(state->outputBufferSize);
  if (state->outputBuffer) {
    state->outputBuffer[0] = 0;
  }
}

void DestroyComplexityState(ComplexityState *state) {
  if (state && state->outputBuffer) {
    free(state->outputBuffer);
    state->outputBuffer = 0;
  }
}

void appendMessage(ComplexityState *state, const char *format, ...) {
  if (!state || !state->outputBuffer) return;
  va_list args;
  va_start(args, format);
  char *localBuffer = 0;
  int result = vasprintf(&localBuffer, format, args);
  if (result > 0) {
    size_t charCount = result;
    if ((state->outputBufferSize - state->outputBufferLen) <= charCount) {
      state->outputBufferSize += charCount + 1024;
      state->outputBuffer = realloc(state->outputBuffer, state->outputBufferSize);
    }
    if (state->outputBuffer) {
      memcpy(state->outputBuffer + state->outputBufferLen, localBuffer, charCount);
      state->outputBufferLen += charCount;
      state->outputBuffer[state->outputBufferLen] = 0;
    }
  }
  if (localBuffer) {
    free(localBuffer);
  }
  va_end(args);
}

int yywrap(yyscan_t yyscanner) { 
  return 1;
}

#ifdef EMBED_MCC

// returns a buffer you have to call free on
char *mcc(const char* utf8String) {
  char *result = 0;

  ComplexityState complexityState;
  InitializeComplexityState(&complexityState);
  // complexityState.debug = 1;
  
  yyscan_t scanner;
  yylex_init(&scanner);
  yyset_extra(&complexityState, scanner);
  
  YY_BUFFER_STATE buf = yy_scan_string(utf8String, scanner);
  yylex(scanner);
  yy_delete_buffer(buf, scanner);
  yylex_destroy(scanner);

  if (complexityState.outputBuffer) {
    // extract the buffer for our result
    result = complexityState.outputBuffer;
    complexityState.outputBuffer = 0;
  }

  DestroyComplexityState(&complexityState);

  return result;
}

#else // !defined(EMBED_MCC)

int main (int argc, const char * argv[]) {
  // Skip over program name
  ++argv;
  --argc; 
  if (argc) {
    for (int i = 0; i < argc; ++i) {
      FILE *our_in = NULL;
      if (strcmp(argv[i], "-") == 0) {
        our_in = stdin;
      } else {
        our_in = fopen(argv[i], "r");
      }
      if (!our_in) {
        printf("Unable to open file");
        exit(1);
      }

      ComplexityState complexityState;
      InitializeComplexityState(&complexityState);
      if (getenv("DEBUG") != NULL) {
        complexityState.debug = 1;
      }
      appendMessage(&complexityState, "- %s\n", argv[i]);
        
      yyscan_t scanner;
      yylex_init(&scanner);
      yyset_extra(&complexityState, scanner);
      yyset_in(our_in, scanner);

      yylex(scanner);

      yylex_destroy(scanner);
      
      appendMessage(&complexityState, "\n");
      if (complexityState.outputBuffer) {
        printf("%s", complexityState.outputBuffer);
      }
      DestroyComplexityState(&complexityState);
      if (our_in != stdin) {
        fclose(our_in);
      }
    }
  } else {
    ComplexityState complexityState;
    InitializeComplexityState(&complexityState);
    if (getenv("DEBUG") != NULL) {
      complexityState.debug = 1;
    }
    
    yyscan_t scanner;
    yylex_init(&scanner);
    yyset_extra(&complexityState, scanner);
    
    yyset_in(stdin, scanner);
    yylex(scanner);
    yylex_destroy(scanner);
  }
  return 0;
}

#endif // defined(EMBED_MCC)
        
void IncrementComplexityCount(yyscan_t yyscanner) {
  ComplexityState *state = yyget_extra(yyscanner);
  if (state->debug) {
    appendMessage(state, "\tIncrease Complexity: (%s - %d)\n",
                  yyget_text(yyscanner), state->lineNum);
  }
  state->complexityCount += 1;
}

void IncrementLineCount(yyscan_t yyscanner) {
  ComplexityState *state = yyget_extra(yyscanner);
  state->lineNum += 1;
}

void IncrementNesting(yyscan_t yyscanner, int curState) {
  ComplexityState *state = yyget_extra(yyscanner);
  if (curState == OPENSCOPE) {
    yy_pop_state(yyscanner);
    yy_push_state(SCOPE, yyscanner);
  } else {
    if (state->nestingDepth == 0) {
      state->startLine = state->lineNum;
    }
    state->nestingDepth += 1;
    yy_push_state(BRACE, yyscanner);
  }
  if (state->debug) {
    for (int i = 0; i < state->totalNestingDepth; i++) {
      appendMessage(state, "\t");
    }
    state->totalNestingDepth += 1; 
    appendMessage(state, "Increase Nesting To %s: (%s - %d)\n", ScopeName(curState), 
                  yyget_text(yyscanner), state->lineNum);
  }
}

void DecrementNesting(yyscan_t yyscanner, int curState) {
  ComplexityState *state = yyget_extra(yyscanner);
  if (curState == BRACE) {
    state->nestingDepth -= 1;
    if (state->nestingDepth == 0 && state->complexityCount) {
      const char *risk;
      if (state->complexityCount < 11) {
        risk = "low";
      } else if (state->complexityCount < 21) {
        risk = "moderate";
      } else if (state->complexityCount < 51) {
        risk = "high";
      } else {
        risk = "extreme";
      }
      appendMessage(state, "Line: %d To: %d Complexity: %d Risk: %s\n", 
                    state->startLine, state->lineNum, state->complexityCount, risk);
      state->complexityCount = 1;
    }
  }
  yy_pop_state(yyscanner);

  if (state->debug) {
    state->totalNestingDepth -= 1;
    for (int i = 0; i < state->totalNestingDepth; i++) {
      appendMessage(state, "\t");
    }
    appendMessage(state, "Decrease Nesting To %s: (%s - %d)\n", ScopeName(curState), 
                  yyget_text(yyscanner), state->lineNum);
  }
        
}

void HandleComment(yyscan_t yyscanner) {
  while(1) {
    int c;
    while ((c = input(yyscanner)) != '*' && c != EOF && c != '\n');  
    if ( c == '*' ) {
      while ( (c = input(yyscanner)) == '*' );
      if ( c == '/' ) break;    
    }
    if (c == '\n') {
      IncrementLineCount(yyscanner);
    } else if ( c == EOF ) {
      ComplexityState *state = yyget_extra(yyscanner);
      appendMessage(state, "EOF in comment");
      break;
    }
  }
}
        
void HandleOpenScope(yyscan_t yyscanner) {
  yy_push_state(OPENSCOPE, yyscanner);
}

const char* ScopeName(int scope) {
  typedef struct {
    int num;
    const char *name;
  } ScopeMap;
  #define NUMTONAME(x) { x, #x }
  ScopeMap map[] = {
    NUMTONAME(INITIAL),
    NUMTONAME(OPENSCOPE), 
    NUMTONAME(SCOPE),
    NUMTONAME(BRACE) 
  };
  for (size_t i = 0; i < sizeof(map) / sizeof(ScopeMap); ++i) {
    if (scope == map[i].num) {
      return map[i].name;
    }
  }
  return "Unknown";
}
