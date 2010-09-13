//
//  ARISAppDelegate.m
//  ARIS
//
//  Created by Ben Longoria on 2/11/09.
//  Copyright University of Wisconsin 2009. All rights reserved.
//

#import "ARISAppDelegate.h"
#import "Node.h"

@implementation ARISAppDelegate

@synthesize appModel;
@synthesize window;
@synthesize tabBarController;
@synthesize loginViewController;
@synthesize loginViewNavigationController;
@synthesize gamePickerViewController;
@synthesize gamePickerNavigationController;
@synthesize nearbyBar;
@synthesize nearbyObjectNavigationController;
@synthesize myCLController;
@synthesize waitingIndicator,waitingIndicatorView;
@synthesize networkAlert;

//@synthesize toolbarViewController;

- (void)applicationDidFinishLaunching:(UIApplication *)application {
	
	//Don't sleep
	application.idleTimerDisabled = YES;
	
	//init app model
	appModel = [[AppModel alloc] init];
	
	//Init keys in UserDefaults in case the user has not visited the ARIS Settings page
	//To set these defaults, edit Settings.bundle->Root.plist 
	[appModel initUserDefaults];
	
	//Load defaults from UserDefaults
	[appModel loadUserDefaults];
	[appModel retain];
	
	//Log the current Language
	NSArray *languages = [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleLanguages"];
	NSString *currentLanguage = [languages objectAtIndex:0];
	NSLog(@"Current Locale: %@", [[NSLocale currentLocale] localeIdentifier]);
	NSLog(@"Current language: %@", currentLanguage);
	[languages release];
	[currentLanguage release];
	
	
	
	//Check for Internet conductivity
	NSLog(@"AppDelegate: Verifying Connection to: %@",appModel.baseAppURL);
	Reachability *r = [Reachability reachabilityWithHostName:@"arisgames.org"];
	NetworkStatus internetStatus = [r currentReachabilityStatus];
	BOOL connection = (internetStatus == ReachableViaWiFi) || (internetStatus == ReachableViaWWAN);
	//connection = NO; //For debugging locally
	if (!connection) {
		NSLog(@"AppDelegate: Internet Connection Failed");
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"NoConnectionTitleKey", @"") message: NSLocalizedString(@"NoConnectionMessageKey",@"") delegate: self cancelButtonTitle: nil otherButtonTitles: nil];
		[alert show];
		[alert release];
		return;
	} else {
		NSLog(@"AppDelegate: Internet Connection Functional");
	}
	
	
	//register for notifications from views
	NSNotificationCenter *dispatcher = [NSNotificationCenter defaultCenter];
	[dispatcher addObserver:self selector:@selector(finishLoginAttempt:) name:@"NewLoginResponseReady" object:nil];
	[dispatcher addObserver:self selector:@selector(selectGame:) name:@"SelectGame" object:nil];
	[dispatcher addObserver:self selector:@selector(performLogout:) name:@"LogoutRequested" object:nil];
	[dispatcher addObserver:self selector:@selector(displayNearbyObjects:) name:@"NearbyButtonTouched" object:nil];

	//Setup ARView
	//ARViewViewControler *arViewController = [[[ARViewViewControler alloc] initWithNibName:@"ARView" bundle:nil] autorelease];
	//UINavigationController *arNavigationController = [[UINavigationController alloc] initWithRootViewController: arViewController];
	//arNavigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
	
	//Setup Tasks View
	QuestsViewController *questsViewController = [[[QuestsViewController alloc] initWithNibName:@"Quests" bundle:nil] autorelease];
	UINavigationController *questsNavigationController = [[UINavigationController alloc] initWithRootViewController: questsViewController];
	questsNavigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
	
	//Setup GPS View
	GPSViewController *gpsViewController = [[[GPSViewController alloc] initWithNibName:@"GPS" bundle:nil] autorelease];
	UINavigationController *gpsNavigationController = [[UINavigationController alloc] initWithRootViewController: gpsViewController];
	gpsNavigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;

	//Setup Inventory View
	InventoryListViewController *inventoryListViewController = [[[InventoryListViewController alloc] initWithNibName:@"InventoryList" bundle:nil] autorelease];
	UINavigationController *inventoryNavigationController = [[UINavigationController alloc] initWithRootViewController: inventoryListViewController];
	inventoryNavigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
	
	//Setup Camera View
	CameraViewController *cameraViewController = [[[CameraViewController alloc] initWithNibName:@"Camera" bundle:nil] autorelease];
	UINavigationController *cameraNavigationController = [[UINavigationController alloc] initWithRootViewController: cameraViewController];
	cameraNavigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;

	//Setup Audio Recorder View
	AudioRecorderViewController *audioRecorderViewController = [[[AudioRecorderViewController alloc] initWithNibName:@"AudioRecorderViewController" bundle:nil] autorelease];
	UINavigationController *audioRecorderNavigationController = [[UINavigationController alloc] initWithRootViewController: audioRecorderViewController];
	audioRecorderNavigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;	
	
	//QR Scanner Developer View
	QRScannerViewController *qrScannerViewController = [[[QRScannerViewController alloc] initWithNibName:@"QRScanner" bundle:nil] autorelease];
	UINavigationController *qrScannerNavigationController = [[UINavigationController alloc] initWithRootViewController: qrScannerViewController];
	qrScannerNavigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
	
	//Logout View
	LogoutViewController *logoutViewController = [[[LogoutViewController alloc] initWithNibName:@"Logout" bundle:nil] autorelease];
	UINavigationController *logoutNavigationController = [[UINavigationController alloc] initWithRootViewController: logoutViewController];
	logoutNavigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;

	//Start Over View
	StartOverViewController *startOverViewController = [[[StartOverViewController alloc] initWithNibName:@"StartOverViewController" bundle:nil] autorelease];
	UINavigationController *startOverNavigationController = [[UINavigationController alloc] initWithRootViewController: startOverViewController];
	startOverNavigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;	
	
	//Developer View
	DeveloperViewController *developerViewController = [[[DeveloperViewController alloc] initWithNibName:@"Developer" bundle:nil] autorelease];
	UINavigationController *developerNavigationController = [[UINavigationController alloc] initWithRootViewController: developerViewController];
	developerNavigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
	
	
	//Game Picker View
	gamePickerViewController = [[[GamePickerViewController alloc] initWithNibName:@"GamePicker" bundle:nil] autorelease];
	gamePickerViewController.view.frame = [UIScreen mainScreen].applicationFrame;
	gamePickerNavigationController = [[UINavigationController alloc] initWithRootViewController: gamePickerViewController];
	gamePickerNavigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
	[loginViewController retain]; //This view may be removed and readded to the window

	//Login View
	loginViewController = [[[LoginViewController alloc] initWithNibName:@"Login" bundle:nil] autorelease];
	loginViewController.view.frame = [UIScreen mainScreen].applicationFrame;
	loginViewNavigationController = [[UINavigationController alloc] initWithRootViewController: loginViewController];
	loginViewNavigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
	[loginViewController retain]; //This view may be removed and readded to the window
	
	//Add the view controllers to the Tab Bar
	tabBarController.viewControllers = [NSMutableArray arrayWithObjects: 
										questsNavigationController, 
										gpsNavigationController,
										inventoryNavigationController,
										qrScannerNavigationController,
										//arNavigationController,
										cameraNavigationController,
										audioRecorderNavigationController,
										gamePickerNavigationController,
										logoutNavigationController,
										startOverNavigationController,
										//developerNavigationController,
										nil];	

	[window addSubview:tabBarController.view];

	//Customize the 'more' nav controller on the tab bar
	UINavigationController *moreNavController = tabBarController.moreNavigationController;
	moreNavController.navigationBar.barStyle = UIBarStyleBlackOpaque;
	moreNavController.delegate = self;
	
	//Setup Location Manager
	myCLController = [[MyCLController alloc] initWithAppModel:appModel];
	[myCLController.locationManager startUpdatingLocation];
		
	//Display the login screen if this user is not logged in
	if (appModel.loggedIn == YES) {
		if (!appModel.gameId || appModel.gameId == 0 ) {
			NSLog(@"Appdelegate: Player already logged in, but a site has not been selected. Display site picker");
			tabBarController.view.hidden = YES;
			[window addSubview:gamePickerNavigationController.view];
		}
		else {
			NSLog(@"Appdelegate: Player already logged in and they have a site selected. Go into the default module");
			[appModel fetchAllGameLists];
			[appModel fetchLocationList];
			
			[self playAudioAlert:@"questChange" shouldVibrate:NO];
		}
	}
	else {
		NSLog(@"Appdelegate: Player not logged in, display login");
		tabBarController.view.hidden = YES;
		[window addSubview:loginViewNavigationController.view];
	}
	
	//Inventory Bar, which is really a view
	nearbyBar = [[NearbyBar alloc] initWithFrame:CGRectMake(0.0, 63.0, 320.0, 20.0)];
	[window addSubview:nearbyBar];	
	
}


