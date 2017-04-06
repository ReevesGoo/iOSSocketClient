//
//  ViewController.m
//  iOSSocketClient
//
//  Created by ReevesGoo on 2017/3/15.
//  Copyright © 2017年 ReevesGoo. All rights reserved.
//

#import "ViewController.h"
#include<stdio.h>
#include<unistd.h>
#include<strings.h>
#include<sys/types.h>
#include<sys/socket.h>
#include<netinet/in.h>
#include<netdb.h>
#import <AudioToolbox/AudioToolbox.h>
#import "AudioConstant.h"


#define BUFFER_SIZE 256

@interface ViewController (){
    int toServerSocket;
    
    AudioStreamBasicDescription audioDescription;///音频参数
    AudioQueueRef audioQueue;//音频播放队列
    AudioQueueBufferRef audioQueueBuffers[QUEUE_BUFFER_SIZE];//音频缓存
    NSLock *synlock ;///同步控制
    
    long audioDataIndex;
    
}
@property (weak, nonatomic) IBOutlet UITextField *ipAddress;
@property (weak, nonatomic) IBOutlet UITextField *portAddress;
@property (weak, nonatomic) IBOutlet UITextField *msgTextField;

@property (nonatomic,strong) NSMutableData *allData;
@property (nonatomic,assign) BOOL isReceiveAudioData;
@property (weak, nonatomic) IBOutlet UIButton *playBtn;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.isReceiveAudioData = false;
//    [VoiceConvertHandle shareInstance].delegate = self;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(disconnectServer) name:@"appwillterminate" object:nil];
 
    
    // Do any additional setup after loading the view, typically from a nib.
}

- (IBAction)connect:(UIButton *)sender {

    
    if ([sender.currentTitle isEqualToString:@"连接服务器"]) {
         NSLog(@"conn server...");
        [sender setTitle:@"断开服务器" forState:UIControlStateNormal];
        
        struct hostent *he;
        struct sockaddr_in server;
        
        NSString *ip = self.ipAddress.text;
        NSString *port = self.portAddress.text;
        
        if((he = gethostbyname([ip cStringUsingEncoding:NSUTF8StringEncoding])) == NULL)
        {
            printf("gethostbyname error/n");
            //exit(1);
        }
        if((toServerSocket = socket(AF_INET, SOCK_STREAM, 0)) == -1)
        {
            printf("socket() error /n");
            //exit(1);
        }
        bzero(&server, sizeof(server));
        
        server.sin_family = AF_INET;
        server.sin_port = htons([port intValue]);
        server.sin_addr = *((struct in_addr *)he->h_addr);
        
        if(connect(toServerSocket, (struct sockaddr *)&server, sizeof(server)) == -1)
        {
            printf("\n connetc() error ");
            // exit(1);
        }
        [self startListenAndNewThread];
        
        
    }else{
        NSLog(@"disconnect server");
        [sender setTitle:@"连接服务器" forState:UIControlStateNormal];
         [self sendToServer:@"-"];
        close(toServerSocket);
//        AudioQueueReset(audioQueue);
        [self.playBtn setTitle:@"播放" forState:UIControlStateNormal];
        self.isReceiveAudioData = false;
        AudioQueueStop(audioQueue, true);
        self.allData = nil;
        self.allData  = [NSMutableData data];
    }
}

-(void)disconnectServer{

    [self sendToServer:@"-"];
    close(toServerSocket);

}

// 在新线程中监听客户端
-(void) startListenAndNewThread{
    [NSThread detachNewThreadSelector:@selector(initServer)
                             toTarget:self withObject:nil];
}
- (IBAction)play:(UIButton *)sender {
 

        if ([sender.currentTitle isEqualToString:@"播放"]) {
            
            self.isReceiveAudioData = true;
            [sender setTitle:@"停止" forState:UIControlStateNormal];
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5
                                                                      * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self initAudio];
                    AudioQueueStart(audioQueue, NULL);
                    for(int i=0;i<QUEUE_BUFFER_SIZE;i++)
                    {
                        [self readPCMAndPlay:audioQueue buffer:audioQueueBuffers[i]];
                    }

            });
            
          
            
        }else{
            self.isReceiveAudioData = false;
            //重置缓冲队列
            AudioQueueReset(audioQueue);
//            AudioQueueStop(audioQueue, true);
            self.allData = nil;
            self.allData  = [NSMutableData data];
            
            [sender setTitle:@"播放" forState:UIControlStateNormal];
        }
 
}

