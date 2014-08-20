//
//  ViewController.m
//  Vocal Sketcher
//
//  Created by Jacob Kirk on 03/02/2014.
//  Copyright (c) 2014 Jacob Kirk. All rights reserved.
//

#import "ViewController.h"
#import <Accelerate/Accelerate.h>

@interface ViewController (){
    
    AVAudioRecorder *recorder;
    AVAudioPlayer *player;
}

@end

@implementation ViewController

@synthesize recordButton, playButton, processButton, exportButton;

enum
{
    frameSize   = 2048,
    overlap     = 4,
    stride      = 1,
    log2Samples = 12,
    range       = 8192,
    step        = frameSize/overlap,
    minimum     = 2000,
    PPQ         = 128,
    BPM         = 120
};

static COMPLEX_SPLIT    A;
static FFTSetup         setupReal;

static float            overlapBufferA[range];
static float            overlapBufferB[range];
static float            phase1[range];
static float            phase2[range];
static float            dPhase[range];
static float            frequencies[range];
static float            magnitude[range];

static float            deltaPhase;
static float            trueFrequency;

static float            freqPerBin = 44100.0/2048.0;
static float            expect     = 2.0 * M_PI * (float)step / (float)frameSize;

static float            fftCount;
static float            noteLength;

static float            totalFFT;

static float            pulsesPerSec = BPM * PPQ/60;

static int              firstPress;

NSString *pitch;
NSString *lastPitch;
NSString *stopPitch;

NSString *currentHexPitch;

NSString *midiBlock;
NSString *midiDeltaTime;
NSString *midiPitch;
NSString *midiComplete;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [playButton setEnabled:NO];
    [processButton setEnabled:NO];
    [exportButton setEnabled:NO];
    _record.hidden = NO;
    _playGrey.hidden = NO;
    _processGrey.hidden = NO;
    _exportGrey.hidden = NO;
    _info.hidden = NO;
    
    // Setting up audio file path
    NSArray *audioPath = [NSArray arrayWithObjects:
                          [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask,YES) lastObject], @"recordedAudio.m4a",nil];
    
    NSURL *outputFileURL = [NSURL fileURLWithPathComponents:audioPath];
    
    // Setting up audio session
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    
    // Setting recorder values
    NSMutableDictionary *recordingSettings = [[NSMutableDictionary alloc] init];
    
    [recordingSettings setValue:[NSNumber numberWithInt:kAudioFormatMPEG4AAC] forKey:AVFormatIDKey];
    [recordingSettings setValue:[NSNumber numberWithFloat:44100.0] forKey:AVSampleRateKey];
    [recordingSettings setValue:[NSNumber numberWithInt: 1] forKey:AVNumberOfChannelsKey];
    
    // Initiate and prepare the recorder
    recorder = [[AVAudioRecorder alloc] initWithURL:outputFileURL settings:recordingSettings error:nil];
    recorder.delegate = self;
    recorder.meteringEnabled = YES;
    [recorder prepareToRecord];
    
    [self fftSetup];
    
}

- (void)fftSetup
{
    // Allocating memory for complex vectors
    A.realp = (float *) malloc(frameSize * sizeof(float));
    A.imagp = (float *) malloc(frameSize * sizeof(float));
    
    // Allocating FFT data structure
    setupReal = vDSP_create_fftsetup(log2Samples, FFT_RADIX2);
    
    // Allocating memory for phase and overlap buffer
    memset(phase2, 0, range * sizeof(float));
    
}