- (void) showNetworkAlert{
	NSLog (@"AppDelegate: Showing Network Alert");
	
	if (!self.networkAlert) {
		networkAlert = [[UIAlertView alloc] initWithTitle: NSLocalizedString(@"PoorConnectionTitleKey", @"") 
											message: NSLocalizedString(@"PoorConnectionMessageKey", @"")
												 delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
	}
	
	if (self.networkAlert.visible == NO) [networkAlert show];
		
}

- (void) removeNetworkAlert {
	NSLog (@"AppDelegate: Removing Network Alert");
	
	if (self.networkAlert != nil) {
		[self.networkAlert dismissWithClickedButtonIndex:0 animated:YES];
	}
	

}



- (void) showNewWaitingIndicator:(NSString *)message displayProgressBar:(BOOL)displayProgressBar {
	NSLog (@"AppDelegate: Showing Waiting Indicator");
	if (!self.waitingIndicatorView) {
		self.waitingIndicatorView = [[WaitingIndicatorView alloc] initWithWaitingMessage:message showProgressBar:NO];
	}

	[self.waitingIndicatorView show];
	
}

- (void) removeNewWaitingIndicator {
	NSLog (@"AppDelegate: Removing Waiting Indicator");
	if (self.waitingIndicatorView != nil) [self.waitingIndicatorView dismiss];
}


- (void) showWaitingIndicator:(NSString *)message displayProgressBar:(BOOL)displayProgressBar {
	NSLog (@"AppDelegate: Showing Waiting Indicator");
	if (!self.waitingIndicator) {
		self.waitingIndicator = [[WaitingIndicatorViewController alloc] initWithNibName:@"WaitingIndicator" bundle:nil];
	}
	self.waitingIndicator.message = message;
	self.waitingIndicator.progressView.hidden = !displayProgressBar;
	
	//by adding a subview to window, we make sure it is put on top
	if (appModel.loggedIn == YES) [self.window addSubview:self.waitingIndicator.view]; 

}

- (void) removeWaitingIndicator {
	NSLog (@"AppDelegate: Removing Waiting Indicator");
	if (self.waitingIndicator != nil) [self.waitingIndicator.view removeFromSuperview ];
}


- (void) playAudioAlert:(NSString*)wavFileName shouldVibrate:(BOOL)shouldVibrate{
	NSLog(@"AppDelegate: Playing an audio Alert sound");
	
	//Vibrate
	if (shouldVibrate == YES) [NSThread detachNewThreadSelector:@selector(vibrate) toTarget:self withObject:nil];	
	//Play the sound on a background thread
	[NSThread detachNewThreadSelector:@selector(playAudio:) toTarget:self withObject:wavFileName];
}

//Play a sound
- (void) playAudio:(NSString*)wavFileName {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];  

	
	SystemSoundID alert;  
	NSURL* url = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:wavFileName ofType:@"wav"]];
	AudioServicesCreateSystemSoundID((CFURLRef)url, &alert);  
	AudioServicesPlaySystemSound (alert);
				  
	[pool release];
}

