//
//  InnovNoteViewController.m
//  YOI
//
//  Created by Jacob James Hanshaw on 5/8/13.
//
//

#import "InnovNoteViewController.h"

#import "InnovNoteModel.h"
#import "AppServices.h"
#import "InnovAudioEnums.h"
#import "Note.h"
#import "NoteContent.h"
#import "Tag.h"
#import "Logger.h"

#import "InnovPopOverView.h"
#import "InnovPopOverSocialContentView.h"
#import "LoginViewController.h"
#import "InnovCommentViewController.h"
#import "AsyncMediaImageView.h"
#import "InnovNoteEditorViewController.h"
#import "ARISMoviePlayerViewController.h"

#define IMAGE_X_MARGIN      0
#define IMAGE_Y_MARGIN      0

#define BUTTON_WIDTH        36
#define BUTTON_HEIGHT       36

#define DEFAULT_FONT        [UIFont fontWithName:@"Helvetica" size:14]

@interface InnovNoteViewController ()<InnovNoteEditorViewDelegate>
{
    UIScrollView *noteView;
    
    AsyncMediaImageView *imageView;
    UIButton *playButton;
    UILabel  *usernameLabel;
    UIButton *flagButton;
    UIButton *likeButton;
    UIButton *shareButton;
    UIButton *commentButton;
    UITextView *captionTextView;
    
    Note *note;
    UIBarButtonItem *editButton;
    
	InnovAudioViewerModeType mode;
    ARISMoviePlayerViewController *ARISMoviePlayer;
}

@end

@implementation InnovNoteViewController

