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
static void Error(const char *err);
  
// States
// OPENSCOPE - we have encountered a potential scoping keyword 
//             (namespace, class, enum, struct) but we've not sure if we
//             are declaring the scope, or defining it. If we hit a '{' before
//             a ';' we will be defining. Otherwise we are declaring.
// SCOPE     - we are defining a scoped area (namespace, class, enum, struct)
// BRACE     - we are in a non "scoped" area surrounded by {}.
%}
%option stack
%s OPENSCOPE
%s OPENCASE
%s CASE
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

"/*"                { /**/ HandleComment(); }
"//".*              {}

        <OPENCASE>{horizontal_white}+ { printf("OpenCase whitespace\n"); }
        <OPENCASE>case{horizontal_white}+{identifier}  {printf("OpenCase case\n"); }
        <OPENCASE>: { printf("OpenCase :\n"); }
        <OPENCASE>default {printf("OpenCase default\n"); }
        <OPENCASE>"\n" { printf("OpenCase Newline\n"); IncrementLineCount(); }
        <OPENCASE>.*        { printf("Exit Case (%s): ", yytext); yy_pop_state(); printf("%d\n", YY_START); REJECT; }

        {horizontal_white}+ {}

({v_tab}|{c_return}|{form_feed})+ {}

{blank_line}*"\n" { IncrementLineCount(); }

        
asm                 {}
auto                {}
break               {}
case{horizontal_white}+{identifier} { HandleCase(); }
char                {}
const               {}
continue            {}
default             { HandleCase(); }
define              {}
defined             {}
do                  {}
double              {}
elif.*              {}
#else               {}
else                {}
endif               {}
enum                { yy_push_state(OPENSCOPE); }
error               {}
extern              {}
float               {}
for                 { IncrementComplexityCount(); }
goto                {}
#if.*               {}
if                  { IncrementComplexityCount(); }
ifdef               {}
ifndef              {}
include             {}
import              {}
int                 {}
line                {}
long                {}
mutable             {}
pragma              {}
register            {}
return              {}
short               {}
signed              {}
sizeof              {}
static              {}
struct              { yy_push_state(OPENSCOPE); }
switch              {}
typedef             {}
undef               {}
union               { yy_push_state(OPENSCOPE); }
unsigned            {}
void                {}
volatile            {}
warning             {}
wchar_t             {}
        while               { printf("while\n"); IncrementComplexityCount(); }
and                 { IncrementComplexityCount(); }
and_eq              {}
bitand              {}
bitor               {}
bool                {}
catch               { IncrementComplexityCount(); }
class               { yy_push_state(OPENSCOPE); }
compl               {}
const_cast          {}
delete              {}
dynamic_cast        {}
explicit            {}
export              {}
false               {}
friend              {}
inline              {}
namespace           { yy_push_state(OPENSCOPE); }
new                 {}
not                 {}
or                  { IncrementComplexityCount(); }
or_eq               {}
operator            {}
protected           {}
private             {}
public              {}
reinterpret_cast    {}
static_cast         {}
template            {}
this                {}
throw               {}
true                {}
try                 {}
typeid              {}
typename            {}
using               {}
virtual             {}
xor                 {}
xor_eq              {}
 
interface           {}
protocol            {}
implementation      {}
synchronized        {}
selector            {}
encode              {}
self                {}
super               {}
end                 {}
package             {}
id                  {}
in                  {}
out                 {}
inout               {}
bycopy              {}
byref               {}
oneway              {}
finally             {}

{identifier}        {}

{decimal_constant}  {}
{octal_constant}    {}
{hex_constant}      {}
{floating_constant} {}


"L"?[']{c_char}+['] {}


"L"?["]{s_char}*["] {}


"("                 {}
")"                 {}
","                 {}
"#"                 {}
"##"                {}
"@"                 {}
"{"                 { IncrementNesting(); }
"}"                 { DecrementNesting(); }
"["                 {}
"]"                 {}
"."                 {}
"&"                 {}
"*"                 {}
"+"                 {}
"-"                 {}
"~"                 {}
"!"                 {}
"/"                 {}
"%"                 {}
"<"                 {}
">"                 {}
"^"                 {}
"|"                 {}
"?"                 { IncrementComplexityCount(); }
":"                 {}
 <OPENSCOPE>";"     { yy_pop_state(); }
";"                 {}
"="                 {}
".*"                {}
"::"                {}
"->"                {}
"->*"               {}
"++"                {}
"--"                {}
"<<"                {}
">>"                {}
"<="                {}
">="                {}
"=="                {}
"!="                {}
"&&"                { IncrementComplexityCount(); }
"||"                { IncrementComplexityCount(); }
"*="                {}
"/="                {}
"%="                {}
"+="                {}
"-="                {}
"<<="               {}
">>="               {}
"&="                {}
"^="                {}
"|="                {}
"..."               {}

%%

int yywrap() { 
  return 1;
}

int main (int argc, const char * argv[]) {
  // Skip over program name
  ++argv;
  --argc; 
  if (argc) {
    int i;
    for (i = 0; i < argc; ++i) {
      if (strcmp(argv[i], "-") == 0) {
        yyin = stdin;
      } else {
        yyin = fopen(argv[i], "r");
      }
      if (!yyin) {
        Error("Unable to open file");
      }
      printf("- %s\n", argv[i]);  
      yy_push_state(INITIAL);
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

int gNestingDepth = 0;
int gComplexityCount = 1;
int gLineNum = 1;
int gStartLine = 0;
  
void IncrementComplexityCount() {
  gComplexityCount += 1;
}

void IncrementLineCount() {
  gLineNum += 1;
}

void IncrementNesting() {
        printf("{\n");
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
}

void HandleCase() {
 if (YY_START != OPENCASE) { 
        printf("Counted Case\n");
   IncrementComplexityCount(); 
   yy_push_state(OPENCASE);
        } else {
        printf("Ignored Case\n");
        }

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
    
void Error(const char *err) {
  printf(err);
  exit(1);
}