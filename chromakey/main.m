//
//  main.m
//  chromakey
//
//  Created by Kevin Meaney on 20/02/2014.
//  Copyright (c) 2014 Kevin Meaney. All rights reserved.
//

@import Foundation;
@import QuartzCore;

#import "YVSChromaKeyFilter.h"

// ---------------------------------------------------------------------------
//		S W I T C H E S
// ---------------------------------------------------------------------------


// ---------------------------------------------------------------------------
//		P R O T O T Y P E S
// ---------------------------------------------------------------------------

// static void printNSString(NSString *string);
// static void printArgs(int argc, const char **argv);

// ---------------------------------------------------------------------------
//		AVExporter Class Interface
// ---------------------------------------------------------------------------
@interface YVSChromaKeyImageProcessor : NSObject

@property (nonatomic, strong) NSString *programName;
@property (nonatomic, strong) NSString *exportType; // hard coded to png or tiff
@property (nonatomic, strong) NSNumber *distance;
@property (nonatomic, strong) NSNumber *slopeWidth;
@property (nonatomic, strong) NSString *redColour;
@property (nonatomic, strong) NSString *greenColour;
@property (nonatomic, strong) NSString *blueColour;
@property (nonatomic, strong) CIVector *ciColourVector;
@property (nonatomic, strong) NSURL *sourcePath;
@property (nonatomic, strong) NSURL *destinationFolder;

- (id)initWithArgs:(int)argc argv:(const char **)argv;
- (void)printUsage;
- (int)run;

@end

BOOL GetCGFloatFromString(NSString *string, CGFloat *value)
{
    NSScanner *scanner = [[NSScanner alloc] initWithString:string];
    CGFloat floatVal;
#if defined(__LP64__) && __LP64__
    BOOL gotValue = [scanner scanDouble:&floatVal];
#else
    BOOL gotValue = [scanner scanFloat:&floatVal];
#endif
    if (gotValue)
    {
        *value = floatVal;
    }
    return gotValue;
}

@implementation YVSChromaKeyImageProcessor

-(instancetype)initWithArgs:(int)argc argv:(const char **)argv
{
    self = [super init];
    if (self)
    {
        self.exportType = @"public.png";
        // Processing the args goes here.
        BOOL gotRed = NO;
        BOOL gotGreen = NO;
        BOOL gotBlue = NO;
        BOOL gotSource = NO;
        BOOL gotDestination = NO;   // Folder to save files.

        [self setProgramName:@(*argv++)];
        
        argc--;
        while (argc > 0 && **argv == '-' )
        {
            const char *args = *argv;
            
            argc--;
            argv++;
            
            if (!strcmp(args, "-source"))
            {
                NSString *sourcePath = @(*argv++);
                sourcePath = [sourcePath stringByExpandingTildeInPath];
                self.sourcePath = [[NSURL alloc] initFileURLWithPath:sourcePath];
                if (self.sourcePath)
                {
                    gotSource = YES;
                }
                argc--;
            }
            else if (!strcmp(args, "-destination"))
            {
                NSString *destFold = @(*argv++);
                destFold = [destFold stringByExpandingTildeInPath];
                NSURL *destURL = [[NSURL alloc] initFileURLWithPath:destFold
                                                        isDirectory:YES];
                self.destinationFolder = destURL;
                if (self.destinationFolder)
                {
                    gotDestination = YES;
                }
                argc--;
            }
            else if (!strcmp(args, "-distance"))
            {
                CGFloat dist;
                NSString *distance = @(*argv++);
                
                BOOL gotDistance = GetCGFloatFromString(distance, &dist);
                if (gotDistance)
                {
                    self.distance = @(dist);
                }
                argc--;
            }
            else if (!strcmp(args, "-slopewidth"))
            {
                CGFloat slopeW;
                NSString *slopeWidth = @(*argv++);
                
                BOOL gotSlopeWidth = GetCGFloatFromString(slopeWidth, &slopeW);
                if (gotSlopeWidth)
                {
                    self.slopeWidth = @(slopeW);
                }
                argc--;
            }
            else if (!strcmp(args, "-red"))
            {
                self.redColour = @(*argv++);
                gotRed = YES;
                argc--;
            }
            else if (!strcmp(args, "-green"))
            {
                self.greenColour = @(*argv++);
                gotGreen = YES;
                argc--;
            }
            else if (!strcmp(args, "-blue"))
            {
                self.blueColour = @(*argv++);
                gotBlue = YES;
                argc--;
            }
        }
        if (gotRed && gotGreen && gotBlue)
        {
            BOOL success = YES;
            CGFloat red, green, blue;
            success &= GetCGFloatFromString(self.redColour, &red);
            success &= GetCGFloatFromString(self.greenColour, &green);
            success &= GetCGFloatFromString(self.blueColour, &blue);
            if (success)
            {
                CIVector *vect = [[CIVector alloc] initWithX:red
                                                           Y:green
                                                           Z:blue
                                                           W:1.0];
                self.ciColourVector = vect;
            }
            else
            {
                red = blue = green = NO;
            }
        }
        if (!(gotRed && gotBlue && gotGreen && gotDestination && gotSource))
        {
            self = nil;
            return self;
        }
    }
    return self;
}

