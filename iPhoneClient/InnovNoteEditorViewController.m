//
//  InnovNoteEditorViewController.m
//  ARIS
//
//  Created by Jacob Hanshaw on 4/5/13.
//
//

#import "InnovNoteEditorViewController.h"
#import "AppModel.h"
#import "AppServices.h"
#import "InnovViewController.h"
#import "CameraViewController.h"
#import "Tag.h"
#import "TagCell.h"
#import "Logger.h"

#define DEFAULTTEXT @"Write a caption..."

@interface InnovNoteEditorViewController ()

@end

@implementation InnovNoteEditorViewController

@synthesize note, delegate, isEditing;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshViewFromModel) name:@"NewNoteListReady" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshCategories)    name:@"NewTagListReady"  object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(recordButtonPressed:) name:MPMoviePlayerLoadStateDidChangeNotification object:ARISMoviePlayer.moviePlayer];
        
        tagList = [[NSMutableArray alloc]initWithCapacity:10];
    }
    return self;
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    cancelButton = [[UIBarButtonItem alloc] initWithTitle: @"Cancel"
                                                    style: UIBarButtonItemStyleDone
                                                   target:self
                                                   action:@selector(backButtonTouchAction:)];
    self.navigationItem.leftBarButtonItem = cancelButton;
    
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle: @"Share"
                                                                   style: UIBarButtonItemStyleDone
                                                                  target:self
                                                                  action:@selector(backButtonTouchAction:)];
    self.navigationItem.rightBarButtonItem = doneButton;
    
    imageView.delegate = self;
    
    [[AVAudioSession sharedInstance] setDelegate: self];
    NSString *tempDir = NSTemporaryDirectory ();
    NSString *soundFilePath =[tempDir stringByAppendingString: [NSString stringWithFormat:@"%@.caf",[self getUniqueId]]];
    soundFileURL = [[NSURL alloc] initFileURLWithPath: soundFilePath];
    
    [self refreshCategories];
    
    ARISMoviePlayer = [[ARISMoviePlayerViewController alloc] init];
    ARISMoviePlayer.view.frame = CGRectMake(0, 0, 1, 1);
    ARISMoviePlayer.moviePlayer.view.hidden = YES;
    [self.view addSubview:ARISMoviePlayer.view];
    ARISMoviePlayer.moviePlayer.movieSourceType = MPMovieSourceTypeStreaming;
    [ARISMoviePlayer.moviePlayer setControlStyle:MPMovieControlStyleNone];
    [ARISMoviePlayer.moviePlayer setFullscreen:NO];
    
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear: animated];
    
    if(self.note.noteId != 0)
    {
#warning when do we edit
        isEditing = YES;
        newNote = NO;
        
        captionTextView.text = self.note.title;
        
        imageView.userInteractionEnabled = YES;
        
        if([self.note.tags count] > 0){
            originalTagId = ((Tag *)[self.note.tags objectAtIndex:0]).tagId;
            originalTagName = ((Tag *)[self.note.tags objectAtIndex:0]).tagName;
            [tagTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:[tagList indexOfObject:((Tag *)[self.note.tags objectAtIndex:0])] inSection:0]].accessoryType = UITableViewCellAccessoryCheckmark;
        }
        else [self tableView:tagTableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
        
        NSError *error;
        [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryPlayAndRecord error: &error];
        [[Logger sharedLogger] logError:error];
        [[AVAudioSession sharedInstance] setActive: YES error: &error];
        [[Logger sharedLogger] logError:error];
        
        mode = kInnovAudioRecorderNoAudio;
        [self updateButtonsForCurrentMode];
        hasAudioToUpload = NO;
        
        [self refreshViewFromModel];
    }
    
    else
    {
        self.note = [[Note alloc] init];
        self.note.title =  DEFAULTTEXT;
        self.note.creatorId = [AppModel sharedAppModel].playerId;
        self.note.username = [AppModel sharedAppModel].userName;
        self.note.noteId = [[AppServices sharedAppServices] createNoteStartIncomplete];
        self.note.showOnList = YES;
        self.note.showOnMap  = YES;
        isEditing = NO;
        newNote = YES;
        originalTagName = nil;
#warning should allows show on List and Map?
        if(self.note.noteId == 0)
        {
            UIAlertView *alert = [[UIAlertView alloc]initWithTitle: NSLocalizedString(@"NoteEditorCreateNoteFailedKey", @"") message: NSLocalizedString(@"NoteEditorCreateNoteFailedMessageKey", @"") delegate:self.delegate cancelButtonTitle: NSLocalizedString(@"OkKey", @"") otherButtonTitles: nil];
            [alert show];
            cancelled = YES;
            [self.navigationController popViewControllerAnimated:YES];
            return;
        }
        captionTextView.text = DEFAULTTEXT;
        captionTextView.textColor = [UIColor lightGrayColor];
        
        imageView.userInteractionEnabled = NO;
        
        [[AppModel sharedAppModel].playerNoteList setObject:note forKey:[NSNumber numberWithInt:note.noteId]];
        
        [self cameraButtonTouchAction];
    }
    
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
#warning Called twice
    
    if(!self.note || newNote || cancelled) return;
    
    if([captionTextView.text isEqualToString:DEFAULTTEXT] || [captionTextView.text length] == 0) self.note.title = @"";
    else self.note.title = captionTextView.text;
    [[AppServices sharedAppServices] updateNoteWithNoteId:self.note.noteId title:self.note.title publicToMap:self.note.showOnMap publicToList:self.note.showOnList];
    [[AppServices sharedAppServices] setNoteCompleteForNoteId:self.note.noteId];
    
    if(mode == kInnovAudioRecorderRecording) [self recordButtonPressed:nil];
    if(hasAudioToUpload) [[[AppModel sharedAppModel]uploadManager] uploadContentForNoteId:self.note.noteId withTitle:[NSString stringWithFormat:@"%@",[NSDate date]] withText:nil withType:kNoteContentTypeAudio withFileURL:soundFileURL];
    
    
    if(![originalTagName isEqualToString:newTagName])
        [[AppServices sharedAppServices] deleteTagFromNote:self.note.noteId tagId:originalTagId];
    
    [[AppServices sharedAppServices] addTagToNote:self.note.noteId tagName:newTagName];
    
    Tag *tag = [[Tag alloc] init];
    tag.tagName = newTagName;
    [self.note.tags addObject:tag];
    
    if([delegate isKindOfClass:[InnovViewController class]]) ((InnovViewController *)self.delegate).noteToAdd = self.note;
    
    [[AppModel sharedAppModel].playerNoteList setObject:self.note forKey:[NSNumber numberWithInt:self.note.noteId]];
    
