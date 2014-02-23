//
//  YVSChromaKeyFilter.h
//  chromakey
//
//  Created by Kevin Meaney on 20/02/2014.
//  Copyright (c) 2014 Kevin Meaney. All rights reserved.
//


@interface YVSChromaKeyFilter : CIFilter
{
    CIImage   *inputImage;
    CIVector  *inputColor;
    NSNumber  *inputDistance;
    NSNumber  *inputSlopeWidth;
}

/// initialize. Create the YVSChromaKeyFilter CIKernel object used in every .
+(void)initialize;

/// Basic init method.
-(instancetype)init;

/// Return the customAttributes
-(NSDictionary *)customAttributes;

@end
