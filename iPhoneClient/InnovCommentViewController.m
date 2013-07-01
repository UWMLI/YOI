//
//  InnovCommentViewController.m
//  YOI
//
//  Created by Jacob Hanshaw on 7/1/13.
//
//

#import "InnovCommentViewController.h"

@interface InnovCommentViewController () <UITableViewDataSource, UITableViewDelegate>
{
    __weak IBOutlet UITableView *commentTableView;
}

@end

@implementation InnovCommentViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidUnload {
    commentTableView = nil;
    [super viewDidUnload];
}
@end