#warning point where added to map may change
    [[AppServices sharedAppServices] dropNote:self.note.noteId atCoordinate:[AppModel sharedAppModel].playerLocation.coordinate];
    self.note.dropped = YES;
    
    NSError *error;
    [[AVAudioSession sharedInstance] setActive: NO error: &error];
    [[Logger sharedLogger] logError:error];
    
    self.note = nil;
}

- (IBAction)backButtonTouchAction: (id) sender
{
    cancelled = ([sender isKindOfClass: [UIBarButtonItem class]] && [((UIBarButtonItem *) sender).title isEqualToString:@"Cancel"]);
    if(!isEditing && !([sender isKindOfClass: [UIBarButtonItem class]] && [((UIBarButtonItem *) sender).title isEqualToString:@"Share"]))
    {
        [[AppServices sharedAppServices] deleteNoteWithNoteId:self.note.noteId];
        [[AppModel sharedAppModel].playerNoteList removeObjectForKey:[NSNumber numberWithInt:self.note.noteId]];
        
    }
    
    NSError *error;
    [[AVAudioSession sharedInstance] setActive: NO error: &error];
    [[Logger sharedLogger] logError:error];
    
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark UITextView methods

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [captionTextView resignFirstResponder];
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    textView.textColor = [UIColor blackColor];
    if([textView.text isEqualToString:DEFAULTTEXT]) textView.text = @"";
}

#pragma mark UIImageView methods

-(void) asyncMediaImageTouched:(id)sender
{
    [self cameraButtonTouchAction];
}

-(void)cameraButtonTouchAction
{
    CameraViewController *cameraVC = [[CameraViewController alloc] init];
    
    if(isEditing) cameraVC.backView = self;
    else cameraVC.backView = self.delegate;
    cameraVC.parentDelegate = self.delegate;
    cameraVC.showCamera = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
    cameraVC.editView = self;
    cameraVC.noteId = self.note.noteId;
    
    [self.navigationController pushViewController:cameraVC animated:NO];
}

