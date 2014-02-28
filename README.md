chromakey
=========

A custom chroma key Core Image Filter (CIFilter) built into a command line tool.

### Uses

Objective-C, Cocoa, OS X, CoreImage.

### Produced

A command line tool "chromakey", Custom core image filter "YVSChromaKeyFilter" that inherits from CIFilter and implements its own custom kernel.

### Requirements

10.9, Xcode 5.0.1.

The following is a print usage output produced if you call the command line tool without any parameters.

	Add to image transparency based on a chroma key color, color difference and slope width.

	chromakey - usage:
	Based on a chroma key color and the distance and slope width transparency is added to the image.
	The output file name is the same as the input file name, except for the file name extension which is replaced with png
		./chromakey [-parameter <value> ...] [-switch]
		parameters are preceded by a -<parameterName>.  The order of the parameters is unimportant. There's one switch.
		Required parameters are -source <sourceFile/Folder URL> -destination <outputFolderURL> -red <X.X> -green <X.X> -blue <X.X> 
		Required parameters:
			-destination <outputFolderURL> The folder to export the new image file to.
			-source <sourceFile/Folder URL> The source file, or folder containing images.
			-red <X.X> The red color component value for the chroma key color. Range: 0.0 to 1.0
			-green <X.X> The green color component value for the chroma key color. Range: 0.0 to 1.0
			-blue <X.X> The blue color component value for the chroma key color. Range: 0.0 to 1.0
		Optional parameters:
			-distance <X.X> The spread of the chroma key color. Default is 0.08. Range: 0.0 to 1.0
			-slopewidth <X.X> The width of the slope when sliding from alpha 0.0 to 1.0. Default 0.06. Range: 0.0 to 1.0
		Switches:
			-tiff Save as tiff, default is png. Saving as tiff will create larger files, but will run faster.
		Sample chromakey uses:
			A fairly wide range of colors near green that will be transparent. A small slopewidth means a sharp transition from transparent to opaque.
				./chromakey -source ~/Pictures -destination ~/Desktop/junkimages -red 0.0 -green 1.0 -blue 0.0 -distance 0.2 -slopewidth 0.02
			Make dark greys transparent and a gradual transition from transparent to opaque with a larger slope width. Save as tiff.
				./chromakey -tiff -source ~/Pictures -destination ~/Desktop/junkimages -red 0.2 -green 0.2 -blue 0.2 -distance 0.08 -slopewidth 0.2
