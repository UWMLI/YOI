//
//  InnovCommentViewController.m
//  YOI
//
//  Created by Jacob Hanshaw on 7/1/13.
//
//

#import "InnovCommentViewController.h"
#import <QuartzCore/QuartzCore.h>

#import "Note.h"
#import "Tag.h"
#import "Comment.h"
#import "AppModel.h"
#import "AppServices.h"
#import "InnovNoteModel.h"
#import "InnovCommentCell.h"
#import "DAKeyboardControl.h"
#import "LoginViewController.h"

#define DEFAULT_TEXT                @"Add a comment..."
#define DEFAULT_FONT                [UIFont fontWithName:@"Helvetica" size:14]
#define DEFAULT_TEXTVIEW_MARGIN     8
#define ADJUSTED_TEXTVIEW_MARGIN    0

#define COMMENT_BAR_HEIGHT          46
#define COMMENT_BAR_HEIGHT_MAX      80
#define COMMENT_BAR_X_MARGIN        10
#define COMMENT_BAR_Y_MARGIN        6
#define COMMENT_BAR_BUTTON_WIDTH    58

#define DEFAULT_MAX_VISIBLE_COMMENTS 5
#define EXPAND_INDEX                 ((int)DEFAULT_MAX_VISIBLE_COMMENTS/2)
#define EXPAND_TEXT                  @". . ."

#define MAX_COMMENT_LENGTH           255

static NSString * const EXPAND_CELL_ID  = @"ExpandCell";
static NSString * const COMMENT_CELL_ID = @"CommentCell";

@interface InnovCommentViewController () <UITextViewDelegate, UITableViewDataSource, UITableViewDelegate, InnovCommentCellDelegate>
{
    __weak IBOutlet UITableView *commentTableView;
    
    UIToolbar       *addCommentBar;
    UITextView      *addCommentTextView;
    UIBarButtonItem *addCommentButton;
    
    BOOL expanded;
}

@end

@implementation InnovCommentViewController

@synthesize note;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        self.title = @"Comments";
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshViewFromModel) name:@"NoteModelUpdate:Notes" object:nil];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    addCommentBar = [[UIToolbar alloc] initWithFrame:CGRectMake(0.0f,
                                                                self.view.bounds.size.height - COMMENT_BAR_HEIGHT,
                                                                self.view.bounds.size.width,
                                                                COMMENT_BAR_HEIGHT)];
    addCommentBar.barStyle = UIBarStyleBlackOpaque;
    addCommentBar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:addCommentBar];
    
    addCommentTextView =      [[UITextView alloc] initWithFrame:CGRectMake(COMMENT_BAR_X_MARGIN,
                                                                           COMMENT_BAR_Y_MARGIN,
                                                                           addCommentBar.bounds.size.width - (2 * COMMENT_BAR_X_MARGIN)  - (COMMENT_BAR_BUTTON_WIDTH + COMMENT_BAR_X_MARGIN),
                                                                           COMMENT_BAR_HEIGHT-COMMENT_BAR_Y_MARGIN*2)];
    addCommentTextView.delegate            = self;
    addCommentTextView.layer.masksToBounds = YES;
    addCommentTextView.layer.cornerRadius  = 9.0f;
    addCommentTextView.font                = DEFAULT_FONT;
    addCommentTextView.contentInset        = UIEdgeInsetsMake(-8,-4,-8,-4);
    addCommentTextView.autoresizingMask    = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [addCommentBar addSubview:addCommentTextView];
    
    addCommentButton = [[UIBarButtonItem alloc] initWithTitle:@"Send" style:UIBarButtonItemStyleDone target:self action:@selector(addCommentButtonPressed:)];
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
    [addCommentBar setItems:[NSArray arrayWithObjects:flex, addCommentButton, nil]];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear: animated];
    
    addCommentTextView.text      = DEFAULT_TEXT;
    addCommentTextView.textColor = [UIColor lightGrayColor];
    [self adjustCommentBarToFitText];
    
    if([self.note.tags count] > 0)
        self.title = ((Tag *)[self.note.tags objectAtIndex:0]).tagName;
    else
        self.title = @"Note";
    
    self.view.keyboardTriggerOffset = addCommentBar.bounds.size.height;
    
    [self.view addKeyboardPanningWithActionHandler:^(CGRect keyboardFrameInView) {
        /*
         Try not to call "self" inside this block (retain cycle).
         But if you do, make sure to remove DAKeyboardControl
         when you are done with the view controller by calling:
         [self.view removeKeyboardControl];
         */
#warning check if necessary now that is loaded and released with view visibile
        if (self.isViewLoaded && self.view.window)
        {
            CGRect addCommentBarFrame = addCommentBar.frame;
            addCommentBarFrame.origin.y = keyboardFrameInView.origin.y - addCommentBarFrame.size.height;
            addCommentBar.frame = addCommentBarFrame;
            
            CGRect tableViewFrame = commentTableView.frame;
            tableViewFrame.size.height = addCommentBarFrame.origin.y;
            commentTableView.frame = tableViewFrame;
            if([commentTableView numberOfRowsInSection:0] > 0)
                [commentTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:([commentTableView numberOfRowsInSection:0] - 1) inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
        }
    }];
    
    if([commentTableView numberOfRowsInSection:0] > 0)
        [commentTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:([commentTableView numberOfRowsInSection:0] - 1) inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self.view removeKeyboardControl];
}