/*
 [[AppServices sharedAppServices]deleteNoteLocationWithNoteId:self.note.noteId];
 
 DropOnMapViewController *mapVC = [[DropOnMapViewController alloc] initWithNibName:@"DropOnMapViewController" bundle:nil] ;
 mapVC.noteId = self.note.noteId;
 mapVC.delegate = self;
 self.noteValid = YES;
 self.mapButton.selected = YES;
 
 [self.navigationController pushViewController:mapVC animated:NO];
 
 
 [[AppServices sharedAppServices] updateNoteWithNoteId:self.note.noteId title:self.textField.text publicToMap:self.note.showOnMap publicToList:self.note.showOnList];
 */

#pragma mark Note Contents

- (void)refreshViewFromModel
{
    note = [[[AppModel sharedAppModel] playerNoteList] objectForKey:[NSNumber numberWithInt:note.noteId]];
    [self addCDUploadsToNote];
    
    for(int i = 0; i < [self.note.contents count]; ++i)
    {
        NoteContent *noteContent = [self.note.contents objectAtIndex:i];
        if([[noteContent getType] isEqualToString:kNoteContentTypePhoto]) {
            [imageView loadImageFromMedia:[noteContent getMedia]];
        }
        else if ([[noteContent getType] isEqualToString:kNoteContentTypeAudio]) {
            if (![[ARISMoviePlayer.moviePlayer.contentURL absoluteString] isEqualToString: noteContent.getMedia.url]) {
                [ARISMoviePlayer.moviePlayer setContentURL: [NSURL URLWithString:noteContent.getMedia.url]];
                [ARISMoviePlayer.moviePlayer prepareToPlay];
			}
            mode = kInnovAudioRecorderAudio;
            [self updateButtonsForCurrentMode];
        }
#warning test moviePlayer Audio
    }
}

-(void)addCDUploadsToNote
{
    for(int x = [self.note.contents count]-1; x >= 0; x--)
    {
        //Removes note contents that are not done uploading, because they will all be added again right after this loop
        if((NSObject <NoteContentProtocol> *)[[self.note.contents objectAtIndex:x] managedObjectContext] == nil ||
           ![[[self.note.contents objectAtIndex:x] getUploadState] isEqualToString:@"uploadStateDONE"])
            [self.note.contents removeObjectAtIndex:x];
    }
    
    NSArray *uploadContentsForNote = [[[AppModel sharedAppModel].uploadManager.uploadContentsForNotes objectForKey:[NSNumber numberWithInt:self.note.noteId]]allValues];
    [self.note.contents addObjectsFromArray:uploadContentsForNote];
    NSLog(@"InnovNoteEditorVC: Added %d upload content(s) to note",[uploadContentsForNote count]);
}

#pragma mark Audio Methods

- (NSString *)getUniqueId
{
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    CFStringRef string = CFUUIDCreateString(NULL, theUUID);
    CFRelease(theUUID);
    return (__bridge NSString *)string;
}

- (void)updateButtonsForCurrentMode{
    
	[deleteAudioButton setTitle: NSLocalizedString(@"DiscardKey", @"") forState: UIControlStateNormal];
	[deleteAudioButton setTitle: NSLocalizedString(@"DiscardKey", @"") forState: UIControlStateHighlighted];
    
    switch (mode) {
		case kInnovAudioRecorderNoAudio:
			[recordButton setTitle: NSLocalizedString(@"BeginRecordingKey", @"") forState: UIControlStateNormal];
			[recordButton setTitle: NSLocalizedString(@"BeginRecordingKey", @"") forState: UIControlStateHighlighted];
			deleteAudioButton.hidden = YES;
			break;
		case kInnovAudioRecorderRecording:
			[recordButton setTitle: NSLocalizedString(@"StopRecordingKey", @"") forState: UIControlStateNormal];
			[recordButton setTitle: NSLocalizedString(@"StopRecordingKey", @"") forState: UIControlStateHighlighted];
			deleteAudioButton.hidden = YES;
			break;
		case kInnovAudioRecorderAudio:
			[recordButton setTitle: NSLocalizedString(@"PlayKey", @"") forState: UIControlStateNormal];
			[recordButton setTitle: NSLocalizedString(@"PlayKey", @"") forState: UIControlStateHighlighted];
			deleteAudioButton.hidden = NO;
			break;
		case kInnovAudioRecorderPlaying:
			[recordButton setTitle: NSLocalizedString(@"StopKey", @"") forState: UIControlStateNormal];
			[recordButton setTitle: NSLocalizedString(@"StopKey", @"") forState: UIControlStateHighlighted];
			deleteAudioButton.hidden = YES;
			break;
            
		default:
			break;
	}
}

