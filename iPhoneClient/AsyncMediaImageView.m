//
//  AsyncImageView.m
//  ARIS
//
//  Created by David J Gagnon on 11/18/09.
//  Copyright 2009 University of Wisconsin - Madison. All rights reserved.
//

#import "AsyncMediaImageView.h"
#import "AppModel.h"
#import "AppServices.h"
#import "UIImage+Scale.h"

@interface AsyncMediaImageView()
{
    UIActivityIndicatorView *spinner;
}

@end

@implementation AsyncMediaImageView

@synthesize connection;
@synthesize data;
@synthesize media;
@synthesize mMoviePlayer;
@synthesize isLoading;
@synthesize loaded;
@synthesize dontUseImage;
@synthesize delegate;

-(id)initWithFrame:(CGRect)aFrame andMedia:(Media *)aMedia
{
    self.media = aMedia;
    return [self initWithFrame:aFrame andMediaId:[aMedia.uid intValue]];
}

-(id)initWithFrame:(CGRect)aFrame andMediaId:(int)mediaId
{
    if (self = [super initWithFrame:aFrame])
    {
        self.loaded = NO;
        self.contentMode = UIViewContentModeScaleAspectFill;
        self.clipsToBounds = YES;
        
        if(!media)
            media = [[AppModel sharedAppModel] mediaForMediaId:mediaId];
        
        if([media.type isEqualToString:kMediaTypeImage])
            [self loadImageFromMedia:media];
        else if([media.type isEqualToString:kMediaTypeVideo] || [media.type isEqualToString:kMediaTypeAudio])
        {
            if (self.media.image)
            {
                [self updateViewWithNewImage:[UIImage imageWithData:self.media.image]];
                self.loaded = YES;
            }
            else if([media.type isEqualToString:kMediaTypeVideo])
            {
                NSNumber *thumbTime = [NSNumber numberWithFloat:1.0f];
                NSArray *timeArray = [NSArray arrayWithObject:thumbTime];
                
                //Create movie player object
                if(!self.mMoviePlayer)
                {
                    ARISMoviePlayerViewController *mMoviePlayerAlloc = [[ARISMoviePlayerViewController alloc] initWithContentURL:[NSURL URLWithString: media.url]];
                    self.mMoviePlayer = mMoviePlayerAlloc;
                }
                else
                {
                  ARISMoviePlayerViewController *mMoviePlayerAlloc = [self.mMoviePlayer initWithContentURL:[NSURL URLWithString: media.url]]; 
                  self.mMoviePlayer = mMoviePlayerAlloc; 
                }
            
                self.mMoviePlayer.moviePlayer.shouldAutoplay = NO;
                [self.mMoviePlayer.moviePlayer requestThumbnailImagesAtTimes:timeArray timeOption:MPMovieTimeOptionNearestKeyFrame];
                 
                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(movieThumbDidFinish:) name:MPMoviePlayerThumbnailImageRequestDidFinishNotification object:self.mMoviePlayer.moviePlayer];
        
                //set up indicators
                [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
                
                //put a spinner in the view
                spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
                spinner.hidesWhenStopped = YES;
                [spinner startAnimating];
                
                spinner.center = self.center;
                [self addSubview:spinner];
                
                self.isLoading= YES;
            }
            else if ([media.type isEqualToString:kMediaTypeAudio])
            {
                UIImage *image = [UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"microphoneBackground" ofType:@"jpg"]];
                self.media.image = UIImageJPEGRepresentation(image, 1.0);
                [self updateViewWithNewImage:image];
                self.loaded = YES;
            }
        }
    }
    return self;
}

-(void)movieThumbDidFinish:(NSNotification*) aNotification
{
    NSLog(@"AsyncMediaImageView: movieThumbDidFinish");
    NSDictionary *userInfo = aNotification.userInfo;
    UIImage *videoThumb = [userInfo objectForKey:MPMoviePlayerThumbnailImageKey];

    UIImage *videoThumbSized = [videoThumb scaleToSize:self.frame.size];        
    self.media.image = UIImageJPEGRepresentation(videoThumbSized,1.0 ) ;     
    [self updateViewWithNewImage:[UIImage imageWithData:self.media.image]];

    if (self.delegate && [self.delegate respondsToSelector:@selector(imageFinishedLoading)])
        [delegate imageFinishedLoading];
    
    //end the UI indicator
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	
    //clear out the spinner
    [spinner stopAnimating];
    
    self.loaded = YES;
    self.isLoading = NO;
}

- (void)startSpinner
{
    if(!spinner)
    {
        spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        spinner.hidesWhenStopped = YES;
        [self addSubview:spinner];
    }
    
    spinner.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    spinner.color = [UIColor blackColor];
    [spinner startAnimating];
}

- (void)stopSpinner
{
    [spinner stopAnimating];
}

- (void)setSpinnerColor: (UIColor *) color
{
    spinner.color = color;
}

