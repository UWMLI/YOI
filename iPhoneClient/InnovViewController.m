
//
//  InnovViewController.m
//  ARIS
//
//  Created by Jacob Hanshaw on 3/25/13.
//
//

#import "InnovViewController.h"

#import "AppModel.h"
#import "AppServices.h"
#import "SifterAppDelegate.h"
#import "Note.h"
#import "InnovNoteModel.h"
#import "InnovPresentNoteDelegate.h"

#import "InnovSettingsView.h"
#import "InnovPopOverView.h"
#import "InnovPopOverNotifContentView.h"
#import "LoginViewController.h"
#import "InnovMapViewController.h"
#import "InnovListViewController.h"
#import "InnovSelectedTagsViewController.h"
#import "InnovNoteViewController.h"
#import "InnovNoteEditorViewController.h"

#define SWITCH_VIEWS_ANIMATION_DURATION 0.50

@interface InnovViewController () <InnovSettingsViewDelegate, InnovPresentNoteDelegate, InnovNoteEditorViewDelegate, UISearchBarDelegate>
{
    __weak IBOutlet UIButton *showTagsButton;
    __weak IBOutlet UIButton *trackingButton;
    
    __weak IBOutlet UIView *contentView;
    __weak IBOutlet UIImageView *toolBarImageView;
    
    UIButton *switchButton;
    UIBarButtonItem *switchViewsBarButton;
    UISearchBar *searchBar;
    UIBarButtonItem *settingsBarButton;
    
    InnovMapViewController  *mapVC;
    InnovListViewController *listVC;
    InnovSettingsView *settingsView;
    InnovSelectedTagsViewController *selectedTagsVC;
    InnovPopOverView *popOver;
    
    Note *noteToAdd;
    NSString *currentSearchTerm;
}

@end

@implementation InnovViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(logInFailed) name:@"LogInFailed" object:nil];
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.wantsFullScreenLayout = YES;
    
    mapVC = [[InnovMapViewController alloc] init];
    mapVC.delegate = self;
    [self addChildViewController:mapVC];
    [contentView addSubview:mapVC.view];
    [mapVC didMoveToParentViewController:self];
    
    listVC = [[InnovListViewController alloc] init];
    listVC.delegate = self;
    [self addChildViewController:listVC];
    
    switchButton = [UIButton buttonWithType:UIButtonTypeCustom];
    switchButton.frame = CGRectMake(0, 0, 30, 30);
    [switchButton addTarget:self action:@selector(switchViews) forControlEvents:UIControlEventTouchUpInside];
    [switchButton setBackgroundImage: [UIImage imageNamed:@"listModeIcon.png"] forState:UIControlStateNormal];
    [switchButton setBackgroundImage: [UIImage imageNamed:@"listModeIcon.png"] forState:UIControlStateHighlighted];
    switchViewsBarButton = [[UIBarButtonItem alloc] initWithCustomView:switchButton];
    self.navigationItem.leftBarButtonItem = switchViewsBarButton;
    
    searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(-5.0, 0.0, self.navigationController.navigationBar.frame.size.width, self.navigationController.navigationBar.frame.size.height)];
    searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    UIView *searchBarView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, self.navigationController.navigationBar.frame.size.width-10, self.navigationController.navigationBar.frame.size.height)];
    searchBarView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    searchBar.delegate = self;
    [searchBar setBackgroundImage:[UIImage new]];
    [searchBarView addSubview:searchBar];
    self.navigationItem.titleView = searchBarView;
    
    UIButton *settingsButton = [UIButton buttonWithType:UIButtonTypeCustom];
    settingsButton.frame = CGRectMake(0, 0, 30, 30);
    [settingsButton addTarget:self action:@selector(settingsPressed) forControlEvents:UIControlEventTouchUpInside];
    [settingsButton setBackgroundImage: [UIImage imageNamed:@"settingsIcon.png"] forState:UIControlStateNormal];
    [settingsButton setBackgroundImage: [UIImage imageNamed:@"settingsIcon.png"] forState:UIControlStateHighlighted];
    settingsBarButton = [[UIBarButtonItem alloc] initWithCustomView:settingsButton];
    self.navigationItem.rightBarButtonItem = settingsBarButton;
    
    settingsView = [[InnovSettingsView alloc] init];
    settingsView.delegate = self;
    CGRect settingsLocation = settingsView.frame;
    settingsLocation.origin.x = self.view.frame.size.width  - settingsView.frame.size.width;
   // settingsLocation.origin.y = [UIApplication sharedApplication].statusBarFrame.size.height + self.navigationController.navigationBar.frame.size.height;
    settingsView.frame = settingsLocation;
    settingsView.alpha = 0.0f;
    
    selectedTagsVC = [[InnovSelectedTagsViewController alloc] init];
    
    [showTagsButton setTintColor:[UIColor orangeColor]];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    //Fixes missing status bar when cancelling picture pick from library
    if([UIApplication sharedApplication].statusBarHidden)
    {
        [self.navigationController setNavigationBarHidden:YES animated:NO];
        [[UIApplication sharedApplication] setStatusBarHidden:NO];
        [self.navigationController setNavigationBarHidden:NO animated:NO];
    }
    
    if([[InnovNoteModel sharedNoteModel].allTags count] == 0)
        [[AppServices sharedAppServices] fetchGameNoteTagsAsynchronously:YES];
    
    CGRect contentVCFrame = contentView.frame;
    contentVCFrame.origin.x = 0;
    contentVCFrame.origin.y = 0;
    mapVC.view.frame = contentVCFrame;
    mapVC.view.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth);
    
    listVC.view.frame = contentVCFrame;
    listVC.view.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth);
    
    CGRect selectedTagsFrame = selectedTagsVC.view.frame;
    selectedTagsFrame.origin.x = 0;
    selectedTagsFrame.origin.y = self.view.frame.size.height;
   // selectedTagsFrame.size.height = self.view.frame.size.height - selectedTagsFrame.origin.y;
    selectedTagsVC.view.frame = selectedTagsFrame;
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if(noteToAdd != nil)
    {
        [self animateInNote:noteToAdd];
        noteToAdd = nil;
    }
}