- (IBAction)recordButtonPressed:(id)sender
{
	NSError *error;
	
	switch (mode) {
		case kInnovAudioRecorderNoAudio:
        {
            
			NSDictionary *recordSettings = [[NSDictionary alloc] initWithObjectsAndKeys:
											[NSNumber numberWithInt:kAudioFormatAppleIMA4],     AVFormatIDKey,
											[NSNumber numberWithInt:16000.0],                   AVSampleRateKey,
											[NSNumber numberWithInt: 1],                        AVNumberOfChannelsKey,
											[NSNumber numberWithInt: AVAudioQualityMin],        AVSampleRateConverterAudioQualityKey,
											nil];
            
			soundRecorder = [[AVAudioRecorder alloc] initWithURL: soundFileURL settings: recordSettings error: &error];
			[[Logger sharedLogger] logError:error];
            
			soundRecorder.delegate = self;
			[soundRecorder setMeteringEnabled:YES];
			[soundRecorder prepareToRecord];
			
			
			BOOL audioHWAvailable = [[AVAudioSession sharedInstance] inputIsAvailable];
			if (!audioHWAvailable) {
				UIAlertView *cantRecordAlert =
				[[UIAlertView alloc] initWithTitle: NSLocalizedString(@"NoAudioHardwareAvailableTitleKey", @"")
										   message: NSLocalizedString(@"NoAudioHardwareAvailableMessageKey", @"")
										  delegate: nil
								 cancelButtonTitle: NSLocalizedString(@"OkKey",@"")
								 otherButtonTitles:nil];
				[cantRecordAlert show];
				return;
			}
			
			[soundRecorder record];
            
			recordLengthCutoffTimer = [NSTimer scheduledTimerWithTimeInterval:30
                                                                       target:self
                                                                     selector:@selector(recordButtonPressed:)
                                                                     userInfo:nil
                                                                      repeats:NO];
            
			mode = kInnovAudioRecorderRecording;
			[self updateButtonsForCurrentMode];
        }
            break;
			
		case kInnovAudioRecorderPlaying:
        {
			[ARISMoviePlayer.moviePlayer stop];
            
            mode = kInnovAudioRecorderAudio;
			[self updateButtonsForCurrentMode];
        }
            break;
			
		case kInnovAudioRecorderAudio:
        {
            
            if(hasAudioToUpload)
            {
                if (soundPlayer == nil)
                {
                    soundPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:soundFileURL error:&error];
                    [[Logger sharedLogger] logError:error];
                    [soundPlayer prepareToPlay];
                    [soundPlayer setDelegate: self];
                }
                [soundPlayer play];
            }
            else
                [ARISMoviePlayer.moviePlayer play];
            
			
			mode = kInnovAudioRecorderPlaying;
			[self updateButtonsForCurrentMode];
			
        }
            break;
			
		case kInnovAudioRecorderRecording:
        {
            [recordLengthCutoffTimer invalidate];
			
			[soundRecorder stop];
			soundRecorder = nil;
            
            hasAudioToUpload = YES;
            
			mode = kInnovAudioRecorderAudio;
			[self updateButtonsForCurrentMode];
        }
            break;
			
		default:
			break;
	}
	
}


- (IBAction)deleteAudioButtonPressed:(id)sender
{
    if(hasAudioToUpload) hasAudioToUpload = NO;
    else
    {
        for(int i = 0; i < [note.contents count]; ++i)
        {
            NoteContent *noteContent = [self.note.contents objectAtIndex:i];
            if([[noteContent getType] isEqualToString:kNoteContentTypeAudio])
            {
                if([[noteContent getUploadState] isEqualToString:@"uploadStateDONE"])
                    [[AppServices sharedAppServices] deleteNoteContentWithContentId:[noteContent getContentId]];
                else
                    [[AppModel sharedAppModel].uploadManager deleteContentFromNoteId:self.note.noteId andFileURL:[NSURL URLWithString:[[noteContent getMedia] url]]];
                
                [self.note.contents removeObjectAtIndex:i];
            }
        }
    }
    
	soundPlayer = nil;
	mode = kInnovAudioRecorderNoAudio;
	[self updateButtonsForCurrentMode];
}

