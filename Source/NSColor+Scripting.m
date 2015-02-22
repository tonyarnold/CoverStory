//
//  NSColor+Scripting.m
//  CoverStory
//
//  Copyright 2009 Google Inc.
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

#import <Cocoa/Cocoa.h>
@interface NSColor(CoverStoryScripting)
@end

@implementation NSColor(CoverStoryScripting)
+ (NSColor *)scriptingRGBColorWithDescriptor:(NSAppleEventDescriptor *)inDesc {
  // We're expected to handle everything that can be coerced to 
  //RGB colors, not just RGB colors.
  NSColor *color = nil;
  NSAppleEventDescriptor *rgbColorDescriptor 
    = [inDesc coerceToDescriptorType:typeRGBColor];
  if (rgbColorDescriptor) {
	// RGBColors contain 16-bit red, green, and blue components. 
    // Don't trust structures found in Apple event descriptors though.
	NSData *descriptorData = [rgbColorDescriptor data];
	if ([descriptorData length] == sizeof(RGBColor)) {
      const RGBColor *qdColor = (const RGBColor *)[descriptorData bytes];
      CGFloat red = ((CGFloat)qdColor->red / 65535.0f);
      CGFloat green = ((CGFloat)qdColor->green / 65535.0f);
      CGFloat blue = ((CGFloat)qdColor->blue / 65535.0f);
      color = [NSColor colorWithCalibratedRed:red 
                                        green:green
                                         blue:blue
                                        alpha:1.0];
	}
  }
  return color;
}

- (NSAppleEventDescriptor *)scriptingRGBColorDescriptor {
  // RGBColors contain 16-bit red, green, and blue components.
  NSColor *colorAsCalibratedRGB 
    = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
  RGBColor qdColor;
  CGFloat red, green, blue, alpha;
  [colorAsCalibratedRGB getRed:&red green:&green blue:&blue alpha:&alpha];
  qdColor.red = (unsigned short)(red * 65535.0f);
  qdColor.green = (unsigned short)(green * 65535.0f);
  qdColor.blue = (unsigned short)(blue * 65535.0f);
  return [NSAppleEventDescriptor descriptorWithDescriptorType:typeRGBColor 
                                                        bytes:&qdColor 
                                                       length:sizeof(RGBColor)];
}
@end
