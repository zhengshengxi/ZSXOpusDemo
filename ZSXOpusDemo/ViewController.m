//
//  ViewController.m
//  ZSXOpusDemo
//
//  Created by 郑胜昔 on 2019/8/22.
//  Copyright © 2019 郑胜昔. All rights reserved.
//

#import "ViewController.h"
#import "ZSXAudioManager.h"
#import "ZSXOpusCodec.h"
#import "ZSXPlotView.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIButton *btn;
@property (weak, nonatomic) IBOutlet UILabel *lblInfo;
@property (nonatomic,strong) ZSXPlotView *wavPlotView;
@property (nonatomic,strong) ZSXPlotView *opusPlotView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]initWithTitle:@"分享" style:UIBarButtonItemStylePlain target:self action:@selector(shareAction:)];
    
    self.wavPlotView = [[ZSXPlotView alloc]initWithFrame:CGRectMake(0, 100, self.view.frame.size.width, 150)];
    [self.view addSubview:self.wavPlotView];
    
    self.opusPlotView = [[ZSXPlotView alloc]initWithFrame:CGRectMake(0, 300, self.view.frame.size.width, 150)];
    [self.view addSubview:self.opusPlotView];
}

- (IBAction)btnAction:(id)sender {
    if ([ZSXAudioManager.shared isRecording]) {
        [sender setTitle:@"开始录音" forState:UIControlStateNormal];
        [sender setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
        [ZSXAudioManager.shared recordStop];
    } else {
        [sender setTitle:@"停止" forState:UIControlStateNormal];
        [sender setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        
        [ZSXAudioManager.shared recordStartWithProcess:^(float peakPower) {
            NSLog(@"%.2f", peakPower);
        } completed:^(NSData *data, NSError *error) {
            if (error) {
                NSLog(@"record err:%@", error);
            } else {
                NSLog(@"record completed:%zd", data.length);
                [self wav2opus2wav:data];
            }
        }];
    }
}

- (void)wav2opus2wav:(NSData *)data {
    // seeking ‘data’ flag.
    NSRange dataFlagRange = [data rangeOfData:[@"data" dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions range:NSMakeRange(0, data.length)];
    if (dataFlagRange.length == 0) {
        NSLog(@"ERROR: not found 'data' flag.");
        return;
    }
    
    // WAV => PCM
    NSUInteger pcmLenIdx = NSMaxRange(dataFlagRange);
    uint32_t pcmDataLen = *((uint32_t *)((char *)data.bytes + pcmLenIdx));
    NSUInteger pcmDataIdx = pcmLenIdx + sizeof(uint32_t);
    NSData *pcmData = [data subdataWithRange:(NSMakeRange(pcmDataIdx, pcmDataLen))];
    // 绘制原PCM波形
    [self.wavPlotView setPoints:pcmData];
    NSLog(@"WAV => PCM: %zd", pcmData.length);
    
    // PCM => OPUS
    NSData *opus = [ZSXOpusCodec.shared encode:pcmData];
    NSLog(@"PCM => OPUS: %zd", opus.length);
    
    // OPUS => PCM
    NSData *newpcm = [ZSXOpusCodec.shared decode:opus];
    // 绘制后PCM波形
    [self.opusPlotView setPoints:newpcm];
    NSLog(@"OPUS => PCM: %zd", newpcm.length);
    
    // PCM => WAV
    NSMutableData *wavHeader = [[data subdataWithRange:NSMakeRange(0, pcmDataIdx)] mutableCopy];
    *((uint32_t *)((char *)wavHeader.bytes + pcmLenIdx)) = (uint32_t)newpcm.length;
    [wavHeader appendData:newpcm]; //新pcm添加wav头
    NSData *newWav = wavHeader;
    NSLog(@"PCM => WAV: %zd", newWav.length);
    
    // 更新 info label
    self.lblInfo.text = [NSString stringWithFormat:@"原PCM: %zd 字节 \nOPUS: %zd 字节 \n后PCM: %zd 字节  \n压缩倍数:%.2f", pcmData.length, opus.length, newpcm.length, 1.0*pcmData.length/opus.length];
    
    // 播放解码出来的wav
    [ZSXAudioManager.shared playAudioData:newWav completionHandler:^(BOOL successfully) {
        NSLog(@"SUCCESS: wav -> pcm -> opus -> pcm -> wav : %.2f", 1.0*pcmData.length/opus.length);
    }];
}

-(void)shareAction:(UIBarButtonItem *)sender {
    NSString *testToShare = @"分享的标题";
    NSURL *urlToShare = [NSURL URLWithString:ZSXAudioManager.shared.filePath];
    NSArray *activityItems = @[testToShare,urlToShare];
    UIActivityViewController *activityVc = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
    [self presentViewController:activityVc animated:YES completion:nil];
    activityVc.completionWithItemsHandler = ^(UIActivityType  _Nullable activityType, BOOL completed, NSArray * _Nullable returnedItems, NSError * _Nullable activityError) {
        if (completed) {
            NSLog(@"分享成功");
        } else{
            NSLog(@"分享取消");
        }
    };
}

@end