#pragma mark Display New Note

- (void) prepareToDisplayNote: (Note *) note
{
    noteToAdd = note;
#warning could be different
    [[InnovNoteModel sharedNoteModel] removeSearchTerm:currentSearchTerm];
    currentSearchTerm = @"";
    [selectedTagsVC updateSelectedContent:kMine];
}

- (void) animateInNote: (Note *) note
{
    if ([contentView.subviews containsObject:mapVC.view])
        [mapVC showNotePopUpForNote:note];
    else
        [listVC animateInNote:note];
}

#pragma mark Search Bar Delegate Methods

- (void) searchBarTextDidBeginEditing:(UISearchBar *)aSearchBar
{
    [self searchBar:searchBar activate:YES];
}

- (void) searchBarCancelButtonClicked:(UISearchBar *)aSearchBar
{
    aSearchBar.text = @"";
    [self searchBar: aSearchBar textDidChange:aSearchBar.text];
    [self searchBar:aSearchBar activate:NO];
}

- (void) searchBarSearchButtonClicked:(UISearchBar *)aSearchBar
{
    [self searchBar:searchBar activate:NO];
    [[InnovNoteModel sharedNoteModel] fetchMoreNotes];
}

- (void) searchBar:(UISearchBar *)aSearchBar activate:(BOOL)active
{
   listVC.view.userInteractionEnabled = !active;
    mapVC.view.userInteractionEnabled = !active;
    if (!active)
        [aSearchBar resignFirstResponder];

    [aSearchBar setShowsCancelButton:active animated:YES];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [[InnovNoteModel sharedNoteModel] removeSearchTerm:currentSearchTerm];
    currentSearchTerm = searchText.lowercaseString;
    [[InnovNoteModel sharedNoteModel] addSearchTerm:currentSearchTerm];
}

#pragma mark Buttons Pressed

- (void)settingsPressed
{
    if(![self.view.subviews containsObject:settingsView])
    {
        [self.view addSubview:settingsView];
        [settingsView show];
    }
    else
        [settingsView hide];
}

- (IBAction)showTagsPressed:(id)sender
{
    
    if(![self.view.subviews containsObject:selectedTagsVC.view])
    {
        [showTagsButton setSelected:YES];
        [self addChildViewController:selectedTagsVC];
        [self.view insertSubview:selectedTagsVC.view belowSubview:toolBarImageView];
        [selectedTagsVC didMoveToParentViewController:self];
        [selectedTagsVC show];
    }
    else
    {
        [showTagsButton setSelected:NO];
        [selectedTagsVC hide];
    }
}

