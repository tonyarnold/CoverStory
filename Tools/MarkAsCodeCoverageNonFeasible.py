#! /usr/bin/python
# -*- coding: utf-8 -*-
# 
# MarkAsCodeCoverageNonFeasible.py
# Copyright 2008 Google Inc.
#
# Marks a block of code as non feasible with regards to code coverage.
# To use it with Xcode 3.x, go to the scripts menu and choose 
# "Edit User Scripts...". Then "Add Script File..." under the plus in
# the lower left hand corner.
#
# Set Input to "Selection"
# Directory to "Home Directory"
# Output to "Replace Selection"
# Errors to "Display in Alert"
#
# Then select the line(s) in your code that you want to mark as not
# covered, and select the script. Mapping it to Cntl-Option-N makes 
# it easy to do from the keyboard.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.  You may obtain 
# a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and 
# limitations under the License.

import sys
import string

def main():
  inputLines = sys.stdin.readlines()
  if len(inputLines) == 1:
    resultText = inputLines[0].rstrip() + """  // COV_NF_LINE\r"""
  else:
    firstLine = inputLines[0]
    spaces = firstLine[0:-len(firstLine.lstrip())]
    resultText = spaces + """// COV_NF_START\r"""
    for curLine in inputLines:
      resultText += curLine
    resultText += spaces + """// COV_NF_END\r"""
  print resultText

if __name__ == '__main__':
  main()