- (void)loadImageFromMedia:(Media *) aMedia
{
    //put a spinner in the view
    if(!spinner)
    {
        spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        spinner.hidesWhenStopped = YES;
        [self addSubview:spinner];
    }
    
    spinner.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    [spinner startAnimating];
    
    if(aMedia != self.media && aMedia.image != self.media.image)
        self.loaded = NO;
    
    self.media = aMedia;
    
    self.contentMode = UIViewContentModeScaleAspectFill;
    
    if(self.loaded)
    {
        [spinner stopAnimating];
        return;
    }

    if(self.isLoading) return;

    self.isLoading = YES;

    //check if the media already as the image, if so, just grab it
    UIImage *cachedImage = [[AppModel sharedAppModel] cachedImageForMediaId:[self.media.uid intValue]];
    if(cachedImage)
    {
        [self updateViewWithNewImage:cachedImage];
        self.loaded = YES;
        self.isLoading = NO;
        [spinner stopAnimating];
		return;
    }
    
	if (self.media.image && !dontUseImage)
    {
        [self updateViewWithNewImage:[UIImage imageWithData:self.media.image]];
        self.loaded = YES;
        self.isLoading = NO;
        [spinner stopAnimating];
		return;
	}

    if (!self.media.url)
    {
        NSLog(@"AsyncImageView: loadImageFromMedia with null url! Trying to load from server (mediaId:%d)",[self.media.uid intValue]);
        self.isLoading = NO;

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(retryLoadingMyMedia) name:@"ReceivedMediaList" object:nil];
        [[AppServices sharedAppServices] fetchMedia:[self.media.uid intValue]];
        return;
    }
	
    self.loaded = NO;

	//set up indicators
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
	
	NSLog(@"AsyncImageView: Loading Image at %@",self.media.url);
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString: self.media.url]
											 cachePolicy:NSURLRequestUseProtocolCachePolicy
										 timeoutInterval:60.0];
    connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
}

- (void)retryLoadingMyMedia
{
    NSLog(@"Failed to load media %d previously- new media list received so trying again...", [self.media.uid intValue]);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self loadImageFromMedia:[[AppModel sharedAppModel] mediaForMediaId:[self.media.uid intValue]]];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData {
    if (!self.data)
		data = [[NSMutableData alloc] initWithCapacity:2048];
    [self.data appendData:incrementalData];
}

- (void)connectionDidFinishLoading:(NSURLConnection*)theConnection {
	//end the UI indicator
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	
    //clear out the spinner
    [spinner stopAnimating];
    
	//throw out the connection
    if(self.connection!=nil)
        self.connection=nil;
	
	//turn the data into an image
	UIImage* image = [UIImage imageWithData:data];
	
	//Save the image in the media
    if(image)
        self.media.image = data;
    
    //throw out the data

    self.loaded = YES;
	self.isLoading= NO;
	[self updateViewWithNewImage:image];
    self.data=nil;
    
    NSLog(@"NSNotification: ImageReady");
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%d", [self.media.uid intValue]], @"mediaId", image, @"image", nil];
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:@"ImageReady" object:nil userInfo:userInfo]];
}

- (void)connection:(NSURLConnection *) theConnection didFailWithError:(NSError *)error
{
    self.data = nil;
    [self retryLoadingMyMedia];
}

- (void) updateViewWithNewImage:(UIImage*)image
{
    if(image)
    {
        [self setImage:image];
        if (self.delegate && [self.delegate respondsToSelector:@selector(imageFinishedLoading)])
            [delegate imageFinishedLoading];
    }
    self.isLoading = NO;
    self.loaded = YES;
}

- (void) setImage:(UIImage*)image
{
    super.image = [self resizeImage:image newSize:self.frame.size];
    
    [self setNeedsLayout];
  //  [self setNeedsDisplay];
  //  [self.superview setNeedsLayout];
}

- (UIImage *)resizeImage:(UIImage*)image newSize:(CGSize)newSize {
    CGRect newRect = CGRectIntegral(CGRectMake(0, 0, newSize.width, newSize.height));
    CGImageRef imageRef = image.CGImage;
    
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // Set the quality level to use when rescaling
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    CGAffineTransform flipVertical = CGAffineTransformMake(1, 0, 0, -1, 0, newSize.height);
    
    CGContextConcatCTM(context, flipVertical);
    // Draw into the context; this scales the image
    CGContextDrawImage(context, newRect, imageRef);
    
    // Get the resized image from the context and a UIImage
    CGImageRef newImageRef = CGBitmapContextCreateImage(context);
    UIImage *newImage = [UIImage imageWithCGImage:newImageRef];
    
    CGImageRelease(newImageRef);
    UIGraphicsEndImageContext();
    
    return newImage;
}

- (void) reset
{
    self.image = nil;
    self.data  = nil;
    self.media = nil;
    self.loaded = NO;
    self.isLoading = NO;
    [spinner stopAnimating];
    [connection cancel];
    self.connection=nil;
}

- (void)dealloc
{
    if(connection) [connection cancel];
    if(mMoviePlayer) [mMoviePlayer.moviePlayer cancelAllThumbnailImageRequests];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
