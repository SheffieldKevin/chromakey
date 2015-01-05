//
//  YVSChromaKeyFilter.m
//  chromakey
//
//  Created by Kevin Meaney on 20/02/2014.
//  Copyright (c) 2014 Kevin Meaney. All rights reserved.
//

#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

@import Foundation;
@import QuartzCore;

#import "YVSChromaKeyFilter.h"

NSString *const YVSChromaKeyFilterString = SHADER_STRING
(
  kernel vec4 apply(sampler inputImage, vec4 inputColor,
                    float inputDistance, float inputSlope)
  {
    vec4 outputColor;
    vec4 foregroundColor = sample(inputImage, samplerCoord(inputImage));
    foregroundColor = unpremultiply(foregroundColor);
    float dist = distance(foregroundColor.rgb, inputColor.rgb);
    float alpha = smoothstep(inputDistance, inputDistance + inputSlope, dist);
    outputColor.a = foregroundColor.a * alpha;
    outputColor.rgb = foregroundColor.rgb;
    outputColor = premultiply(outputColor);
    return outputColor;
  }
);

CIVector *YVSChromaKeyFilterDefaultInputColor;
NSNumber *YVSChromaKeyFilterDefaultInputDistance;
NSNumber *YVSChromaKeyFilterDefaultInputSlopeWidth;

static CIKernel *chromaKeyKernel;

@implementation YVSChromaKeyFilter

+(void)initialize
{
    if (self == [YVSChromaKeyFilter class])
    {
        NSArray *kernels = [CIKernel kernelsWithString:YVSChromaKeyFilterString];
        chromaKeyKernel = kernels[0];
        YVSChromaKeyFilterDefaultInputColor = [[CIVector alloc] initWithX:0.0f
                                                                        Y:1.0f
                                                                        Z:0.0f
                                                                        W:1.0];
        YVSChromaKeyFilterDefaultInputDistance = @0.08;
        YVSChromaKeyFilterDefaultInputSlopeWidth = @0.06;
        
        [CIFilter registerFilterName:@"YVSChromaKeyFilter"
                         constructor:(id<CIFilterConstructor>)self
                     classAttributes:@{
            kCIAttributeFilterDisplayName : @"Simple Chroma Key.",
             kCIAttributeFilterCategories : @[
                   kCICategoryColorAdjustment, kCICategoryVideo,
                   kCICategoryStillImage, kCICategoryInterlaced,
                   kCICategoryNonSquarePixels]
                                     }
         ];
    }
}

+(CIFilter *)filterWithName:(NSString *)name
{
    CIFilter  *filter;
    filter = [[YVSChromaKeyFilter alloc] init];
    return filter;
}

-(id)init
{
    self = [super init];
    
    if (self)
    {
        self->inputColor = YVSChromaKeyFilterDefaultInputColor;
        self->inputDistance = YVSChromaKeyFilterDefaultInputDistance;
        self->inputSlopeWidth = YVSChromaKeyFilterDefaultInputSlopeWidth;
    }
    
    return self;
}

- (CIImage *)outputImage
{
    NSParameterAssert(inputImage != nil &&
                      [inputImage isKindOfClass:[CIImage class]]);
    NSParameterAssert(inputColor != nil &&
                      [inputColor isKindOfClass:[CIVector class]]);
    NSParameterAssert(inputDistance != nil &&
                      [inputDistance isKindOfClass:[NSNumber class]]);
    NSParameterAssert(inputSlopeWidth != nil &&
                      [inputSlopeWidth isKindOfClass:[NSNumber class]]);
    
    // Create output image by applying chroma key filter.
    CIImage *outputImage;
    
    outputImage = [self apply:chromaKeyKernel,
                            [CISampler samplerWithImage:inputImage],
                            self->inputColor, inputDistance, inputSlopeWidth,
                            kCIApplyOptionDefinition, [inputImage definition],
                            nil];
    
    return outputImage;
}

- (NSDictionary *)customAttributes
{
    NSDictionary *inputColorProps = @{
                     kCIAttributeClass : [CIColor class],
                   kCIAttributeDefault : YVSChromaKeyFilterDefaultInputColor,
                      kCIAttributeType : kCIAttributeTypeOpaqueColor };
    
    NSDictionary *inputDistanceProps = @{
                     kCIAttributeClass : [NSNumber class],
                   kCIAttributeDefault : YVSChromaKeyFilterDefaultInputDistance,
                      kCIAttributeType : kCIAttributeTypeDistance };

    NSDictionary *inputSlopeWidthProps = @{
                    kCIAttributeClass : [NSNumber class],
                  kCIAttributeDefault : YVSChromaKeyFilterDefaultInputSlopeWidth,
                     kCIAttributeType : kCIAttributeTypeDistance };

    return @{ kCIInputColorKey : inputColorProps,
              @"inputDistance" : inputDistanceProps,
            @"inputSlopeWidth" : inputSlopeWidthProps };
}


@end