#pragma mark Refresh

- (void)refreshViewFromModel
{
    [commentTableView reloadData];
}

#pragma mark UITextView methods

- (void) textViewDidBeginEditing:(UITextView *)textView
{
    textView.textColor = [UIColor blackColor];
    if([textView.text isEqualToString:DEFAULT_TEXT]) textView.text = @"";
}

- (BOOL )textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{    
    if([[textView text] length] - range.length + text.length > MAX_COMMENT_LENGTH)
        return NO;
    
    return YES;
}

- (void) textViewDidChange:(UITextView *)textView
{
    [self adjustCommentBarToFitText];
    if([commentTableView numberOfRowsInSection:0] > 0)
        [commentTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:([commentTableView numberOfRowsInSection:0] - 1) inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:NO];
}

- (void) adjustCommentBarToFitText
{
    CGSize size = CGSizeMake(addCommentTextView.frame.size.width - (2 * ADJUSTED_TEXTVIEW_MARGIN), COMMENT_BAR_HEIGHT_MAX - (2 * COMMENT_BAR_Y_MARGIN));
    CGFloat newHeight = ([addCommentTextView.text sizeWithFont:addCommentTextView.font constrainedToSize:size].height + (2 * ADJUSTED_TEXTVIEW_MARGIN)) + (2 * COMMENT_BAR_Y_MARGIN);
    CGFloat oldHeight = addCommentBar.frame.size.height;
    
    CGRect frame = addCommentBar.frame;
    frame.size.height = MAX(newHeight, COMMENT_BAR_HEIGHT);
    frame.origin.y   += oldHeight-frame.size.height;
    
    addCommentBar.frame = frame;
    
    CGRect tableViewFrame = commentTableView.frame;
    tableViewFrame.size.height = addCommentBar.frame.origin.y;
    commentTableView.frame = tableViewFrame;
    
    self.view.keyboardTriggerOffset = addCommentBar.bounds.size.height;
}

- (void) addCommentButtonPressed:(id)sender
{
    [self.view endEditing:YES];
    
    if([AppModel sharedAppModel].playerId == 0)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Must Be Logged In" message:@"You must be logged in to comment on notes." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Log In", nil];
        [alert show];
    }
    else if([addCommentTextView.text length] > 0 && ![addCommentTextView.text isEqualToString:DEFAULT_TEXT])
    {
        Note *commentNote = [[Note alloc] init];
        commentNote.noteId = [[AppServices sharedAppServices] addCommentToNoteWithId:self.note.noteId andTitle:@""];
        
        commentNote.title = addCommentTextView.text;
        commentNote.parentNoteId = self.note.noteId;
        commentNote.creatorId = [AppModel sharedAppModel].playerId;
        commentNote.username = [AppModel sharedAppModel].userName;
        commentNote.displayname = [AppModel sharedAppModel].displayName;
#warning probably unnecessary to do this second call
        [[AppServices sharedAppServices]updateCommentWithId:commentNote.noteId andTitle:commentNote.title andRefresh:YES];
        
        [self.note.comments insertObject:commentNote atIndex:0];
        [[InnovNoteModel sharedNoteModel] updateNote:note];
    }
    
    addCommentTextView.text = DEFAULT_TEXT;
    addCommentTextView.textColor = [UIColor lightGrayColor];
    
    [self adjustCommentBarToFitText];
    
    [commentTableView reloadData];
    if([commentTableView numberOfRowsInSection:0] > 0)
        [commentTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:([commentTableView numberOfRowsInSection:0] - 1) inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if([alertView.title isEqualToString:@"Must Be Logged In"] && buttonIndex != 0)
        [self presentLogIn];
}