//Vibrate
- (void) vibrate {
	AudioServicesPlaySystemSound (kSystemSoundID_Vibrate);  
}



- (void)newError: (NSString *)text {
	NSLog(@"%@", text);
}

- (void)displayNearbyObjectView:(UIViewController *)nearbyObjectViewController {
	//Hide the nearby bar
	nearbyBar.hidden = YES;
	
	nearbyObjectNavigationController = [[UINavigationController alloc] initWithRootViewController:nearbyObjectViewController];
	nearbyObjectNavigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
		
	//Display
	[self.tabBarController presentModalViewController:nearbyObjectNavigationController animated:YES];
	[nearbyObjectNavigationController release];
}




- (void)attemptLoginWithUserName:(NSString *)userName andPassword:(NSString *)password {	
	NSLog(@"AppDelegate: Attempt Login for: %@ Password: %@", userName, password);
	appModel.username = userName;
	appModel.password = password;

	[self showNewWaitingIndicator:@"Logging In..." displayProgressBar:NO];
	[appModel login];
}

- (void)finishLoginAttempt:(NSNotification *)notification {
	NSLog(@"AppDelegate: Finishing Login Attempt");
	
	[self removeNewWaitingIndicator];
	
	//handle login response
	if(appModel.loggedIn) {
		NSLog(@"AppDelegate: Login Success");
		[loginViewNavigationController.view removeFromSuperview];
		[appModel saveUserDefaults];
		[window addSubview:gamePickerNavigationController.view]; //This will automatically load it's own data
		gamePickerViewController.view.frame = [UIScreen mainScreen].applicationFrame;
		
	} else {
		NSLog(@"AppDelegate: Login Failed, check for a network issue");
		if (self.networkAlert) NSLog(@"AppDelegate: Network is down, skip login alert");
		else {
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"LoginErrorTitleKey",@"")
															message:NSLocalizedString(@"LoginErrorMessageKey",@"")
														   delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
			[alert show];	
			[alert release];
		}
	}
	
}

