//
//  ZSXOpusCodec.m
//  ZSXOpusDemo
//
//  Created by 郑胜昔 on 2019/8/22.
//  Copyright © 2019 郑胜昔. All rights reserved.
//

#import "ZSXOpusCodec.h"
#import "opus.h"
#import "AudioDefine.h"

#define APPLICATION         OPUS_APPLICATION_VOIP
#define MAX_PACKET_BYTES    (FRAME_SIZE * CHANNELS * sizeof(opus_int16))
#define MAX_FRAME_SIZE      (FRAME_SIZE * CHANNELS * sizeof(opus_int16))

// 用于记录opus块大小的类型
typedef opus_int16 OPUS_DATA_SIZE_T;

@implementation ZSXOpusCodec {
    OpusEncoder *_encoder;
    OpusDecoder *_decoder;
}

+ (instancetype)shared {
    static id _instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[super allocWithZone: NULL] init];
    });
    return _instance;
}

+ (id)allocWithZone:(struct _NSZone *)zone {
    return [self shared];
}

- (id)copyWithZone:(struct _NSZone *)zone {
    return [[self class] shared];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _encoder = opus_encoder_create(SAMPLE_RATE, CHANNELS, APPLICATION, NULL);
        opus_encoder_ctl(_encoder, OPUS_SET_BITRATE(BITRATE));
        opus_encoder_ctl(_encoder, OPUS_SET_SIGNAL(OPUS_SIGNAL_VOICE));
        //        opus_encoder_ctl(_encoder, OPUS_SET_VBR(0));
        //        opus_encoder_ctl(_encoder, OPUS_SET_APPLICATION(OPUS_APPLICATION_VOIP));
        
        _decoder = opus_decoder_create(SAMPLE_RATE, CHANNELS, NULL);
    }
    return self;
}

#pragma mark - Public

- (NSData *)encode:(NSData *)PCM {
    opus_int16 *PCMPtr = (opus_int16 *)PCM.bytes;
    int PCMSize = (int)PCM.length / sizeof(opus_int16);
    opus_int16 *PCMEnd = PCMPtr + PCMSize;
    
    NSMutableData *mutData = [NSMutableData data];
    unsigned char encodedPacket[MAX_PACKET_BYTES];
    
    // 记录opus块大小
    OPUS_DATA_SIZE_T encodedBytes = 0;
    
    while (PCMPtr + FRAME_SIZE < PCMEnd) {
        encodedBytes = opus_encode(_encoder, PCMPtr, FRAME_SIZE, encodedPacket, MAX_PACKET_BYTES);
        if (encodedBytes <= 0) {
            NSLog(@"ERROR: encodedBytes<=0");
            return nil;
        }
        NSLog(@"encodedBytes: %d",  encodedBytes);
        
        // 保存opus块大小
        [mutData appendBytes:&encodedBytes length:sizeof(encodedBytes)];
        // 保存opus数据
        [mutData appendBytes:encodedPacket length:encodedBytes];
        
        PCMPtr += FRAME_SIZE;
    }
    
    return mutData.length > 0 ? mutData : nil;
}

- (NSData *)decode:(NSData *)opus {
    unsigned char *opusPtr = (unsigned char *)opus.bytes;
    int opusSize = (int)opus.length;
    unsigned char *opusEnd = opusPtr + opusSize;
    
    NSMutableData *mutData = [NSMutableData data];
    
    opus_int16 decodedPacket[MAX_FRAME_SIZE];
    int decodedSamples = 0;
    
    // 保存opus块大小的数据
    OPUS_DATA_SIZE_T nBytes = 0;
    
    while (opusPtr < opusEnd) {
        // 取出opus块大小的数据
        nBytes = *(OPUS_DATA_SIZE_T *)opusPtr;
        opusPtr += sizeof(nBytes);
        
        decodedSamples = opus_decode(_decoder, opusPtr, nBytes, decodedPacket, MAX_FRAME_SIZE, 0);
        if (decodedSamples <= 0) {
            NSLog(@"ERROR: decodedSamples<=0");
            return nil;
        }
        NSLog(@"decodedSamples:%d", decodedSamples);
        [mutData appendBytes:decodedPacket length:decodedSamples * sizeof(opus_int16)];
        
        opusPtr += nBytes;
    }
    
    return mutData.length > 0 ? mutData : nil;
}

@end