-(void)initAudio
{
    audioDataIndex = 0;
    ///设置音频参数
    audioDescription.mSampleRate = kSamplingRate;//采样率
    audioDescription.mFormatID = kAudioFormatLinearPCM;
    audioDescription.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    audioDescription.mChannelsPerFrame = 1;///单声道
    audioDescription.mFramesPerPacket = 1;//每一个packet一侦数据
    audioDescription.mBitsPerChannel = kBitsPerChannels;//每个采样点16bit量化
    audioDescription.mBytesPerFrame = kBytesPerFrame;
    audioDescription.mBytesPerPacket = kBytesPerFrame;
    ///创建一个新的从audioqueue到硬件层的通道
    //	AudioQueueNewOutput(&audioDescription, AudioPlayerAQInputCallback, self, CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &audioQueue);///使用当前线程播
    AudioQueueNewOutput(&audioDescription, AudioPlayerAQInputCallback, (__bridge void * _Nullable)(self), nil, nil, 0, &audioQueue);//使用player的内部线程播
    ////添加buffer区
    for(int i=0;i<QUEUE_BUFFER_SIZE;i++)
    {
        int result =  AudioQueueAllocateBuffer(audioQueue, MIN_SIZE_PER_FRAME, &audioQueueBuffers[i]);///创建buffer区，MIN_SIZE_PER_FRAME为每一侦所需要的最小的大小，该大小应该比每次往buffer里写的最大的一次还大
        NSLog(@"AudioQueueAllocateBuffer i = %d,result = %d",i,result);
    }
}


-(void)readPCMAndPlay:(AudioQueueRef)outQ buffer:(AudioQueueBufferRef)outQB
{
    [synlock lock];
    if(audioDataIndex + EVERY_READ_LENGTH < self.allData.length)
    {
        NSData *allData = [self.allData subdataWithRange:NSMakeRange(audioDataIndex, EVERY_READ_LENGTH)];
        memcpy(outQB->mAudioData, [allData bytes], EVERY_READ_LENGTH);
        audioDataIndex += EVERY_READ_LENGTH;
        outQB->mAudioDataByteSize =EVERY_READ_LENGTH;
        AudioQueueEnqueueBuffer(outQ, outQB, 0, NULL);
    }
    [synlock unlock];

}

/*
 用静态函数通过void *input来获取原类指针
 这个回调存在的意义是为了重用缓冲buffer区，当通过AudioQueueEnqueueBuffer(outQ, outQB, 0, NULL);函数放入queue里面的音频文件播放完以后，通过这个函数通知
 调用者，这样可以重新再使用回调传回的AudioQueueBufferRef
 */
static void AudioPlayerAQInputCallback(void *input, AudioQueueRef outQ, AudioQueueBufferRef outQB)
{
    NSLog(@"AudioPlayerAQInputCallback");
    ViewController *viewcontroller = (__bridge ViewController *)input;
    [viewcontroller checkUsedQueueBuffer:outQB];
    [viewcontroller readPCMAndPlay:outQ buffer:outQB];
}



-(void)initServer {
    char buffer[EVERY_READ_LENGTH];
//    [player start];
    
    while (1) {
        recv(toServerSocket, buffer, EVERY_READ_LENGTH,0);
        NSData *data = [NSData dataWithBytes:buffer length:EVERY_READ_LENGTH];
        NSLog(@"receive datalength:%lu",(unsigned long)[data length]);
        
        if (self.isReceiveAudioData) {
              [self.allData appendData:data];
        }
    }

    
}

-(NSMutableData *)allData{

    if (!_allData) {
        _allData = [NSMutableData data];
    }
    
    return _allData;


}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.ipAddress resignFirstResponder];
    [self.msgTextField resignFirstResponder];
    [self.portAddress resignFirstResponder];
}

- (IBAction)send:(UIButton *)sender {
    [self sendToServer:self.msgTextField.text];
}

-(void) sendToServer:(NSString*) message{
    NSLog(@"send message to server...");
    
    char mychar[10240];
    strcpy(mychar,(char *)[message UTF8String]);

    
    char buffer[BUFFER_SIZE];
    bzero(buffer, BUFFER_SIZE);
    //Byte b;
//    const char* talkData =
//    [ message cStringUsingEncoding:NSUTF8StringEncoding];
    
    //发送buffer中的字符串到new_server_socket,实际是给客户端
    send(toServerSocket,mychar,1024,0);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


-(void)checkUsedQueueBuffer:(AudioQueueBufferRef) qbuf
{
    if(qbuf == audioQueueBuffers[0])
    {
        NSLog(@"AudioPlayerAQInputCallback,bufferindex = 0");
    }
    if(qbuf == audioQueueBuffers[1])
    {
        NSLog(@"AudioPlayerAQInputCallback,bufferindex = 1");
    }
    if(qbuf == audioQueueBuffers[2])
    {
        NSLog(@"AudioPlayerAQInputCallback,bufferindex = 2");
    }
    if(qbuf == audioQueueBuffers[3])
    {
        NSLog(@"AudioPlayerAQInputCallback,bufferindex = 3");
    }
}


-(void)dealloc{

    [[NSNotificationCenter defaultCenter] removeObserver:self];

}

@end