- (void)selectGame:(NSNotification *)notification {
    //NSDictionary *loginObject = [notification object];
	NSDictionary *userInfo = notification.userInfo;
	Game *selectedGame = [userInfo objectForKey:@"game"];

	NSLog(@"AppDelegate: Game Selected. '%@' game was selected using '%@' as it's site", selectedGame.name, selectedGame.site);

	[gamePickerNavigationController.view removeFromSuperview];
	
	//Set the model to this game
	appModel.site = selectedGame.site;
	appModel.gameId = selectedGame.gameId;
	appModel.gamePcMediaId = selectedGame.pcMediaId;
	[appModel saveUserDefaults];
	
	//Clear out the old game data
	[appModel resetAllPlayerLists];

	
	
	//Notify the Server
	NSLog(@"AppDelegate: Game Selected. Notifying Server");
	[appModel updateServerGameSelected];
	
	//Set tabBar to the first item
	tabBarController.selectedIndex = 0;
	
	//Display the tabBar (and it's content)
	tabBarController.view.hidden = NO;
	
	UINavigationController *navigationController;
	UIViewController *visibleViewController;
	
	//Get the naviation controller and visible view controller
	if ([tabBarController.selectedViewController isKindOfClass:[UINavigationController class]]) {
		navigationController = (UINavigationController*)tabBarController.selectedViewController;
		visibleViewController = [navigationController visibleViewController];
	}
	else {
		navigationController = nil;
		visibleViewController = tabBarController.selectedViewController;
	}
	
	NSLog(@"AppDelegate: %@ selected",[visibleViewController title]);
	
	[appModel fetchAllGameLists];
	[appModel fetchLocationList];

	
	[self playAudioAlert:@"questChange" shouldVibrate:NO];
	
	//Use setModel to refresh the content
	if([visibleViewController respondsToSelector:@selector(refresh)]) {
		[visibleViewController performSelector:@selector(refresh) withObject:nil];
	}
}


- (void)performLogout:(NSNotification *)notification {
    NSLog(@"Performing Logout: Clearing NSUserDefaults and Displaying Login Screen");
	
	//Clear any user realated info in appModel (except server)
	[appModel clearUserDefaults];
	[appModel loadUserDefaults];
	[appModel resetAllPlayerLists];
	
	//(re)load the login view
	tabBarController.view.hidden = YES;
	[window addSubview:loginViewNavigationController.view];
}

- (void) returnToHomeView{
	NSLog(@"AppDelegate: Returning to Home View - Tab Bar Index 0");
	[tabBarController setSelectedIndex:0];	
}


#pragma mark Memory Management

-(void) applicationWillTerminate:(UIApplication *)application {
	NSLog(@"Begin Application Termination");
	
	[appModel saveUserDefaults];
}

- (void)dealloc {
	[appModel release];
	[super dealloc];
}
@end

