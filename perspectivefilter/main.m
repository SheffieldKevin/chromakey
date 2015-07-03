//  main.m
//  perspective filter

@import Foundation;
@import QuartzCore;

// ---------------------------------------------------------------------------
//        PerspectiveFilterProcessor Class Interface
// ---------------------------------------------------------------------------
@interface PerspectiveFilterProcessor : NSObject
{
    CGContextRef cgContext;
}

@property (nonatomic, strong) NSString *programName;
@property (nonatomic, strong) NSString *exportType; // hard coded to png or tiff
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

void DrawWhiteToContext(CGContextRef context, size_t width,
                                   size_t height)
{
    // Now redraw to the context with transparent black.
    CGContextSaveGState(context);
    CGColorRef white = CGColorCreateGenericRGB(1.0, 1.0, 1.0, 1.0);
    CGContextSetBlendMode(context, kCGBlendModeCopy);
    CGContextSetFillColorWithColor(context, white);
    CGColorRelease(white);
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

@implementation PerspectiveFilterProcessor

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
        self.exportType = @"public.png"; // defaults to png.
        
        // Processing the args goes here.
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
            else if (!strcmp(args, "-tiff"))
            {
                self.exportType = @"public.tiff";
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
        }
        if (!(gotDestination && gotSource))
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
            // Now redraw to the context with transparent black.
            DrawWhiteToContext(origContext, width, height);
            return origContext;
        }
        self.cgContext = nil;
    }
    size_t bytesPerRow = width * 4;
    if (bytesPerRow % 16)
        bytesPerRow += 16 - (bytesPerRow % 16);
    
    CGColorSpaceRef colorSpace;
    colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(NULL, width, height,
                                                 8, bytesPerRow, colorSpace,
                                                 (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    self.cgContext = context;
    
    DrawWhiteToContext(context, width, height);
    
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
    // Create the perspective transform filter and set values.
    CIFilter *filter = [CIFilter filterWithName:@"CIPerspectiveTransform"];
    [filter setDefaults];
    
    [filter setValue:@"[470 850]" forKey:@"inputTopLeft"];
    [filter setValue:@"[530 800]" forKey:@"inputTopRight"];

    [filter setValue:@"[470 150]" forKey:@"inputBottomLeft"];
    [filter setValue:@"[530 200]" forKey:@"inputBottomRight"];
    
    // [filter setValue:@"[0 0 1000 1000]" forKey:@"inputExtent"];
    
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
    // size_t imageWidth = CGImageGetWidth(image);
    // size_t imageHeight = CGImageGetHeight(image);
    size_t imageWidth = 1000;
    size_t imageHeight = 1000;
    
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
    
    // Get the CIImage from the filter.
    CIImage *outImage = [filter valueForKey:kCIOutputImageKey];
    // CIImage *outImage = [filter outputImage];
    CGRect inOutRect = CGRectMake(0.0, 0.0,
                                  (CGFloat)imageWidth, (CGFloat)imageHeight);
    [self.ciContext drawImage:outImage inRect:inOutRect fromRect:inOutRect];
    CGImageRelease(image);
    
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
    printf("Apply a perspective transform filter to images.\n\n");
    printf("perspectivefilter - usage:\n");
    printf("The output file name is the same as the input file name, except for the file name extension which is replaced with png\n");
    printf("    ./perspectivefilter [-parameter <value> ...] [-switch]\n");
    printf("    parameters are preceded by a -<parameterName>.  The order of the parameters is unimportant. There's one switch.\n");
    printf("    Required parameters are -source <sourceFile/Folder URL> -destination <outputFolderURL> \n");
    printf("    Required parameters:\n");
    printf("        -destination <outputFolderURL> The folder to export the new image file to.\n");
    printf("        -source <sourceFile/Folder URL> The source file, or folder containing images.\n");
    printf("    Switches:\n");
    printf("        -tiff Save as tiff, default is png. Saving as tiff will create larger files, but will run faster.\n");
}

@end

int main(int argc, const char * argv[])
{
    int result = -1;
    @autoreleasepool
    {
        PerspectiveFilterProcessor* processor;
        processor = [[PerspectiveFilterProcessor alloc] initWithArgs:argc
                                                                argv:argv];
        if (processor)
        {
            result = [processor run];
        }
        else
        {
            [PerspectiveFilterProcessor printUsage];
        }
    }
    return result;
}
