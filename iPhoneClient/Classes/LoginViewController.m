//
//  LoginViewController.m
//  ARIS
//
//  Created by Ben Longoria on 2/11/09.
//  Copyright 2009 University of Wisconsin. All rights reserved.
//

#import "LoginViewController.h"

#import "AppModel.h"
#import "AppServices.h"
#import "ARISAppDelegate.h"
#import "ForgotViewController.h"
#import "SelfRegistrationViewController.h"

@interface LoginViewController() <SelfRegistrationDelegate>
{
	IBOutlet UITextField *usernameField;
	IBOutlet UITextField *passwordField;
	IBOutlet UIButton *loginButton;
	IBOutlet UIButton *newAccountButton;
    IBOutlet UIButton *changePassButton;
    
	IBOutlet UILabel *newAccountMessageLabel;
}

@end

@implementation LoginViewController

- (id)initWithNibName:(NSString *)nibName bundle:(NSBundle *)nibBundle
{
    self = [super initWithNibName:nibName bundle:nibBundle];
    if (self)
        self.title = @"Log In to YOI"; // NSLocalizedString(@"LoginTitleKey", @"");
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    usernameField.placeholder = NSLocalizedString(@"UsernameKey", @"");
    passwordField.placeholder = NSLocalizedString(@"PasswordKey", @"");
    [loginButton setTitle:NSLocalizedString(@"LoginKey",@"") forState:UIControlStateNormal];
    newAccountMessageLabel.text = NSLocalizedString(@"NewAccountMessageKey", @"");
    [newAccountButton setTitle:NSLocalizedString(@"CreateAccountKey",@"") forState:UIControlStateNormal];
}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [usernameField resignFirstResponder];
    [passwordField resignFirstResponder];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == usernameField)
        [passwordField becomeFirstResponder];
    if(textField == passwordField)
        [self loginButtonTouched:self];
    return YES;
}

//Makes keyboard disappear on touch outside of keyboard or textfield
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [usernameField resignFirstResponder];
    [passwordField resignFirstResponder];
}

-(IBAction)loginButtonTouched:(id)sender
{
    [self attemptLoginWithUserName:usernameField.text andPassword:passwordField.text andGameId:0 inMuseumMode:false];

    [usernameField resignFirstResponder];
    [passwordField resignFirstResponder];
    
    [self.navigationController popViewControllerAnimated:YES];
}

-(IBAction)changePassTouch:(id)sender
{
    ForgotViewController *forgotPassViewController = [[ForgotViewController alloc] initWithNibName:@"ForgotViewController" bundle:[NSBundle mainBundle]];
    [[self navigationController] pushViewController:forgotPassViewController animated:NO];
}

-(IBAction)newAccountButtonTouched:(id)sender
{
    SelfRegistrationViewController *selfRegistrationViewController = [[SelfRegistrationViewController alloc] initWithNibName:@"SelfRegistration" bundle:[NSBundle mainBundle]];
    selfRegistrationViewController.delegate = self;
    [[self navigationController] pushViewController:selfRegistrationViewController animated:NO];
}

- (void)attemptLoginWithUserName:(NSString *)userName andPassword:(NSString *)password andGameId:(int)gameId inMuseumMode:(BOOL)museumMode
{
	[AppModel sharedAppModel].userName = userName;
	[AppModel sharedAppModel].password = password;
	[AppModel sharedAppModel].museumMode = museumMode;
    
	[[AppServices sharedAppServices] login];
    
    if(gameId != 0)
    {
        [AppModel sharedAppModel].skipGameDetails = YES;
        [[AppServices sharedAppServices] fetchOneGameGameList:gameId];
    }
}

@end
