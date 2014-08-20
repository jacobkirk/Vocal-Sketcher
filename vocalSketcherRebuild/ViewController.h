//
//  ViewController.h
//  Vocal Sketcher
//
//  Created by Jacob Kirk on 27/03/2014.
//  Copyright (c) 2014 Jacob Kirk. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MessageUI/MessageUI.h>
#import <MessageUI/MFMailComposeViewController.h>

@interface ViewController : UIViewController <AVAudioRecorderDelegate, AVAudioPlayerDelegate, MFMailComposeViewControllerDelegate>

@property (weak, nonatomic) IBOutlet UIButton *recordButton;
@property (weak, nonatomic) IBOutlet UIButton *playButton;
@property (weak, nonatomic) IBOutlet UIButton *processButton;
@property (weak, nonatomic) IBOutlet UIButton *exportButton;

- (IBAction)recordPressed:(id)sender;
- (IBAction)playPressed:(id)sender;
- (IBAction)processPressed:(id)sender;
- (IBAction)exportPressed:(id)sender;
- (IBAction)infoPressed:(id)sender;

- (IBAction)recordDepressed:(id)sender;
- (IBAction)playDepressed:(id)sender;
- (IBAction)processDepressed:(id)sender;
- (IBAction)exportDepressed:(id)sender;
- (IBAction)infoDepressed:(id)sender;

@property (weak, nonatomic) IBOutlet UIImageView *mainScreen;
@property (weak, nonatomic) IBOutlet UIImageView *stop;
@property (weak, nonatomic) IBOutlet UIImageView *stopGrey;
@property (weak, nonatomic) IBOutlet UIImageView *recordGrey;
@property (weak, nonatomic) IBOutlet UIImageView *record;
@property (weak, nonatomic) IBOutlet UIImageView *playGrey;
@property (weak, nonatomic) IBOutlet UIImageView *play;
@property (weak, nonatomic) IBOutlet UIImageView *playingGrey;
@property (weak, nonatomic) IBOutlet UIImageView *processGrey;
@property (weak, nonatomic) IBOutlet UIImageView *processingCompletedGrey;
@property (weak, nonatomic) IBOutlet UIImageView *process;
@property (weak, nonatomic) IBOutlet UIImageView *exportingGrey;
@property (weak, nonatomic) IBOutlet UIImageView *exportGrey;
@property (weak, nonatomic) IBOutlet UIImageView *exportCompletedGrey;
@property (weak, nonatomic) IBOutlet UIImageView *export;
@property (weak, nonatomic) IBOutlet UIImageView *info;
@property (weak, nonatomic) IBOutlet UIImageView *infoGrey;



@end