void convertToVariableLengthQuantity(uint64_t x, uint8_t *out)
{
    // Adapted from http://rosettacode.org/wiki/Variable-length_quantity#C
    // Converting hex delta time to variable length quantities
	int i, j;
	for (i = 9; i > 0; i--)
    {
		if (x & (0x7FULL << i * 7))
        {
            break;
        }
	}
	for (j = 0; j <= i; j++)
    {
		out[j] = ((x >> ((i - j) * 7)) & 0x7F) | 0x80;
    }
    
	out[i] ^= 0x80;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)recordPressed:(id)sender {
    
    _processingCompletedGrey.hidden = YES;
    _process.hidden = NO;
    _processGrey.hidden = YES;
    _stopGrey.hidden = YES;
    _playingGrey.hidden = YES;
    
    // Stopping audio player before recording
    if (player.playing)
    {
        [player stop];
    }
    
    if (!recorder.recording)
    {
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setActive:YES error:nil];
        
        // Start recording
        [recorder record];
        [processButton setEnabled:NO];
        [exportButton setEnabled:NO];
        
        _stop.hidden = NO;
        _record.hidden = YES;
        _recordGrey.hidden = YES;
        _exportGrey.hidden = NO;
        _exportingGrey.hidden = YES;
        _exportCompletedGrey.hidden = YES;
        _export.hidden = YES;
        _processGrey.hidden = NO;
        _process.hidden = YES;
        _processingCompletedGrey.hidden = YES;
        
        NSLog(@"\n\n*********************");
        NSLog(@"Recording audio");
    }
    
    else
    {
        _record.hidden = NO;
        
        // Stop recording
        [recorder stop];
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        [audioSession setActive:NO error:nil];
        
        NSLog(@"Recording stopped");
    }
    
    [playButton setEnabled:NO];
    _playGrey.hidden = NO;
    _play.hidden = YES;
}

- (IBAction)playPressed:(id)sender {
    
    _playGrey.hidden = YES;
    _playingGrey.hidden = NO;
    [playButton setEnabled:NO];
    
    if (!recorder.recording)
    {
        player = [[AVAudioPlayer alloc] initWithContentsOfURL:recorder.url error:nil];
        [player setDelegate:self];
        [player play];
    }
    
    NSLog(@"Playing audio");
    
}

- (IBAction)recordDepressed:(id)sender {
    
    if (recorder.recording)
    {
        _stop.hidden = YES;
        _stopGrey.hidden = NO;
    }
    else
    {
        _record.hidden = YES;
        _recordGrey.hidden = NO;
    }
}

- (IBAction)playDepressed:(id)sender {
    
    _play.hidden = YES;
    _playGrey.hidden = NO;
    
}

- (IBAction)processDepressed:(id)sender {
    
    _process.hidden = YES;
    _processGrey.hidden = NO;
}

- (IBAction)exportDepressed:(id)sender {
    
    _export.hidden = YES;
    _exportGrey.hidden = NO;
}

