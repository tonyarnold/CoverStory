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
  
static void IncrementComplexityCount();
static void IncrementLineCount();
static void IncrementNesting();

static void DecrementNesting();

static void HandleComment();    
static void HandleCase();
static void EndOpenCase();
static void HandleOpenScope();
static void EndOpenScope();
static void Error(const char *err);
static const char* ScopeName(int scope);
  
// States
// OPENSCOPE - we have encountered a potential scoping keyword 
//             (namespace, class, enum, struct) but we've not sure if we
//             are declaring the scope, or defining it. If we hit a '{' before
//             a ';' we will be defining. Otherwise we are declaring.
// OPENCASE  - we have encountered a case statement. Not sure yet whether
//             it is followed by another case or define, so we need to check
//             before increasing complexity.
// SCOPE     - we are defining a scoped area (namespace, class, enum, struct)
// BRACE     - we are in a non "scoped" area surrounded by {}.
%}
%array
%option stack
%x OPENSCOPE
%x OPENCASE
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

"/*"                                          { /**/ HandleComment(); }
"//".*                                        {}

<OPENCASE,OPENSCOPE>{horizontal_white}+       {}
<OPENCASE>case{horizontal_white}+{identifier} {}
<OPENCASE>:                                   {}
<OPENCASE>default                             {}
<OPENCASE,OPENSCOPE>"\n"                      { IncrementLineCount(); }
<OPENCASE>.                                   { EndOpenCase(); }
<OPENSCOPE>{identifier}                       {}
<OPENSCOPE>.                                  { EndOpenScope(); }

{horizontal_white}+                           {}
({v_tab}|{c_return}|{form_feed})+             {}
{blank_line}*"\n"                             { IncrementLineCount(); }

asm                                           {}
auto                                          {}
break                                         {}
case{horizontal_white}+{identifier}           { HandleCase(); }
char                                          {}
const                                         {}
continue                                      {}
default                                       { HandleCase(); }
define                                        {}
defined                                       {}
do                                            {}
double                                        {}
elif.*                                        {}
#else                                         {}
else                                          {}
endif                                         {}
enum                                          { HandleOpenScope(); }
error                                         {}
extern                                        {}
float                                         {}
for                                           { IncrementComplexityCount(); }
goto                                          {}
#if.*                                         {}
if                                            { IncrementComplexityCount(); }
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
struct                                        { HandleOpenScope(); }
switch                                        {}
typedef                                       {}
undef                                         {}
union                                         { HandleOpenScope(); }
unsigned                                      {}
void                                          {}
volatile                                      {}
warning                                       {}
wchar_t                                       {}
while                                         { IncrementComplexityCount(); }

and                                           { IncrementComplexityCount(); }
and_eq                                        {}
bitand                                        {}
bitor                                         {}
bool                                          {}
catch                                         { IncrementComplexityCount(); }
class                                         { HandleOpenScope(); }
compl                                         {}
const_cast                                    {}
delete                                        {}
dynamic_cast                                  {}
explicit                                      {}
export                                        {}
false                                         {}
friend                                        {}
inline                                        {}
namespace                                     { HandleOpenScope(); }
new                                           {}
not                                           {}
or                                            { IncrementComplexityCount(); }
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
 
interface                                     {}
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
"{"                                           { IncrementNesting(); }
"}"                                           { DecrementNesting(); }
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
"?"                                           { IncrementComplexityCount(); }
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
"&&"                                          { IncrementComplexityCount(); }
"||"                                          { IncrementComplexityCount(); }
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

int gNestingDepth = 0;
int gTotalNestingDepth = 0;
int gComplexityCount = 1;
int gLineNum = 1;
int gStartLine = 0;
char gDebug = 0;
        
int yywrap() { 
  return 1;
}

int main (int argc, const char * argv[]) {
  // Skip over program name
  if (getenv("DEBUG") != NULL) {
    gDebug = 1;
  }
  ++argv;
  --argc; 
  if (argc) {
    for (int i = 0; i < argc; ++i) {
      if (strcmp(argv[i], "-") == 0) {
        yyin = stdin;
      } else {
        yyin = fopen(argv[i], "r");
      }
      if (!yyin) {
        Error("Unable to open file");
      }
      printf("- %s\n", argv[i]);  
      yylex();
      printf("\n");
      if (yyin != stdin) {
        fclose(yyin);
      }
    }
  } else {
    yyin = stdin;
    yylex();
  }
  return 0;
}
        
void IncrementComplexityCount() {
  if (gDebug) {
    printf("\tIncrease Complexity: (%s - %d)\n", yytext, gLineNum);
  }
  gComplexityCount += 1;
}

void IncrementLineCount() {
  gLineNum += 1;
}

void IncrementNesting() {
  if (YY_START == OPENSCOPE) {
    yy_pop_state();
    yy_push_state(SCOPE);
  } else {
    if (gNestingDepth == 0) {
      gStartLine = gLineNum;
    }
    gNestingDepth += 1;
    yy_push_state(BRACE);
  }
  if (gDebug) {
    for (int i = 0; i < gTotalNestingDepth; i++) {
      printf("\t");
    }
    gTotalNestingDepth += 1; 
    printf("Increase Nesting To %s: (%s - %d)\n", ScopeName(YY_START), 
           yytext, gLineNum);
  }
}

void DecrementNesting() {
  if (YY_START == BRACE) {
    gNestingDepth -= 1;
    if (gNestingDepth == 0 && gComplexityCount) {
      char *risk;
      if (gComplexityCount < 11) {
        risk = "low";
      } else if (gComplexityCount < 21) {
        risk = "moderate";
      } else if (gComplexityCount < 51) {
        risk = "high";
      } else {
        risk = "extreme";
      }
      printf("Line: %d To: %d Complexity: %d Risk: %s\n", 
             gStartLine, gLineNum, gComplexityCount, risk);
      gComplexityCount = 1;
    }
  }
  yy_pop_state();

  if (gDebug) {
    gTotalNestingDepth -= 1;
    for (int i = 0; i < gTotalNestingDepth; i++) {
      printf("\t");
    }
    printf("Decrease Nesting To %s: (%s - %d)\n", ScopeName(YY_START), 
           yytext, gLineNum);
  }
        
}

void HandleCase() {
 if (YY_START != OPENCASE) { 
   IncrementComplexityCount(); 
   yy_push_state(OPENCASE);
 }
}

void EndOpenCase() {
  yy_pop_state(); 
  unput(yytext[0]);
}

void HandleComment() {
  while(1) {
    int c;
    while ((c = input()) != '*' && c != EOF && c != '\n');  
    if ( c == '*' ) {
      while ( (c = input()) == '*' );
      if ( c == '/' ) break;    
    }
    if (c == '\n') {
      IncrementLineCount();
    } else if ( c == EOF ) {
      Error( "EOF in comment" );
      break;
    }
  }
}
        
void HandleOpenScope() {
  yy_push_state(OPENSCOPE);
}

void EndOpenScope() {
  if (strcmp(yytext, "{") == 0) {
    IncrementNesting();
  } else {
    yy_pop_state();
    unput(yytext[0]);
  }
}
        
void Error(const char *err) {
  printf(err);
  exit(1);
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
    NUMTONAME(OPENCASE), 
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
