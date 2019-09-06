//
//  ZSXAudioManager.m
//  ZSXOpusDemo
//
//  Created by 郑胜昔 on 2019/8/22.
//  Copyright © 2019 郑胜昔. All rights reserved.
//

#import "ZSXAudioManager.h"
#import <AVFoundation/AVFoundation.h>
#import "AudioDefine.h"
#import "ZSXOpusCodec.h"

@interface ZSXAudioManager() <AVAudioRecorderDelegate, AVAudioPlayerDelegate>

@property (nonatomic, strong) AVAudioSession *audioSession;
@property (nonatomic, strong) AVAudioRecorder *audioRecorder;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;

@property (nonatomic, strong) NSTimer *timer;

@end

@implementation ZSXAudioManager {
    dispatch_queue_t queue;
    
    void (^_recordProcessHandler)(float volume);
    void (^_recordCompletedHandler)(NSData *data, NSError *error);
    
    void (^_palyCompletedHandler)(BOOL successfully);
}

+ (instancetype)shared {
    static id _instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[super allocWithZone: NULL] init];
    });
    return _instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _audioSession = [AVAudioSession sharedInstance];
        [_audioSession setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:nil];
        
        NSURL *directory = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask][0];
        NSURL *fileURL = [directory URLByAppendingPathComponent:@"record.wav"];
        self.filePath = fileURL.absoluteString;
        NSDictionary *settings = @{AVFormatIDKey: @(kAudioFormatLinearPCM),
                                   AVLinearPCMBitDepthKey: @(PCM_BIT_DEPTH),
                                   AVNumberOfChannelsKey: @(CHANNELS),
                                   AVSampleRateKey: @(SAMPLE_RATE)};
        _audioRecorder = [[AVAudioRecorder alloc] initWithURL:fileURL settings:settings error:nil];
        _audioRecorder.meteringEnabled = true;
        _audioRecorder.delegate = self;
        
        _timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(detectionPeakPower) userInfo:nil repeats:YES];
        _timer.fireDate = [NSDate distantFuture];
        
        queue = dispatch_queue_create("audio-manager-queue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

#pragma mark - Recording

- (void)recordStartWithProcess:(void (^)(float peakPower))processHandler
                     completed:(void (^)(NSData *data, NSError *error))completedHandler {
    dispatch_async(queue, ^{
        if (!self.audioRecorder.isRecording) {
            self->_recordProcessHandler = processHandler;
            self->_recordCompletedHandler = completedHandler;
            
            [self.audioRecorder prepareToRecord];
            [self.audioRecorder record];
            
            self->_timer.fireDate = [NSDate distantPast];
        } else {
            if (completedHandler) {
                NSError *error = [NSError errorWithDomain:@"AudioManager" code:-1 userInfo:@{@"info": @"audio recorder is running."}];
                dispatch_async(dispatch_get_main_queue(), ^{
                    completedHandler(nil, error);
                });
            }
        }
    });
}

- (void)recordStop {
    dispatch_async(queue, ^{
        if (self.audioRecorder.isRecording) {
            [self.audioRecorder stop];
            self->_timer.fireDate = [NSDate distantFuture];
        }
    });
}

- (BOOL)isRecording {
    return self.audioRecorder.isRecording;
}

- (void)detectionPeakPower {
    dispatch_async(queue, ^{
        if (self.audioRecorder.isRecording && self->_recordProcessHandler) {
            [self.audioRecorder updateMeters];
            float db = [self.audioRecorder peakPowerForChannel:0];
            float vol = pow(10, (0.05 * db));
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_recordProcessHandler(vol);
            });
        }
    });
}

#pragma mark - AVAudioRecorderDelegate

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
    if (_recordCompletedHandler) {
        if (flag) {
            NSData *data = [[NSData alloc] initWithContentsOfURL:recorder.url];
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_recordCompletedHandler(data, nil);
            });
        } else {
            NSError *error = [NSError errorWithDomain:@"AudioManager" code:-2 userInfo:@{@"info": @"audio recorder is failed."}];
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_recordCompletedHandler(nil, error);
            });
        }
    }
}


#pragma mark - Playing

- (void)playAudioData:(NSData *)data completionHandler:(void (^)(BOOL successfully))handler {
    dispatch_async(queue, ^{
        if (!self.audioPlayer.isPlaying) {
            self->_palyCompletedHandler = handler;
            self.audioPlayer = [[AVAudioPlayer alloc] initWithData:data error:nil];
            self.audioPlayer.delegate = self;
            [self.audioPlayer play];
        }
    });
}

- (void)playOpusAudioData:(NSData *)opusData completionHandler:(void (^)(BOOL successfully))handler {
    dispatch_async(queue, ^{
        if (!self.audioPlayer.isPlaying) {
            NSData *newpcm = [ZSXOpusCodec.shared decode:opusData];
            NSRange dataFlagRange = [newpcm rangeOfData:[@"data" dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions range:NSMakeRange(0, newpcm.length)];
            if (dataFlagRange.length == 0) {
                NSLog(@"ERROR: not found 'data' flag.");
                return;
            }
            NSUInteger pcmLenIdx = NSMaxRange(dataFlagRange);
            uint32_t pcmDataLen = *((uint32_t *)((char *)newpcm.bytes + pcmLenIdx));
            NSUInteger pcmDataIdx = pcmLenIdx + sizeof(uint32_t);
            NSMutableData *wavHeader = [[newpcm subdataWithRange:NSMakeRange(0, pcmDataIdx)] mutableCopy];
            *((uint32_t *)((char *)wavHeader.bytes + pcmLenIdx)) = (uint32_t)newpcm.length;
            [wavHeader appendData:newpcm]; //新pcm添加wav头
            NSData *newWav = wavHeader;
            
            self->_palyCompletedHandler = handler;
            self.audioPlayer = [[AVAudioPlayer alloc] initWithData:newWav error:nil];
            self.audioPlayer.delegate = self;
            [self.audioPlayer play];
        }
    });
}

- (BOOL)isPlaying {
    return _audioPlayer.isPlaying;
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    if (_palyCompletedHandler) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_palyCompletedHandler(flag);
        });
    }
}

@end