-(void)printUsage
{
    printf("To be implemented\n");
}

-(int)run
{
    int result = 0;
    
    // Create the image importer, and exit on failure.
    CGImageSourceRef imageSource = CGImageSourceCreateWithURL(
                                        (__bridge CFURLRef)self.sourcePath,
                                        nil);
    if (!(imageSource && CGImageSourceGetCount(imageSource)))
    {
        result = -2;
        if (imageSource)
        {
            CFRelease(imageSource);
        }
        return result;
    }
    
    // Create the image from the image source and exit on failure.
    CGImageRef image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil);
    CFRelease(imageSource);
    if (!image)
    {
        result = -3;
        return result;
    }
    
    // Create the directory where the new file is to be created if the
    // directory does not already exist.
    NSFileManager *manager = [NSFileManager defaultManager];
    [manager createDirectoryAtURL:self.destinationFolder
      withIntermediateDirectories:YES attributes:nil error:nil];
    
    // Create the full path to the file to be created.
    NSString *fileName = [self.sourcePath lastPathComponent];
    fileName = [fileName stringByDeletingPathExtension];
    fileName = [fileName stringByAppendingPathExtension:@"png"];
    NSURL *outURL = [self.destinationFolder URLByAppendingPathComponent:fileName];
    
    // Now set up the filter to be used.
    [YVSChromaKeyFilter class];
    CIFilter *filter = [CIFilter filterWithName:@"YVSChromaKeyFilter"];
    //    NSLog(@"Filter attributes: %@", [[filter attributes] description]);
    [filter setValue:self.ciColourVector forKey:@"inputColor"];
    CIImage *inCIImage = [CIImage imageWithCGImage:image];
    CGImageRelease(image);
    [filter setValue:inCIImage forKey:kCIInputImageKey];
    [filter setValue:self.ciColourVector forKey:@"inputColor"];
    if (self.distance)
    {
        [filter setValue:self.distance forKey:@"inputDistance"];
    }
    if (self.slopeWidth)
    {
        [filter setValue:self.slopeWidth forKey:@"inputSlopeWidth"];
    }
    NSLog(@"Attributes %@", [[filter attributes] description]);
    
    // OK we need to create a CGContext to draw into.
    size_t imageWidth = CGImageGetWidth(image);
    size_t imageHeight = CGImageGetHeight(image);
    size_t bytesPerRow = imageWidth * 4;
    if (bytesPerRow % 16)
        bytesPerRow += 16 - (bytesPerRow % 16);

    CGColorSpaceRef colorSpace;
    // colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGBLinear);
    colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, imageWidth, imageHeight,
                                                 8, bytesPerRow, colorSpace,
                                    (CGBitmapInfo)kCGImageAlphaPremultipliedLast);

    // CGContext created, now create the ci context.
    NSDictionary *ciContextOptions;
    ciContextOptions = @{ kCIContextWorkingColorSpace : (__bridge id)colorSpace };
    CIContext *ciContext = [CIContext contextWithCGContext:context
                                                   options:ciContextOptions];
    CGRect inOutRect = CGRectMake(0.0, 0.0,
                                  (CGFloat)imageWidth, (CGFloat)imageHeight);
    
    // Get the CIImage from the filter.
    CIImage *outImage = [filter valueForKey:kCIOutputImageKey];
    [ciContext drawImage:outImage inRect:inOutRect fromRect:inOutRect];
    
    // The image should be in my context now, so I should create image from context
    CGImageRef outCGImage = CGBitmapContextCreateImage(context);
    CGImageDestinationRef exporter = CGImageDestinationCreateWithURL(
                                            (__bridge CFURLRef)outURL,
                                            (__bridge CFStringRef)self.exportType,
                                                                     1, NULL);
    CGImageDestinationAddImage(exporter, outCGImage, nil);
    CGImageDestinationFinalize(exporter);
    CGImageRelease(outCGImage);
    CFRelease(exporter);
    return result;
}

@end

int main(int argc, const char * argv[])
{
    int result = -1;
    @autoreleasepool
    {
        //	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        @autoreleasepool
        {
            YVSChromaKeyImageProcessor* processor;
            processor = [[YVSChromaKeyImageProcessor alloc] initWithArgs:argc
                                                                    argv:argv];
            if (processor)
            {
                result = [processor run];
            }
            else
                printf("Failed to initialize\n");
        }
    }
    return result;
}
