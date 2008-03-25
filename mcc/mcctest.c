//
//  mcctest.c
//  mcc
//
//  Created by Dave MacLachlan on 2008/03/25.
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

//  Test file for testing mcc
//  Run this through mcc, and compare it to mcctestmaster.txt

void foo() {
  switch (a) {
    case b:
    case c: {
      while (1);
      break;
    }
    case d:
      foo++;
      break;
    
    default:
      for(int i = 0; i < 20; i++) { j++; }
      break;
  }
}

namespace bar {};

namespace bar;
namespace {
struct {
  struct {
    int b;
  }
  int a;
  }
}

class d {
  inline a() { crazy(); };
  struct c b();
};

struct c d::b() {
  return 0;
}

void bam(struct blat *f) {
  for (int i = 0; i < 10; ++i) { // random inline comment
    if (j) return 1;
  }
}