- (IBAction)processPressed:(id)sender {
    
    _process.hidden = NO;
    _processGrey.hidden = YES;
    
    totalFFT = 0;
    
    firstPress = 1;

    // Clearing midi strings
    midiBlock = @"";
    midiComplete = @"";
    
    ////////////////////////
    ///// LOADING AUDIO ////
    ////////////////////////
    
    // Getting recorded audio
    AVURLAsset *recordedAudio = [AVURLAsset URLAssetWithURL:recorder.url options:nil];
    
    // Defining audio reader
    NSError *error = nil;
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:recordedAudio error:&error];
    
    // Defining audio track
    AVAssetTrack *track = [[recordedAudio tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
    
    // Assigning settings
    NSMutableDictionary *outputSettings = [NSMutableDictionary dictionary];
    [outputSettings setValue:[NSNumber numberWithInt:kAudioFormatLinearPCM] forKey:AVFormatIDKey];
    
    AVAssetReaderTrackOutput *readerOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track outputSettings:outputSettings];
    
    // Adding output to reader
    [reader addOutput:readerOutput];
    
    // Start asset reader
    [reader startReading];
    
    // Putting output into audio buffer
    CMSampleBufferRef audioBuffer = [readerOutput copyNextSampleBuffer];
    NSLog(@"Audio in buffer");
    
    // Calculating audio clip length
    CMTime recordedAudioDuration = recordedAudio.duration;
    float recordedAudioDurationSeconds = CMTimeGetSeconds(recordedAudioDuration);
    NSLog(@"Audio clip length: %f secs", recordedAudioDurationSeconds);
    
    // While buffer has contents...
    while (audioBuffer != NULL)
    {
        if (audioBuffer == NULL) continue;
        
        // Delaring new buffer contents
        CMBlockBufferRef buffer = CMSampleBufferGetDataBuffer(audioBuffer);
        
        // Creating audio buffer list
        AudioBufferList audioBufferList;
        
        // Creating audio buffer list from buffer
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(audioBuffer, NULL, &audioBufferList, sizeof(audioBufferList), NULL, NULL, kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, &buffer);
        
        // Going through audio buffer list
        for (int j = 0; j < audioBufferList.mNumberBuffers; j++)
        {
            // Declaring samples from audio buffer list
            SInt16 *bufferSamples = (SInt16*)audioBufferList.mBuffers[j].mData;
            
            // Counting each FFT
            fftCount++;
            totalFFT++;
            
            // Using temporary buffer to overlap frames
            for (j = 0; j < frameSize; j++)
            {
                if (j < step)
                {
                    overlapBufferB[j] = bufferSamples[j];
                }
                else if (j < frameSize)
                {
                    overlapBufferB[j] = bufferSamples[j] + overlapBufferA[j - step];
                }
                else
                {
                    overlapBufferB[j] = overlapBufferA[j - step];
                }
            }
                
            ////////////////////////
            //// vDSP FUNCTIONS ////
            ////////////////////////
            
            // Creating Hann window function
            for (int i = 0; i < frameSize; i++)
            {
                double window = 0.5 * (1.0 - cos((2.0 * M_PI * i) / (frameSize -  1)));
                
                // Applying window to each frame
                A.realp[i] = window * overlapBufferB[i];
                A.imagp[i] = 0;
            }
            
            // Applying FFT
            vDSP_fft_zrip(setupReal, &A, stride, log2Samples, FFT_FORWARD);
            
            // Magnitude
            vDSP_vdist(A.realp, stride, A.imagp, stride, magnitude, stride, range);
            
            // Detecting phase
            vDSP_zvphas(&A, stride, phase1, stride, range);
            
            // Calculating phase difference
            vDSP_vsub(phase2, stride, phase1, stride, dPhase, stride, range);
            
            // Saving phase
            memcpy(phase2, phase1, range * sizeof(float));
            
            for (int j = 1; j < range; j++)
            {
                ////////////////////////////
                //// PHASE CALCULATIONS ////
                ////////////////////////////
                
                // Adapted from http://stackoverflow.com/a/4912920/3070920
                // Getting phase difference
                deltaPhase = dPhase[j];
                
                // Subtract expected phase difference
                deltaPhase -= j * expect;
                
                // Wrap phase difference into +/- pi interval
                deltaPhase = remainder(deltaPhase, 2.0 * M_PI);
                
                // Calculating difference from bin frequency
                deltaPhase /= expect;
                
                // Calculating true frequency at j-th partial
                frequencies[j] = (j + deltaPhase) * freqPerBin;
            }
            
            float  maximum;
            unsigned long index;
            
            // Calculating maximum magnitude
            vDSP_maxmgvi(magnitude, stride, &maximum, &index, range);
            
            // Getting frequency at peak magnitudeu
            trueFrequency = frequencies[index];
            
            // Testing if input is above noise floor
            if (maximum > minimum)
            {
                // Print frequency and pitch
                // NSLog(@"%.1fHz", trueFrequency);
                
                if (trueFrequency < 75.6)
                {
                    // Ignore (Note below normal vocal range)
                    pitch = @"00";
                }
                else if (trueFrequency < 80.1)      // Eb2
                {
                    pitch = @"27";
                }
                else if (trueFrequency < 84.85)     // E2
                {
                    pitch = @"28";
                }
                else if (trueFrequency < 89.9)      // F2
                {
                    pitch = @"29";
                }
                else if (trueFrequency < 95.25)     // Gb2
                {
                    pitch = @"2A";
                }
                else if (trueFrequency < 100.9)     // G2
                {
                    pitch = @"2B";
                }
                else if (trueFrequency < 106.9)     // Ab2
                {
                    pitch = @"2C";
                }
                else if (trueFrequency < 113.25)    // A2
                {
                    pitch = @"2D";
                }
                else if (trueFrequency < 120.0)     // Bb2
                {
                    pitch = @"2E";
                }
                else if (trueFrequency < 127.15)    // B2
                {
                    pitch = @"2F";
                }
                else if (trueFrequency < 134.7)     // C2
                {
                    pitch = @"30";
                }
                else if (trueFrequency < 142.7)     // Db3
                {
                    pitch = @"31";
                }
                else if (trueFrequency < 151.2)     // D3
                {
                    pitch = @"32";
                }
                else if (trueFrequency < 160.2)     // Eb3
                {
                    pitch = @"33";
                }
                else if (trueFrequency < 169.7)     // E3
                {
                    pitch = @"34";
                }
                else if (trueFrequency < 179.8)     // F3
                {
                    pitch = @"35";
                }
                else if (trueFrequency < 190.5)     // Gb3
                {
                    pitch = @"36";
                }
                else if (trueFrequency < 201.85)    // G3
                {
                    pitch = @"37";
                }
                else if (trueFrequency < 213.85)    // Ab3
                {
                    pitch = @"38";
                }
                else if (trueFrequency < 226.55)    // A3
                {
                    pitch = @"39";
                }
                else if (trueFrequency < 240.0)     // Bb3
                {
                    pitch = @"3A";
                }
                else if (trueFrequency < 254.25)    // B3
                {
                    pitch = @"3B";
                }
                else if (trueFrequency < 269.4)     // C4
                {
                    pitch = @"3C";
                }
                else if (trueFrequency < 285.45)    // Db4
                {
                    pitch = @"3D";
                }
                else if (trueFrequency < 302.4)     // D4
                {
                    pitch = @"3E";
                }
                else if (trueFrequency < 320.35)    // Eb4
                {
                    pitch = @"3F";
                }
                else if (trueFrequency < 339.4)     // E4
                {
                    pitch = @"40";
                }
                else if (trueFrequency < 359.6)     // F4
                {
                    pitch = @"41";
                }
                else if (trueFrequency < 381.0)     // Gb4
                {
                    pitch = @"42";
                }
                else if (trueFrequency < 403.65)    // G4
                {
                    pitch = @"43";
                }
                else if (trueFrequency < 427.65)    // Ab4
                {
                    pitch = @"44";
                }
                else if (trueFrequency < 453.1)     // A4
                {
                    pitch = @"45";
                }
                else if (trueFrequency < 480.05)    // Bb4
                {
                    pitch = @"46";
                }
                else if (trueFrequency < 508.6)     // B4
                {
                    pitch = @"47";
                }
                else if (trueFrequency < 538.85)    // C5
                {
                    pitch = @"48";
                }
                else if (trueFrequency < 570.85)    // Db5
                {
                    pitch = @"49";
                }
                else if (trueFrequency < 604.8)     // D5
                {
                    pitch = @"4A";
                }
                else if (trueFrequency < 678.9)     // Eb5
                {
                    pitch = @"4B";
                }
                else if (trueFrequency < 719.25)    // E5
                {
                    pitch = @"4C";
                }
                else if (trueFrequency < 762.0)     // F5
                {
                    pitch = @"4D";
                }
                else if (trueFrequency < 807.3)     // Gb5
                {
                    pitch = @"4E";
                }
                else if (trueFrequency < 855.3)     // G5
                {
                    pitch = @"4F";
                }
                else if (trueFrequency < 906.05)    // Ab5
                {
                    pitch = @"50";
                }
                else if (trueFrequency < 960.05)    // A5
                {
                    pitch = @"51";
                }
                else if (trueFrequency < 1017.15)   // Bb5
                {
                    pitch = @"52";
                }
                else if (trueFrequency < 1077.6)    // B5
                {
                    pitch = @"53";
                }
                else if (trueFrequency < 1141.7)    // C6
                {
                    pitch = @"54";
                }
                else if (trueFrequency > 1141.7)
                {
                    // Ignore (Note above normal vocal range)
                    pitch = @"00";
                }
                
            }
            else
            {
                // Ignore (Input below noise floor)
                pitch = @"00";
            }
            
            //////////////
            //// MIDI ////
            //////////////
            
            // If the pitch has changed and the FFT has progressed
            if ((pitch != lastPitch) && (fftCount > 1))
            {
                NSLog(@"**************");
                
                // Calculating note length from FFT count and average FFT time
                noteLength = fftCount * 0.18;
                
                // Caculating time in terms of ticks
                long tickTime = noteLength * pulsesPerSec;
                
                // Converting hex to variable length quantity
                NSString *hexVariLen = @"";
                
                // Adapted from http://rosettacode.org/wiki/Variable-length_quantity#C
                uint8_t s[10];
                uint64_t x = tickTime;
                
                int i, j;
                for (j = 0; j < sizeof(x)/8; j++)
                {
                    // Calling the conversion function
                    convertToVariableLengthQuantity(x, s);
                    
                    i = 0;
                    do
                    {
                        uint32_t bits = s[i];
                        NSString *octet = [NSString stringWithFormat:@"%02X ", bits];
                        hexVariLen = [hexVariLen stringByAppendingString:octet];
                    }
                    while ((s[i++] & 0x80));
                }
                
                NSLog(@"Wait this: %@", hexVariLen);
                
                // For no input
                if ([pitch  isEqual: @"00"])
                {
                    // Adding delta time and 'note off' to string
                    midiDeltaTime = [NSString stringWithFormat:@"%@80 ", hexVariLen];
                    midiBlock = [midiBlock stringByAppendingString:midiDeltaTime];
                }
                // For normal input
                else
                {
                    // Adding delta time and 'note on' to string
                    midiDeltaTime = [NSString stringWithFormat:@"%@90 ", hexVariLen];
                    midiBlock = [midiBlock stringByAppendingString:midiDeltaTime];
                }
                
                // Resetting FFT counter
                fftCount = 0;
            }
            
            // Getting newly changed pitch
            if (fftCount == 1)
            {
                currentHexPitch = pitch;
            
                if (firstPress == 1)
                {
                    // Ignore the initial pitch
                }
                else if ([pitch  isEqual: @"00"])
                {
                    // Rest due to no input
                    NSLog(@"Stop this: %@ and play this: %@", stopPitch, currentHexPitch);
                    
                    // Adding pitch to be played and pitch to be stopped to string
                    midiPitch = [NSString stringWithFormat:@"%@ 00 00 80 %@ 00 ", currentHexPitch, stopPitch];
                    midiBlock = [midiBlock stringByAppendingString:midiPitch];
                }
                else
                {
                    // For normal action
                    NSLog(@"Stop this: %@ and play this: %@", stopPitch, currentHexPitch);
                    
                    // Adding pitch to be played and pitch to be stopped to string
                    midiPitch = [NSString stringWithFormat:@"%@ 60 00 80 %@ 00 ", currentHexPitch, stopPitch];
                    midiBlock = [midiBlock stringByAppendingString:midiPitch];
                }
        
                firstPress = 0;
            }
            
            lastPitch = pitch;
            stopPitch = currentHexPitch;
            
        }
        
        // Release buffers when FFT is completed
        CFRelease(buffer);
        CFRelease(audioBuffer);
        
        audioBuffer = [readerOutput copyNextSampleBuffer];
        
    }
    
    // Getting string length
    long midiBlockLength = [midiBlock length];
    
    // Adjusting for bytes and end data
    midiBlockLength /= 2;
    midiBlockLength += 4;
    
    NSString *additionalBytes = @"";
    
    // Adjusting octet to fit block size
    if (midiBlockLength < 16)
    {
        additionalBytes = @"00 00 00 0";
    }
    else if (midiBlockLength < 256)
    {
        additionalBytes = @"00 00 00 ";
    }
    else if (midiBlockLength < 4096)
    {
        additionalBytes = @"00 00 0";
    }
    else if (midiBlockLength < 8192)
    {
        additionalBytes = @"00 00 ";
    }
    else
    {
        // File is too large
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Alert!" message:@"Sorry, your file is too big.\n\nPlease record a shorter version."delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        
        [alert show];
        
        return;
    }
    
    // Converting PPQ to hex
    NSString *hexPPQ = [NSString stringWithFormat:@"%X", PPQ];
    
    NSLog(@"**************");
    
    // midi header and end data
    NSString *header = [NSString stringWithFormat:@"4D 54 68 64 00 00 00 06 00 01 00 01 00 %@ 4D 54 72 6B %@%lX ", hexPPQ, additionalBytes, midiBlockLength];
    NSString *end    = @"00 FF 2F 00";

    // Concatenating strings to form complete midi string
    midiComplete = [midiComplete stringByAppendingString:header];
    midiComplete = [midiComplete stringByAppendingString:midiBlock];
    midiComplete = [midiComplete stringByAppendingString:end];
    
    // Printing complete midi string
    NSLog(@"\n\n\nMIDI Data:\n\n%@", midiComplete);
    
    // Writing MIDI file
    // Opening documents directory
    NSArray *path = NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *directory = [path objectAtIndex:0];
    
    // Declaring file name
    NSString *fileName = [NSString stringWithFormat:@"%@/Vocal Sketcher MIDI.mid", directory];
    
    // Saving MIDI data to file
    [midiComplete writeToFile:fileName atomically:NO encoding:NSStringEncodingConversionAllowLossy error:nil];
    
    /* Calculating average time for FFT loop
    NSLog(@"%f", totalFFT);
    float timePerFFT = recordedAudioDurationSeconds/totalFFT;
    NSLog(@"%f", timePerFFT);*/
    
    [processButton setEnabled:NO];
    [exportButton setEnabled:YES];
    _processingCompletedGrey.hidden = NO;
    _process.hidden = YES;
    _processGrey.hidden = YES;
    _export.hidden = NO;
    _exportGrey.hidden = YES;
}