/*
 - (void)updateMeter {
 [soundRecorder updateMeters];
 float levelInDb = [soundRecorder averagePowerForChannel:0];
 levelInDb = levelInDb + 160;
 
 //Level will always be between 0 and 160 now
 //Usually it will sit around 100 in quiet so we need to correct
 levelInDb = MAX(levelInDb - 100,0);
 float levelInZeroToOne = levelInDb / 60;
 
 NSLog(@"AudioRecorderLevel: %f, level in float:%f",levelInDb,levelInZeroToOne);
 
 self.meter updateLevel:levelInZeroToOne];
 }
 */

#pragma mark Audio Recorder Delegate Metods

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag
{
	//[self.meterUpdateTimer invalidate];
	//[self.meter updateLevel:0];
	//self.meter.alpha = 0.0;
	
	mode = kInnovAudioRecorderAudio;
	[self updateButtonsForCurrentMode];
    
}

#pragma mark Audio Player Delegate Methods

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
	mode = kInnovAudioRecorderAudio;
	[self updateButtonsForCurrentMode];
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error {
	[[Logger sharedLogger] logError:error];
}


#pragma mark Table view methods

-(void)refreshCategories
{
    [tagList removeAllObjects];
    for(int i = 0; i < [[AppModel sharedAppModel].gameTagList count];i++){
        [tagList addObject:[[AppModel sharedAppModel].gameTagList objectAtIndex:i]];
        
        if([((Tag *)[tagList objectAtIndex:i]).tagName isEqualToString:newTagName])
            [tagTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]].accessoryType = UITableViewCellAccessoryCheckmark;
    }
    [tagTableView reloadData];
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case 0:
            if(tagList.count > 0)
                return [tagList count];
            else
                return 1;
            break;
        default:
            break;
    }
    return 1;
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
    switch (section) {
        case 0:
            return @"Categories";
            break;
        default:
            break;
    }
    return @"ERROR";
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *tempCell = (TagCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (![tempCell respondsToSelector:@selector(nameLabel)]) tempCell = nil;
    TagCell *cell = (TagCell *)tempCell;
    
    
    if (cell == nil) {
        // Create a temporary UIViewController to instantiate the custom cell.
        UIViewController *temporaryController = [[UIViewController alloc] initWithNibName:@"TagCell" bundle:nil];
        // Grab a pointer to the custom cell.
        cell = (TagCell *)temporaryController.view;
        // Release the temporary UIViewController.
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
    }
    
    if([tagList count] == 0) cell.nameLabel.text = @"No Categories in Application";
    else cell.nameLabel.text = ((Tag *)[tagList objectAtIndex:indexPath.row]).tagName;
    
    return cell;
}

-(NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    //Not considered selected when auto set to first row, so clear first row
    [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]].accessoryType = UITableViewCellAccessoryNone;
    
    NSIndexPath *oldIndex = [tableView indexPathForSelectedRow];
    [tableView cellForRowAtIndexPath:oldIndex].accessoryType = UITableViewCellAccessoryNone;
    return indexPath;
    
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    TagCell *cell = (TagCell *)[tableView cellForRowAtIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryCheckmark;
    
    newTagName = cell.nameLabel.text;
    [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
    
    self.title = newTagName;
}


#pragma mark Autorotation, Dealloc, and Other Necessary Methods

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

-(BOOL)shouldAutorotate
{
    return YES;
}

-(NSInteger)supportedInterfaceOrientations
{
    NSInteger mask = 0;
    if ([self shouldAutorotateToInterfaceOrientation: UIInterfaceOrientationLandscapeLeft])
        mask |= UIInterfaceOrientationMaskLandscapeLeft;
    if ([self shouldAutorotateToInterfaceOrientation: UIInterfaceOrientationLandscapeRight])
        mask |= UIInterfaceOrientationMaskLandscapeRight;
    if ([self shouldAutorotateToInterfaceOrientation: UIInterfaceOrientationPortrait])
        mask |= UIInterfaceOrientationMaskPortrait;
    if ([self shouldAutorotateToInterfaceOrientation: UIInterfaceOrientationPortraitUpsideDown])
        mask |= UIInterfaceOrientationMaskPortraitUpsideDown;
    return mask;
}

- (void)dealloc
{
    [[AVAudioSession sharedInstance] setDelegate: nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidUnload {
    imageView = nil;
    captionTextView = nil;
    recordButton = nil;
    deleteAudioButton = nil;
    tagTableView = nil;
    [super viewDidUnload];
}


@end