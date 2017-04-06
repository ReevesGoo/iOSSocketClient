//
//  AudioConstant.h
//  iOSSocketClient
//
//  Created by ReevesGoo on 2017/3/15.
//  Copyright © 2017年 ReevesGoo. All rights reserved.
//

#import <Foundation/Foundation.h>

// Audio Settings
#define kNumberBuffers      3
#define t_sample             SInt16
#define kSamplingRate       20000
#define kNumberChannels     1
#define kBitsPerChannels    (sizeof(t_sample) * 8)
#define kBytesPerFrame      (kNumberChannels * sizeof(t_sample))
//#define kFrameSize          (kSamplingRate * sizeof(t_sample))
#define kFrameSize          1000

#define QUEUE_BUFFER_SIZE  4//队列缓冲个数
#define EVERY_READ_LENGTH  1000 //每次从文件读取的长度
#define MIN_SIZE_PER_FRAME 3000 //每侦最小数据长度
@interface AudioConstant : NSObject

@end