- (IBAction)exportPressed:(id)sender {
    
    _exportingGrey.hidden = NO;
    _export.hidden = YES;
    _exportGrey.hidden = YES;
    
    [exportButton setEnabled:NO];
    
    ///////////////////
    //// EXPORTING ////
    ///////////////////
    
    // If the device is set up to send email
    Class mailClass = (NSClassFromString(@"MFMailComposeViewController"));
    
    if (mailClass != nil)
    {
        
        // Writing email subject
        MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];
        picker.mailComposeDelegate = self;
        [picker setSubject:@"Vocal Sketcher MIDI Export"];
        
        // Attaching midi data
        NSData *data = [midiComplete dataUsingEncoding:NSUTF8StringEncoding];
        [picker addAttachmentData:data mimeType:@"MIDI/mid" fileName:@"Vocal Sketcher Export.mid"];
        
        // Writing email body text
        NSString *emailBody = @"MIDI export attached...";
        [picker setMessageBody:emailBody isHTML:NO];
        
        
        //Display Email Composer
        if ([mailClass canSendMail])
        {
            // Open email view controller
            [self presentViewController:picker animated:YES completion:nil];
        }
        else
        {
            _exportingGrey.hidden = YES;
            _exportGrey.hidden = YES;
            _exportCompletedGrey.hidden = YES;
            _export.hidden = NO;
            
            [exportButton setEnabled:YES];
        }
        
    }
    
}



- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error
{
    // Function called to show the result of the emailing
    
    // Displaying message alerts regarding the outcome of the email
    switch (result)
    {
        // Email cancelled
        case MFMailComposeResultCancelled:
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Export Status" message:@"Exporting Cancelled"delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            
            [alert show];
            
            _exportingGrey.hidden = YES;
            _export.hidden = NO;
            [exportButton setEnabled:YES];
        }
            break;
            
        // Email saved
        case MFMailComposeResultSaved:
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Export Status" message:@"Email Saved"delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            
            [alert show];
            
            _exportingGrey.hidden = YES;
            _export.hidden = NO;
            [exportButton setEnabled:YES];
        }
            break;
            
        // Email sent
        case MFMailComposeResultSent:
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Export Status" message:@"Email Sent"delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            
            [alert show];
            
            _exportingGrey.hidden = YES;
            _exportCompletedGrey.hidden = NO;
            
        }
            break;
            
        // Email failed
        case MFMailComposeResultFailed:
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Export Status" message:@"Exporting Failed"delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            
            [alert show];
            
            _exportingGrey.hidden = YES;
            _export.hidden = NO;
            [exportButton setEnabled:YES];
        }
            break;
            
        // Any other outcome...
        default:
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Export Status" message:@"Email Not Sent"delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            
            [alert show];
            
            _exportingGrey.hidden = YES;
            _export.hidden = NO;
            [exportButton setEnabled:YES];
        }
            break;
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
    
}