- (IBAction)cameraPressed:(id)sender
{
    Reachability *internetReach = [Reachability reachabilityForInternetConnection];
    NetworkStatus internet = [internetReach currentReachabilityStatus];
    if(internet == NotReachable)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No Connection" message:@"You must be connected to the internet to create a note." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
    }
    else
    {
        if([AppModel sharedAppModel].playerId == 0)
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Must Be Logged In" message:@"You must be logged in to create a note." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Log In", nil];
            [alert show];
        }
        else
        {
            InnovNoteEditorViewController *editorVC = [[InnovNoteEditorViewController alloc] init];
            editorVC.delegate = self;
            [self.navigationController pushViewController:editorVC animated:NO];
        }
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex)
        [self presentLogIn];
}

- (IBAction)trackingButtonPressed:(id)sender
{
	[(SifterAppDelegate *)[[UIApplication sharedApplication] delegate] playAudioAlert:@"ticktick" shouldVibrate:NO];
    [mapVC zoomAndCenterMapAnimated: YES];
}

#pragma mark Settings Delegate Methods

- (void) showNotifications
{
    InnovPopOverNotifContentView *notifView = [[InnovPopOverNotifContentView alloc] init];
    [notifView refreshFromModel];
    popOver = [[InnovPopOverView alloc] initWithFrame:self.view.frame andContentView:notifView];
    popOver.alpha = 0.0f;
    [self.view addSubview:popOver];
    
    [UIView animateWithDuration:POP_OVER_ANIMATION_DURATION delay:0.0f options:UIViewAnimationCurveEaseOut animations:^{ popOver.alpha = 1.0f; }
                     completion:^(BOOL finished) { }];
}

- (void) showAbout
{
#warning unimplemented
}

- (void) presentLogIn
{
    LoginViewController *logInVC = [[LoginViewController alloc] init];
    [self.navigationController pushViewController:logInVC animated:YES];
}

#pragma mark Login and Game Selection

- (void)logInFailed
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Log In Failed" message:@"The attempt to log in failed. Please confirm your log in information and try again or create an account if you do not have one." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles: nil];
    [alert show];
}

#pragma mark Present Note Delegate Method

- (void) presentNote:(Note *) note
{
    [self.view endEditing:YES];
    
    InnovNoteViewController *noteVC = [[InnovNoteViewController alloc] init];
    noteVC.note = note;
    noteVC.delegate = self;
    [self.navigationController pushViewController:noteVC animated:YES];
}

#pragma mark TouchesBegan Method

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    
#warning SHOULD WORK and DID BEFORE Xcode 5
   // [self.view endEditing: YES];
    [self searchBarCancelButtonClicked:searchBar];
    [settingsView hide];
    [showTagsButton setSelected:NO];
    [selectedTagsVC hide];
}

#pragma mark Switch Views

- (void)switchViews {
    
    UIViewController *coming = nil;
    UIViewController *going = nil;
    NSString *newButtonImageName;
    UIViewAnimationTransition transition;
    
    if (![contentView.subviews containsObject:mapVC.view])
    {
        coming = mapVC;
        going = listVC;
        transition = UIViewAnimationTransitionFlipFromLeft;
        newButtonImageName = @"listModeIcon.png";
    }
    else
    {
        coming = listVC;
        going = mapVC;
        transition = UIViewAnimationTransitionFlipFromRight;
        newButtonImageName = @"103-mapWhite";
    }
    
    [UIView beginAnimations:@"View Flip" context:nil];
    [UIView setAnimationDuration:SWITCH_VIEWS_ANIMATION_DURATION];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
    [UIView setAnimationTransition: transition forView:contentView cache:YES];
    
    [going willMoveToParentViewController:nil];
    [going.view removeFromSuperview];
    [going removeFromParentViewController];
    
    coming.view.frame = going.view.frame;
    [contentView addSubview:coming.view];
    [coming didMoveToParentViewController:self];
    
    [UIView commitAnimations];
    
    [UIView beginAnimations:@"Button Flip" context:nil];
    [UIView setAnimationDuration:SWITCH_VIEWS_ANIMATION_DURATION];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
    [UIView setAnimationTransition: transition forView:switchViewsBarButton.customView cache:YES];
    [((UIButton *)switchViewsBarButton.customView) setBackgroundImage: [UIImage imageNamed:newButtonImageName] forState:UIControlStateNormal];
    [((UIButton *)switchViewsBarButton.customView) setBackgroundImage: [UIImage imageNamed:newButtonImageName] forState:UIControlStateHighlighted];
    [UIView commitAnimations];
}

#pragma mark Free Memory

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidUnload
{
    contentView = nil;
    showTagsButton = nil;
    trackingButton = nil;
    switchViewsBarButton = nil;
    settingsView = nil;
    toolBarImageView = nil;
    [super viewDidUnload];
}

@end