@synthesize note, delegate;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshViewFromModel) name:@"NoteModelUpdate:Notes" object:nil];
    }
    return self;
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    editButton = [[UIBarButtonItem alloc] initWithTitle: @"Edit"
                                                  style: UIBarButtonItemStyleDone
                                                 target:self
                                                 action:@selector(editButtonTouchAction:)];
    
    noteView = [[UIScrollView alloc] initWithFrame:self.view.frame];
    noteView.bounces = NO;
    [self.view addSubview:noteView];
    
    imageView = [[AsyncMediaImageView alloc] init];
    imageView.frame = CGRectMake(IMAGE_X_MARGIN,
                                 IMAGE_Y_MARGIN,
                                 self.view.frame.size.width - 2 * IMAGE_X_MARGIN,
                                 self.view.frame.size.width - 2 * IMAGE_X_MARGIN);
    [noteView addSubview:imageView];
    
    playButton  = [[UIButton alloc] initWithFrame:CGRectMake(IMAGE_X_MARGIN + imageView.frame.size.width -BUTTON_WIDTH,
                                                             IMAGE_Y_MARGIN + imageView.frame.size.height-BUTTON_HEIGHT,
                                                             BUTTON_WIDTH,
                                                             BUTTON_HEIGHT)];
    playButton.backgroundColor = [UIColor clearColor];
    [playButton setImage:[UIImage imageNamed:@"play.png"] forState:UIControlStateNormal];
    [playButton setImage:[UIImage imageNamed:@"play.png"] forState:UIControlStateHighlighted];
	[playButton addTarget:self action:@selector(playButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [noteView addSubview:playButton];
    
    usernameLabel = [[UILabel alloc] initWithFrame:CGRectMake(0,
                                                              IMAGE_Y_MARGIN + imageView.frame.size.height,
                                                              self.view.frame.size.width-4*BUTTON_WIDTH,
                                                              BUTTON_HEIGHT)];
    usernameLabel.backgroundColor = [UIColor blackColor];
    usernameLabel.textColor       = [UIColor whiteColor];
    [noteView addSubview:usernameLabel];
    
    flagButton  = [[UIButton alloc] initWithFrame:CGRectMake(usernameLabel.frame.origin.x  + usernameLabel.frame.size.width,
                                                             IMAGE_Y_MARGIN + imageView.frame.size.height,
                                                             BUTTON_WIDTH,
                                                             BUTTON_HEIGHT)];
    
    flagButton.backgroundColor = [UIColor blackColor];
    [flagButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [flagButton setTitleColor:[UIColor blueColor] forState:UIControlStateSelected];
    [flagButton setTitleColor:[UIColor blueColor] forState:UIControlStateHighlighted];
    [flagButton setTitle:@"F" forState:UIControlStateNormal];
    [flagButton setTitle:@"F" forState:UIControlStateSelected];
    [flagButton setTitle:@"F" forState:UIControlStateHighlighted];
	[flagButton addTarget:self action:@selector(flagButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [noteView addSubview:flagButton];
    
    likeButton  = [[UIButton alloc] initWithFrame:CGRectMake(flagButton.frame.origin.x  + BUTTON_WIDTH,
                                                             IMAGE_Y_MARGIN + imageView.frame.size.height,
                                                             BUTTON_WIDTH,
                                                             BUTTON_HEIGHT)];
    likeButton.backgroundColor = [UIColor blackColor];
    [likeButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [likeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected];
    [likeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
    [likeButton setBackgroundImage:[UIImage imageNamed:@"thumbs_up.png"] forState:UIControlStateNormal];
    [likeButton setBackgroundImage:[UIImage imageNamed:@"thumbs_up_selected.png"] forState:UIControlStateSelected];
    [likeButton setBackgroundImage:[UIImage imageNamed:@"thumbs_up_selected.png"] forState:UIControlStateHighlighted];
	[likeButton addTarget:self action:@selector(likeButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [noteView addSubview:likeButton];
    
    shareButton = [[UIButton alloc] initWithFrame:CGRectMake(likeButton.frame.origin.x + BUTTON_WIDTH,
                                                             IMAGE_Y_MARGIN + imageView.frame.size.height,
                                                             BUTTON_WIDTH,
                                                             BUTTON_HEIGHT)];
    shareButton.backgroundColor = [UIColor blackColor];
    [shareButton setTitle:@"S" forState:UIControlStateNormal];
    [shareButton setTitle:@"S" forState:UIControlStateHighlighted];
	[shareButton addTarget:self action:@selector(shareButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [noteView addSubview:shareButton];
    
    commentButton = [[UIButton alloc] initWithFrame:CGRectMake(shareButton.frame.origin.x + BUTTON_WIDTH,
                                                               IMAGE_Y_MARGIN + imageView.frame.size.height,
                                                               BUTTON_WIDTH,
                                                               BUTTON_HEIGHT)];
    commentButton.backgroundColor = [UIColor blackColor];
    [commentButton setTitle:@"C" forState:UIControlStateNormal];
    [commentButton setTitle:@"C" forState:UIControlStateHighlighted];
	[commentButton addTarget:self action:@selector(commentButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [noteView addSubview:commentButton];
    
    captionTextView = [[UITextView alloc] initWithFrame:CGRectMake(0,
                                                                   IMAGE_Y_MARGIN + imageView.frame.size.height + BUTTON_HEIGHT,
                                                                   self.view.frame.size.width,
                                                                   BUTTON_HEIGHT)];
    captionTextView.contentInset = UIEdgeInsetsMake(-8,-4,-8,-4);
    captionTextView.userInteractionEnabled = NO;
    captionTextView.font = DEFAULT_FONT;
    [noteView addSubview:captionTextView];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear: animated];
    
    UIGraphicsBeginImageContext(CGSizeMake(1,1));
    ARISMoviePlayer = [[ARISMoviePlayerViewController alloc] init];
    ARISMoviePlayer.view.frame = CGRectMake(0, 0, 1, 1);
    ARISMoviePlayer.moviePlayer.view.hidden    = YES;
    ARISMoviePlayer.moviePlayer.shouldAutoplay = YES;
    [ARISMoviePlayer.moviePlayer setFullscreen:NO];
    ARISMoviePlayer.moviePlayer.movieSourceType = MPMovieSourceTypeStreaming;
    [ARISMoviePlayer.moviePlayer setControlStyle:MPMovieControlStyleNone];
    [noteView addSubview:ARISMoviePlayer.view];
    UIGraphicsEndImageContext();
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(MPMoviePlayerPlaybackStateDidChange:)        name:MPMoviePlayerPlaybackStateDidChangeNotification object:ARISMoviePlayer.moviePlayer];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(MPMoviePlayerPlaybackDidFinishNotification:) name:MPMoviePlayerPlaybackDidFinishNotification      object:ARISMoviePlayer.moviePlayer];
    
    if([AppModel sharedAppModel].playerId == self.note.creatorId)
        self.navigationItem.rightBarButtonItem = editButton;
    else
        self.navigationItem.rightBarButtonItem = nil;
    
    if([self.note.tags count] > 0)
        self.title = ((Tag *)[self.note.tags objectAtIndex:0]).tagName;
    else
        self.title = @"Note";
    
    usernameLabel.text = ([note.displayname length] > 0) ? note.displayname : note.username;
    
    mode = kInnovAudioPlayerNoAudio;
    [self updatePlayButtonForCurrentMode];
    
    [self refreshViewFromModel];
    [[AppServices sharedAppServices] fetchNote:self.note.noteId];
}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerPlaybackStateDidChangeNotification object:ARISMoviePlayer.moviePlayer];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerPlaybackDidFinishNotification      object:ARISMoviePlayer.moviePlayer];
    ARISMoviePlayer = nil;
}

#pragma mark Refresh

- (void)refreshViewFromModel
{
    self.note = [[InnovNoteModel sharedNoteModel] noteForNoteId:self.note.noteId];
    [self updateLikeButton];
    [flagButton setSelected:self.note.userFlagged];
    
    [imageView loadImageFromMedia:[[AppModel sharedAppModel] mediaForMediaId:note.imageMediaId]];
    
    if(note.audioMediaId)
    {
        NSString *audioURL = [[AppModel sharedAppModel] mediaForMediaId:note.audioMediaId].url;
        if (![[ARISMoviePlayer.moviePlayer.contentURL absoluteString] isEqualToString: audioURL]) {
            [ARISMoviePlayer.moviePlayer setContentURL: [NSURL URLWithString:audioURL]];
            [ARISMoviePlayer.moviePlayer prepareToPlay];
        }
        mode = kInnovAudioPlayerAudio;
        [self updatePlayButtonForCurrentMode];
    }
    
    captionTextView.text = note.text;
    
    CGRect frame = captionTextView.frame;
    frame.size.height = captionTextView.contentSize.height;
    captionTextView.frame = frame;
    if(!([captionTextView.text length] > 0))
        captionTextView.hidden = YES;
    noteView.contentSize = CGSizeMake(self.view.frame.size.width, IMAGE_Y_MARGIN + imageView.frame.size.height + BUTTON_HEIGHT + captionTextView.frame.size.height);
}

#pragma mark Button methods

- (void)editButtonTouchAction: (id) sender
{
    InnovNoteEditorViewController *editVC = [[InnovNoteEditorViewController alloc] init];
    editVC.note = self.note;
    editVC.delegate = self.delegate;
    [self.navigationController pushViewController:editVC animated:YES];
}

- (void)playButtonPressed:(id)sender
{
	switch (mode) {
		case kInnovAudioPlayerNoAudio:
            break;
		case kInnovAudioPlayerPlaying:
            mode = kInnovAudioPlayerAudio;
            [ARISMoviePlayer.moviePlayer stop];
            [self updatePlayButtonForCurrentMode];
            break;
			
		case kInnovAudioPlayerAudio:
            mode = kInnovAudioPlayerPlaying;
            [ARISMoviePlayer.moviePlayer play];
			[self updatePlayButtonForCurrentMode];
            break;
		default:
			break;
	}
}

- (void)flagButtonPressed:(id)sender
{
    if([AppModel sharedAppModel].playerId == 0)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Must Be Logged In" message:@"You must be logged in to flag notes." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Log In", nil];
        [alert show];
    }
    else
    {
        if(self.note.userFlagged)
        {
            self.note.userFlagged = !flagButton.selected;
            [[AppServices sharedAppServices]unFlagNote:self.note.noteId];
            [flagButton setSelected:self.note.userFlagged];
        }
        else
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Are You Sure?" message:@"Are you sure you want to mark this content as inappropriate?" delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
            [alert show];
        }
        
    }
}

- (void)likeButtonPressed:(id)sender
{
    if([AppModel sharedAppModel].playerId == 0)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Must Be Logged In" message:@"You must be logged in to like notes." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Log In", nil];
        [alert show];
    }
    else
    {
        self.note.userLiked = !likeButton.selected;
        if(self.note.userLiked)
        {
            [[AppServices sharedAppServices]likeNote:self.note.noteId];
            self.note.numRatings++;
        }
        else
        {
            [[AppServices sharedAppServices] unLikeNote:self.note.noteId];
            self.note.numRatings--;
        }
        [self updateLikeButton];
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if([alertView.title isEqualToString:@"Must Be Logged In"] && buttonIndex != 0)
    {
        LoginViewController *logInVC = [[LoginViewController alloc] init];
        [self.navigationController pushViewController:logInVC animated:YES];
    }
    else if(buttonIndex != 0)
    {
        self.note.userFlagged = !flagButton.selected;
        [[AppServices sharedAppServices]flagNote:self.note.noteId];
        [flagButton setSelected:self.note.userFlagged];
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Thank You" message:@"Thank you for your input. We will look into the matter further and remove inappropriate content." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles: nil];
        [alert show];
    }
}

- (void)shareButtonPressed:(id)sender
{
    InnovPopOverSocialContentView *socialContent = [[InnovPopOverSocialContentView alloc] init];
    socialContent.note = self.note;
    [socialContent refreshBadges];
    InnovPopOverView *popOver = [[InnovPopOverView alloc] initWithFrame:self.view.frame andContentView:socialContent];
    CGRect newFrame = socialContent.frame;
    newFrame.origin.y -= NAV_BAR_HEIGHT;
    [popOver adjustContentFrame:newFrame];
    [self.view addSubview:popOver];
}

- (void)commentButtonPressed:(id)sender
{
    InnovCommentViewController *commentVC = [[InnovCommentViewController alloc] init];
    commentVC.note = self.note;
    [self.navigationController pushViewController:commentVC animated:YES];
}

#pragma mark Update Button Appearance

- (void)updatePlayButtonForCurrentMode
{
    playButton.hidden = NO;
    switch (mode)
    {
		case kInnovAudioPlayerNoAudio:
            playButton.hidden = YES;
			break;
		case kInnovAudioPlayerAudio:
            [playButton setImage:[UIImage imageNamed:@"play.png"] forState:UIControlStateNormal];
            [playButton setImage:[UIImage imageNamed:@"play.png"] forState:UIControlStateHighlighted];
			break;
		case kInnovAudioPlayerPlaying:
            [playButton setImage:[UIImage imageNamed:@"stop_button.png"] forState:UIControlStateNormal];
            [playButton setImage:[UIImage imageNamed:@"stop_button.png"] forState:UIControlStateHighlighted];
			break;
		default:
			break;
	}
}

- (void)updateLikeButton
{
    [likeButton setSelected:self.note.userLiked];
    [likeButton setTitle:[NSString stringWithFormat:@"%d",self.note.numRatings] forState:UIControlStateNormal];
    [likeButton setTitle:[NSString stringWithFormat:@"%d",self.note.numRatings] forState:UIControlStateSelected];
    [likeButton setTitle:[NSString stringWithFormat:@"%d",self.note.numRatings] forState:UIControlStateHighlighted];
}

#pragma mark MPMoviePlayerController notifications

- (void)MPMoviePlayerPlaybackStateDidChange:(NSNotification *)notification
{
    if (ARISMoviePlayer.moviePlayer.playbackState == MPMoviePlaybackStatePlaying)
    {
        mode = kInnovAudioPlayerPlaying;
        [self updatePlayButtonForCurrentMode];
    }
}

- (void)MPMoviePlayerPlaybackDidFinishNotification:(NSNotification *)notif
{
    if (mode == kInnovAudioPlayerPlaying)
        [self playButtonPressed:nil];
}

#pragma mark Remove Memory

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

@end