#pragma mark Table view methods

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if([note.comments count] > DEFAULT_MAX_VISIBLE_COMMENTS && !expanded)
        return DEFAULT_MAX_VISIBLE_COMMENTS;
    else
        return [note.comments count];
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(!expanded && indexPath.row == EXPAND_INDEX && [note.comments count] > DEFAULT_MAX_VISIBLE_COMMENTS)
        return  44;
    
    CGSize size = CGSizeMake(self.view.frame.size.width - (2 * DEFAULT_TEXTVIEW_MARGIN), CGFLOAT_MAX);
    NSString *text      = ((Note *)[note.comments objectAtIndex:[self getCommentIndexForRow:indexPath.row]]).title;
    
    return [text sizeWithFont:DEFAULT_FONT constrainedToSize:size].height + (2 * DEFAULT_TEXTVIEW_MARGIN)+AUTHOR_ROW_HEIGHT;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(!expanded && indexPath.row == EXPAND_INDEX && [note.comments count] > DEFAULT_MAX_VISIBLE_COMMENTS)
    {
        UITableViewCell *expandCell = [tableView dequeueReusableCellWithIdentifier:EXPAND_CELL_ID];
        if(!expandCell)
            expandCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:EXPAND_CELL_ID];
        expandCell.textLabel.text = EXPAND_TEXT;
        expandCell.textLabel.textAlignment = UITextAlignmentCenter;
        return expandCell;
    }
    else
    {
        InnovCommentCell *cell = [tableView dequeueReusableCellWithIdentifier:COMMENT_CELL_ID];
        if(!cell)
        {
            cell = [[InnovCommentCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:COMMENT_CELL_ID andDelegate:self];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        
        [cell updateWithNote:[self.note.comments objectAtIndex:[self getCommentIndexForRow:indexPath.row]] andIndex:indexPath.row];
        
        return cell;
    }
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [addCommentTextView resignFirstResponder];
    
    if(![addCommentTextView.text length])
    {
        addCommentTextView.text = DEFAULT_TEXT;
        addCommentTextView.textColor = [UIColor lightGrayColor];
        [self adjustCommentBarToFitText];
    }
    
    if(!expanded && indexPath.row == EXPAND_INDEX && [note.comments count] > DEFAULT_MAX_VISIBLE_COMMENTS)
    {
        expanded = YES;
        [tableView reloadData];
    }
}

-(int)getCommentIndexForRow:(int) row
{
    if(expanded || row < EXPAND_INDEX || [note.comments count] <= DEFAULT_MAX_VISIBLE_COMMENTS)
        return [note.comments count]-row-1;
    else
        return DEFAULT_MAX_VISIBLE_COMMENTS-row-1;
}

#pragma mark InnovCommentCell Delegate Methods

- (void)presentLogIn
{
    LoginViewController *logInVC = [[LoginViewController alloc] init];
    [self.navigationController pushViewController:logInVC animated:YES];
}

- (void)deleteButtonPressed:(UIButton *)sender
{
    self.note = [[InnovNoteModel sharedNoteModel] noteForNoteId:self.note.noteId];
    int deletedNoteId = ((Note *)[self.note.comments objectAtIndex:sender.tag]).noteId;
    [self.note.comments removeObjectAtIndex:sender.tag];
    [commentTableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:sender.tag inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
    [[InnovNoteModel sharedNoteModel] updateNote:self.note];
    [[AppServices sharedAppServices] deleteNoteWithNoteId:deletedNoteId];
}

#pragma mark Remove Memory

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload
{
    commentTableView = nil;
    [super viewDidUnload];
}

@end