//  main.m
//  chromakey
//
//  Created by Kevin Meaney on 20/02/2014.
//  Copyright (c) 2014 Kevin Meaney. All rights reserved.

@import Foundation;
@import QuartzCore;

#import "YVSChromaKeyFilter.h"

// ---------------------------------------------------------------------------
//		S W I T C H E S
// ---------------------------------------------------------------------------


// ---------------------------------------------------------------------------
//		P R O T O T Y P E S
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
//		YVSChromaKeyImageProcessor Class Interface
// ---------------------------------------------------------------------------
@interface YVSChromaKeyImageProcessor : NSObject
{
    CGContextRef cgContext;
}

@property (nonatomic, strong) NSString *programName;
@property (nonatomic, strong) NSString *exportType; // hard coded to png or tiff
@property (nonatomic, strong) NSNumber *distance;
@property (nonatomic, strong) NSNumber *slopeWidth;
@property (nonatomic, strong) NSString *redColour;
@property (nonatomic, strong) NSString *greenColour;
@property (nonatomic, strong) NSString *blueColour;
@property (nonatomic, strong) CIVector *ciColourVector;
@property (nonatomic, strong) NSURL *sourcePath;
@property (nonatomic, assign, getter = isSourceDirectory) BOOL sourceDirectory;
@property (nonatomic, strong) NSURL *destinationFolder;
@property (nonatomic, strong) CIContext *ciContext;
@property (nonatomic, strong) CIFilter *ciFilter;
@property (nonatomic, assign) CGContextRef cgContext; // Really retain.

-(id)initWithArgs:(int)argc argv:(const char **)argv;
+(void)printUsage;
-(CIFilter *)createCIFilter;
-(CGContextRef)getCGContextWithWidth:(size_t)width height:(size_t)height;
-(int)processFile:(NSURL *)fileURL;
-(int)run;

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

void DrawTransparentBlackToContext(CGContextRef context, size_t width,
                                   size_t height)
{
    // Now redraw to the context with transparent black.
    CGContextSaveGState(context);
    CGColorRef tBlack = CGColorCreateGenericRGB(0.0, 0.0, 0.0, 0.0);
    CGContextSetBlendMode(context, kCGBlendModeCopy);
    CGContextSetFillColorWithColor(context, tBlack);
    CGColorRelease(tBlack);
    CGRect theRect = CGRectMake(0.0, 0.0, width, height);
    CGContextFillRect(context, theRect);
    CGContextRestoreGState(context);
}

CGFloat ClipFloatToMinMax(CGFloat in, CGFloat min, CGFloat max)
{
    if (in > max)
        return max;
    if (in < min)
        return min;
    return in;
}

@implementation YVSChromaKeyImageProcessor

-(void)setCgContext:(CGContextRef)theCgContext
{
    if (self.cgContext)
        CGContextRelease(self.cgContext);
    
    if (theCgContext)
        CGContextRetain(theCgContext);
    
    self->cgContext = theCgContext;
}

