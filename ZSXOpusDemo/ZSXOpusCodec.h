//
//  ZSXOpusCodec.h
//  ZSXOpusDemo
//
//  Created by 郑胜昔 on 2019/8/22.
//  Copyright © 2019 郑胜昔. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZSXOpusCodec : NSObject

+ (instancetype)shared;

/**
 将PCM数据编码成opus数据
 
 @param PCM 待编码的PCM格式数据
 @return 成功返回opus数据, 失败返回nil.
 */
- (NSData *)encode:(NSData *)PCM;

/**
 将opus数据解码成PCM数据
 
 @param opus 已编码opus格式数据
 @return 成功返回PCM数据, 失败返回nil.
 */
- (NSData *)decode:(NSData *)opus;

@end

NS_ASSUME_NONNULL_END