- (IBAction)infoPressed:(id)sender {
    
    _info.hidden = NO;
    _infoGrey.hidden = YES;
    
    // Showing instruction message
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Information" message:@"\nWelcome to Vocal Sketcher!\n\nPress RECORD and sing into your phone\n\nPress PLAY to listen to your recording\n\nPress PROCESS to convert your voice to a MIDI file \n\nPress EXPORT to email the file!"delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    
    [alert show];
}

- (IBAction)infoDepressed:(id)sender {
    
    _infoGrey.hidden = NO;
    _info.hidden = YES;
}

#pragma mark - AVAudioRecorderDelegate

- (void) audioRecorderDidFinishRecording:(AVAudioRecorder *)avrecorder successfully:(BOOL)flag {
    [playButton setEnabled:YES];
    [processButton setEnabled:YES];
    
    _record.hidden = NO;
    _stop.hidden = YES;
    _recordGrey.hidden = YES;
    _play.hidden = NO;
    _playGrey.hidden = YES;
    _process.hidden = NO;
    _processGrey.hidden = YES;
    _processingCompletedGrey.hidden = YES;
}

#pragma mark - AVAudioPlayerDelegate

- (void) audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    
    NSLog(@"Playing stopped");
    
    _playingGrey.hidden = YES;
    _play.hidden = NO;
    [playButton setEnabled:YES];
    
}

@end