-(CGContextRef)cgContext
{
    return self->cgContext;
}

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
                argc--;
                if (argc >= 0)
                {
                    NSString *sourcePath = @(*argv++);
                    sourcePath = [sourcePath stringByExpandingTildeInPath];
                    BOOL isDir, fsObjectExists;
                    fsObjectExists = [[NSFileManager defaultManager]
                                      fileExistsAtPath:sourcePath
                                      isDirectory:&isDir];
                    if (fsObjectExists)
                    {
                        NSURL *url;
                        url = [[NSURL alloc] initFileURLWithPath:sourcePath];
                        self.sourcePath = url;
                        self.sourceDirectory = isDir;
                        gotSource = YES;
                    }
                }
            }
            else if (!strcmp(args, "-destination"))
            {
                argc--;
                if (argc >= 0)
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
                }
            }
            else if (!strcmp(args, "-distance"))
            {
                argc--;
                if (argc >= 0)
                {
                    CGFloat dist;
                    NSString *distance = @(*argv++);
                    
                    BOOL gotDistance = GetCGFloatFromString(distance, &dist);
                    if (gotDistance)
                    {
                        dist = ClipFloatToMinMax(dist, 0.0, 1.7);
                        self.distance = @(dist);
                    }
                }
            }
            else if (!strcmp(args, "-slopewidth"))
            {
                argc--;
                if (argc >= 0)
                {
                    CGFloat slopeW;
                    NSString *slopeWidth = @(*argv++);
                    
                    BOOL gotSlopeWidth = GetCGFloatFromString(slopeWidth, &slopeW);
                    if (gotSlopeWidth)
                    {
                        slopeW = ClipFloatToMinMax(slopeW, 0.0, 1.7);
                        self.slopeWidth = @(slopeW);
                    }
                }
            }
            else if (!strcmp(args, "-red"))
            {
                argc--;
                if (argc >= 0)
                {
                    self.redColour = @(*argv++);
                    gotRed = YES;
                }
            }
            else if (!strcmp(args, "-green"))
            {
                argc--;
                if (argc >= 0)
                {
                    self.greenColour = @(*argv++);
                    gotGreen = YES;
                }
            }
            else if (!strcmp(args, "-blue"))
            {
                argc--;
                if (argc >= 0)
                {
                    self.blueColour = @(*argv++);
                    gotBlue = YES;
                }
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
                red = ClipFloatToMinMax(red, 0.0, 1.0);
                green = ClipFloatToMinMax(green, 0.0, 1.0);
                blue = ClipFloatToMinMax(blue, 0.0, 1.0);
                CIVector *vect = [[CIVector alloc] initWithX:red
                                                           Y:green
                                                           Z:blue
                                                           W:1.0];
                self.ciColourVector = vect;
            }
            else
            {
                gotRed = gotBlue = gotGreen = NO;
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

-(CGContextRef)getCGContextWithWidth:(size_t)width height:(size_t)height
{
    CGContextRef origContext = self.cgContext;
    if (origContext)
    {
        size_t origWidth = CGBitmapContextGetWidth(origContext);
        size_t origHeight = CGBitmapContextGetHeight(origContext);
        if (origWidth == width && origHeight == height)
        {
            // Now redraw to the context with solid white.
            DrawTransparentBlackToContext(origContext, width, height);
            return origContext;
        }
        self.cgContext = nil;
    }
    size_t bytesPerRow = width * 4;
    if (bytesPerRow % 16)
        bytesPerRow += 16 - (bytesPerRow % 16);
    
    CGColorSpaceRef colorSpace;
    // colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGBLinear);
    colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, width, height,
                                                 8, bytesPerRow, colorSpace,
                                (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    self.cgContext = context;
    
    // Now draw to the context with solid white. Remove any old alpha value.
    DrawTransparentBlackToContext(context, width, height);

    NSDictionary *ciContextOptions;
    ciContextOptions = @{ kCIContextWorkingColorSpace : (__bridge id)colorSpace,
                          kCIContextUseSoftwareRenderer : @NO };
    self.ciContext = [CIContext contextWithCGContext:self.cgContext
                                                   options:ciContextOptions];
    CFRelease(colorSpace);
    CGContextRelease(context);
    return self.cgContext;
}

-(CIFilter *)createCIFilter
{
    // Create the chroma key filter and set values.
    CIFilter *filter = [CIFilter filterWithName:@"YVSChromaKeyFilter"];
    [filter setValue:self.ciColourVector forKey:@"inputColor"];
    if (self.distance)
    {
        [filter setValue:self.distance forKey:@"inputDistance"];
    }
    if (self.slopeWidth)
    {
        [filter setValue:self.slopeWidth forKey:@"inputSlopeWidth"];
    }

    return filter;
}

-(int)processFile:(NSURL *)fileURL
{
    int result = 0;
    
    // Create the image importer, and exit on failure.
    CGImageSourceRef imageSource;
    imageSource = CGImageSourceCreateWithURL((__bridge CFURLRef)fileURL, nil);
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

    // Build the path to the file to be created.
    NSString *fileName = [fileURL lastPathComponent];
    fileName = [fileName stringByDeletingPathExtension];
    NSString *extension = CFBridgingRelease(UTTypeCopyPreferredTagWithClass(
                                (__bridge CFStringRef)self.exportType,
                                                kUTTagClassFilenameExtension));
    
    fileName = [fileName stringByAppendingPathExtension:extension];
    NSURL *outURL = [self.destinationFolder URLByAppendingPathComponent:fileName];
    
    // Get an already created graphic context or create a new one if necessary.
    size_t imageWidth = CGImageGetWidth(image);
    size_t imageHeight = CGImageGetHeight(image);
    CGContextRef context;
    context = [self getCGContextWithWidth:imageWidth height:imageHeight];

    // Obtain the filter, the createCIFilter sets values except input image.
    if (!self.ciFilter)
    {
        self.ciFilter = [self createCIFilter];
    }
    CIFilter *filter = self.ciFilter;

    CIImage *inCIImage = [CIImage imageWithCGImage:image];
    [filter setValue:inCIImage forKey:kCIInputImageKey];
    CGImageRelease(image);

    // Get the CIImage from the filter.
    CIImage *outImage = [filter valueForKey:kCIOutputImageKey];
    CGRect inOutRect = CGRectMake(0.0, 0.0,
                                  (CGFloat)imageWidth, (CGFloat)imageHeight);
    [self.ciContext drawImage:outImage inRect:inOutRect fromRect:inOutRect];
    
    // The image should be in my context now, so I should create image from context
    CGImageRef outCGImage = CGBitmapContextCreateImage(context);
    CGImageDestinationRef exporter = CGImageDestinationCreateWithURL(
                                         (__bridge CFURLRef)outURL,
                                         (__bridge CFStringRef)self.exportType,
                                         1, NULL);
    NSDictionary *options = @{ (__bridge id)
                            kCGImageDestinationLossyCompressionQuality : @1.0 };
    CGImageDestinationAddImage(exporter, outCGImage,
                               (__bridge CFDictionaryRef)options);
    CGImageDestinationFinalize(exporter);
    CGImageRelease(outCGImage);
    CFRelease(exporter);

    return result;
}

-(int)run
{
    int result = 0;

    // Set up the filter to be used.
    [YVSChromaKeyFilter class];

    // Create the directory where the new files are to be created if the
    // directory does not already exist.
    NSFileManager *manager = [NSFileManager defaultManager];
    [manager createDirectoryAtURL:self.destinationFolder
      withIntermediateDirectories:YES attributes:nil error:nil];
    
    if (self.isSourceDirectory)
    {
        NSArray *filesInDir = [manager contentsOfDirectoryAtURL:self.sourcePath
                                     includingPropertiesForKeys:nil
                                options:NSDirectoryEnumerationSkipsHiddenFiles
                                                          error:nil];
        if (filesInDir)
        {
            for (NSURL *fileURL in filesInDir)
            {
                @autoreleasepool
                {
                    // ignore result of processing file. Just because one file
                    // couldn't be processed doesn't mean the next can't.
                    [self processFile:fileURL];
                }
            }
        }
    }
    else
    {
        [self processFile:self.sourcePath];
    }
    self.cgContext = nil;
    self.ciContext = nil;
    return result;
}

+(void)printUsage
{
    printf("chromakey - usage:\n");
    printf("Based on the specified chroma key color and the chroma key distance and slope width an alpha channel is added to the image.\n");
    printf("The output file name is the same as the input file name, except for the file name extension which is replaced with png\n");
	printf("	./chromakey [-parameter <value> ...]\n");
	printf("	parameters are all preceded by a -<parameterName>.  The order of the parameters is unimportant.\n");
	printf("	Required parameters are -source <sourceFile/Folder URL> -destination <outputFolderURL> -red <X.X> -green <X.X> -blue <X.X> \n");
	printf("	Available parameters are:\n");
	printf("		-destination <outputFolderURL> The folder to export the new image file to.\n");
	printf("		-source <sourceFile/Folder URL> The source file, or \n");
    printf("		-red <X.X> The red color component value for the chroma key color. Range from 0.0 to 1.0\n");
    printf("		-green <X.X> The green color component value for the chroma key color. Range from 0.0 to 1.0\n");
    printf("		-blue <X.X> The blue color component value for the chroma key color. Range from 0.0 to 1.0\n");
	printf("		-distance <X.X> The spread of the chroma key color. Optional. Default is 0.08. Range is from 0.0 to 1.0\n");
	printf("		-slopewidth <X.X> The width of the slope in the when sliding from an alpa of 0.0 to an alpha of 1.0. Optional. Default 0.06. Range: 0.0 to 1.7\n");
	printf("	Sample chromakey uses:\n");
    printf("        A fairly wide range of colors near green that will be transparent. The small slopewidth means a sharp transition from transparent to opaque.\n");
	printf("	./chromakey -source ~/Pictures -destination ~/Desktop/junkimages -red 0.0 -green 1.0 -blue 0.0 -distance 0.2 -slopewidth 0.02\n");
    printf("		Make dark greys transparent and a gradual transition from transparent to opaque with a larger slope width.\n");
	printf("	./chromakey -source ~/Pictures -destination ~/Desktop/junkimages -red 0.2 -green 0.2 -blue 0.2 -distance 0.08 -slopewidth 0.2\n");
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
                [YVSChromaKeyImageProcessor printUsage];
        }
    }
    return result;
}
