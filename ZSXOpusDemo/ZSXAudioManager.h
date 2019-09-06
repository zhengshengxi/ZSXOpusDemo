//
//  ZSXAudioManager.h
//  ZSXOpusDemo
//
//  Created by 郑胜昔 on 2019/8/22.
//  Copyright © 2019 郑胜昔. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZSXAudioManager : NSObject

@property (nonatomic, copy) NSString *filePath;

+ (instancetype)shared;

// Recording
- (void)recordStartWithProcess:(void (^)(float peakPower))processHandler completed:(void (^)(NSData *data, NSError *error))completedHandler;
- (void)recordStop;
- (BOOL)isRecording;

// Playing
- (void)playAudioData:(NSData *)data completionHandler:(void (^)(BOOL successfully))handler;
- (void)playOpusAudioData:(NSData *)opusData completionHandler:(void (^)(BOOL successfully))handler;
- (BOOL)isPlaying;

@end

NS_ASSUME_NONNULL_END
