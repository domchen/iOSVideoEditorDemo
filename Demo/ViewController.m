//
//  ViewController.m
//  Demo
//
//  Created by dom on 11/10/16.
//  Copyright © 2016 domchen. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

#define TIMER_INTERVAL 1
typedef void(^PropertyChangeBlock)(AVCaptureDevice *captureDevice);

static NSString* toFixedString(int value) {
    if(value<10){
        return  [NSString stringWithFormat:@"0%d", value];
    }
    return [NSString stringWithFormat:@"%d",value];
}

@interface ViewController ()<AVCaptureFileOutputRecordingDelegate>
@property (strong,nonatomic) AVCaptureSession *captureSession;
@property (strong,nonatomic) AVCaptureDeviceInput *captureDeviceInput;
@property (strong,nonatomic) AVCaptureMovieFileOutput *captureMovieFileOutput;
@property (strong,nonatomic) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;

@end

@implementation ViewController {
    
    int currentTime;
    NSMutableArray *animationImages;
    NSTimer *countTimer;
    UIView* progressPreView;
    float progressStep;
    
    float preLayerWidth;
    float preLayerHeight;
    float preLayerHWRate;
}
@synthesize recordButton;
@synthesize stopButton;
@synthesize viewContainer;
@synthesize bottomView;
@synthesize timeLabel;

- (IBAction)startRecord:(id)sender {
    [UIView animateWithDuration:0.5 animations:^{recordButton.alpha = 0.0;}];
    [UIView animateWithDuration:0.5 animations:^{stopButton.alpha = 1.0;}];
    stopButton.hidden = NO;
    
    AVCaptureConnection *captureConnection=[self.captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
    captureConnection.videoOrientation=[self.captureVideoPreviewLayer connection].videoOrientation;
    [self.captureMovieFileOutput startRecordingToOutputFileURL:[NSURL fileURLWithPath:[self getVideoSaveFilePathString]] recordingDelegate:self];
    
}

- (IBAction)stopRecord:(id)sender {
    [UIView animateWithDuration:0.5 animations:^{recordButton.alpha = 1.0;}];
    [UIView animateWithDuration:0.5 animations:^{stopButton.alpha = 0.0;}];
    [self stopTimer];
    [self.captureMovieFileOutput stopRecording];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    preLayerWidth = SCREEN_WIDTH;
    preLayerHeight = SCREEN_HEIGHT;
    preLayerHWRate =preLayerHeight/preLayerWidth;
    
    animationImages = [NSMutableArray array];
    NSString *baseURL = [[NSBundle mainBundle] pathForResource:@"bird_1" ofType:@"png"];
    baseURL = [baseURL substringToIndex:baseURL.length-5];
    for(int i=1;i<54;i++){
        NSString* path = [NSString stringWithFormat:@"%@%d%@",baseURL,i,@".png"];
        UIImage* image = [UIImage imageNamed:path];
        if(image){
            [animationImages addObject:(id)image.CGImage];
        }
    }

    [self createVideoFolderIfNotExist];
    [self initCapture];


}


- (BOOL)prefersStatusBarHidden
{
    return YES;
}

-(void)initCapture{
    
    _captureSession=[[AVCaptureSession alloc]init];
    if ([_captureSession canSetSessionPreset:AVCaptureSessionPresetHigh]) {
        _captureSession.sessionPreset=AVCaptureSessionPresetiFrame960x540;
    }
    
    
    AVCaptureDevice *captureDevice=[self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];
    AVCaptureDevice *audioCaptureDevice=[[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
    
    NSError *error=nil;
    _captureDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:captureDevice error:&error];
    
    AVCaptureDeviceInput *audioCaptureDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:audioCaptureDevice error:&error];
    
    _captureMovieFileOutput=[[AVCaptureMovieFileOutput alloc]init];
    
    if ([_captureSession canAddInput:_captureDeviceInput]) {
        [_captureSession addInput:_captureDeviceInput];
        [_captureSession addInput:audioCaptureDeviceInput];
        AVCaptureConnection *captureConnection=[_captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        if ([captureConnection isVideoStabilizationSupported ]) {
            captureConnection.preferredVideoStabilizationMode=AVCaptureVideoStabilizationModeAuto;
        }
    }
    
    if ([_captureSession canAddOutput:_captureMovieFileOutput]) {
        [_captureSession addOutput:_captureMovieFileOutput];
    }
    
    _captureVideoPreviewLayer=[[AVCaptureVideoPreviewLayer alloc]initWithSession:self.captureSession];
    
    CALayer *layer= self.viewContainer.layer;
    layer.masksToBounds=YES;
    
    _captureVideoPreviewLayer.frame=  CGRectMake(0, 0, preLayerWidth, preLayerHeight);
    _captureVideoPreviewLayer.videoGravity=AVLayerVideoGravityResizeAspectFill;
    [layer insertSublayer:_captureVideoPreviewLayer below:nil];
    [self addGenstureRecognizer];
    
}

-(void)addGenstureRecognizer{
    UITapGestureRecognizer *tapGesture=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapScreen:)];
    [self.viewContainer addGestureRecognizer:tapGesture];
}

-(void)tapScreen:(UITapGestureRecognizer *)tapGesture{
    CGPoint point= [tapGesture locationInView:self.viewContainer];
    
    CGPoint cameraPoint= [self.captureVideoPreviewLayer captureDevicePointOfInterestForPoint:point];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposureMode:AVCaptureExposureModeAutoExpose atPoint:cameraPoint];
}

-(void)focusWithMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode atPoint:(CGPoint)point{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:AVCaptureFocusModeAutoFocus];
        }
        if ([captureDevice isFocusPointOfInterestSupported]) {
            [captureDevice setFocusPointOfInterest:point];
        }
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:AVCaptureExposureModeAutoExpose];
        }
        if ([captureDevice isExposurePointOfInterestSupported]) {
            [captureDevice setExposurePointOfInterest:point];
        }
    }];
}

-(void)changeDeviceProperty:(PropertyChangeBlock)propertyChange{
    AVCaptureDevice *captureDevice= [self.captureDeviceInput device];
    NSError *error;
    if ([captureDevice lockForConfiguration:&error]) {
        propertyChange(captureDevice);
        [captureDevice unlockForConfiguration];
    }else{
        NSLog(@"设置设备属性过程发生错误，错误信息：%@",error.localizedDescription);
    }
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self.captureSession startRunning];
}

-(void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    [self.captureSession stopRunning];
    
  
    
}

-(AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition )position{
    NSArray *cameras= [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if ([camera position]==position) {
            return camera;
        }
    }
    return nil;
}

- (NSString *)getVideoSaveFilePathString
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [paths objectAtIndex:0];
    
    path = [path stringByAppendingPathComponent:VIDEO_FOLDER];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMddHHmmss";
    NSString *nowTimeStr = [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceNow:0]];
    
    NSString *fileName = [[path stringByAppendingPathComponent:nowTimeStr] stringByAppendingString:@".mov"];
    
    return fileName;
}

-(NSString *)getVideoExportFilePathString {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [paths objectAtIndex:0];
    
    path = [path stringByAppendingPathComponent:VIDEO_FOLDER];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMddHHmmss";
    NSString *nowTimeStr = [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceNow:0]];
    
    NSString *fileName = [[path stringByAppendingPathComponent:nowTimeStr] stringByAppendingString:@".mp4"];
    
    return fileName;

}


- (void)createVideoFolderIfNotExist
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [paths objectAtIndex:0];
    
    NSString *folderPath = [path stringByAppendingPathComponent:VIDEO_FOLDER];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir = NO;
    BOOL isDirExist = [fileManager fileExistsAtPath:folderPath isDirectory:&isDir];
    
    if(!(isDirExist && isDir))
    {
        BOOL bCreateDir = [fileManager createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:nil];
        if(!bCreateDir){
            NSLog(@"创建保存视频文件夹失败");
        }
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)startTimer{
    currentTime = -1;
    countTimer = [NSTimer scheduledTimerWithTimeInterval:TIMER_INTERVAL target:self selector:@selector(onTimer:) userInfo:nil repeats:YES];
    [countTimer fire];
    [UIView animateWithDuration:0.5 animations:^{bottomView.alpha = 0.0;}];
}

-(void)stopTimer{
    [countTimer invalidate];
    countTimer = nil;
    timeLabel.text = @"00:00:00";
    [UIView animateWithDuration:0.5 animations:^{bottomView.alpha = 0.3;}];
}
- (void)onTimer:(NSTimer *)timer
{
    currentTime += TIMER_INTERVAL;
    NSString* seconds = toFixedString(currentTime % 60);
    NSString* minutes = toFixedString((currentTime/60)%60);
    NSString* hours = toFixedString(currentTime/3600);
    timeLabel.text = [NSString stringWithFormat:@"%@:%@:%@", hours, minutes, seconds];
}


-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections{
    NSLog(@"开始录制...");
    [self startTimer];
}
-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error{
    NSURL* exportFileURL = [NSURL fileURLWithPath:[self getVideoExportFilePathString]];
    [self editVideo:outputFileURL export:exportFileURL];
}


-(void)editVideo:(NSURL*)sourceURL export:(NSURL*)exportURL {
    AVAsset *asset = [[AVURLAsset alloc] initWithURL:sourceURL options:nil];
    AVAssetTrack *assetVideoTrack = [asset tracksWithMediaType:AVMediaTypeVideo][0];
    AVAssetTrack *assetAudioTrack =  [asset tracksWithMediaType:AVMediaTypeAudio][0];
    
    AVMutableComposition* mutableComposition = [AVMutableComposition composition];
    NSError *error = nil;
    AVMutableCompositionTrack *compositionVideoTrack = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *compositionAudioTrack = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    
    // 从视频中截取出“10-15秒”的片段，然后将这段内容从第10秒开始插入3次(鬼畜循环效果)
    CMTime position5 = CMTimeMakeWithSeconds(5, 1);
    CMTime position10 = CMTimeMakeWithSeconds(10, 1);
    [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, [asset duration]) ofTrack:assetVideoTrack atTime:kCMTimeZero error:&error];
    [compositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, [asset duration]) ofTrack:assetAudioTrack atTime:kCMTimeZero error:&error];
    for(int i=1;i<3;i++){
        CMTime pos = CMTimeMakeWithSeconds(i*5+10, 1);
        [compositionVideoTrack insertTimeRange:CMTimeRangeMake(position10,position5) ofTrack:assetVideoTrack atTime:pos error:&error];
         [compositionAudioTrack insertTimeRange:CMTimeRangeMake(position10,position5) ofTrack:assetAudioTrack atTime:pos error:&error];
    }
    
    
    // 在视频的第10秒位置，插入附件中的背景音乐
    NSString *audioURL = [[NSBundle mainBundle] pathForResource:@"bg" ofType:@"wav"];
    AVAsset *audioAsset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:audioURL] options:nil];
    AVAssetTrack *newAudioTrack = [audioAsset tracksWithMediaType:AVMediaTypeAudio][0];
    AVMutableCompositionTrack *customAudioTrack = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    [customAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, [audioAsset duration]) ofTrack:newAudioTrack atTime:position10 error:&error];
    
 
    
    AVAssetExportSession* exportSession = [[AVAssetExportSession alloc] initWithAsset:[mutableComposition copy] presetName:AVAssetExportPresetMediumQuality];
    
    CGAffineTransform t = assetVideoTrack.preferredTransform;
    AVMutableVideoComposition* mutableVideoComposition = [AVMutableVideoComposition videoComposition];
    mutableVideoComposition.renderSize = CGSizeMake(assetVideoTrack.naturalSize.height,assetVideoTrack.naturalSize.width);
    mutableVideoComposition.frameDuration = CMTimeMake(1, 30);
    
    
    AVMutableVideoCompositionInstruction* instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    instruction.timeRange = CMTimeRangeMake(kCMTimeZero, [mutableComposition duration]);
    AVMutableVideoCompositionLayerInstruction* layerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:(mutableComposition.tracks)[0]];
    [layerInstruction setTransform:t atTime:kCMTimeZero];
    instruction.layerInstructions = @[layerInstruction];
    mutableVideoComposition.instructions = @[instruction];
    
    
    // 在视频的第3秒位置，插入附件中的gif动图
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath: @"contents"];
    
    animation.calculationMode = kCAAnimationDiscrete;
    animation.duration = 7.0;
    animation.repeatCount = 1;
    animation.beginTime = 3;
    animation.values = animationImages; // NSArray of CGImageRefs
    
    
    CGSize size = assetVideoTrack.naturalSize;
    CALayer *animationLayer = [CALayer layer];
    animationLayer.frame = CGRectMake(0, 0, 550, 400);
    [animationLayer setMasksToBounds:YES];
    [animationLayer addAnimation: animation forKey: @"contents"];
    
    CALayer *parentLayer = [CALayer layer];
    CALayer *videoLayer = [CALayer layer];
    
    parentLayer.frame = CGRectMake(0, 0, size.height, size.width);
    videoLayer.frame = CGRectMake(0, 0, size.height, size.width);
    [parentLayer addSublayer:videoLayer];
    [parentLayer addSublayer:animationLayer];
    
    
    
    mutableVideoComposition.animationTool = [AVVideoCompositionCoreAnimationTool
                                 videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];
    
    
    
    exportSession.videoComposition = mutableVideoComposition;
    exportSession.outputURL = exportURL;
    exportSession.outputFileType=AVFileTypeMPEG4;
    
    
    [exportSession exportAsynchronouslyWithCompletionHandler:^(void){
        switch (exportSession.status) {
            case AVAssetExportSessionStatusCompleted:
                [self saveToPhtotLibrary:exportURL];
                break;
            case AVAssetExportSessionStatusFailed:
                NSLog(@"Failed:%@",exportSession.error);
                break;
            case AVAssetExportSessionStatusCancelled:
                NSLog(@"Canceled:%@",exportSession.error);
                break;
            default:
                break;
        }
        NSFileManager* fileManager=[NSFileManager defaultManager];
        [fileManager removeItemAtURL:sourceURL error:nil];
    }];

}


-(void)saveToPhtotLibrary:(NSURL*)outputFileURL {
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library writeVideoAtPathToSavedPhotosAlbum:outputFileURL
                                completionBlock:^(NSURL *assetURL, NSError *error) {
                                    if (error) {
                                        NSLog(@"Save video fail:%@",error);
                                    } else {
                                        NSLog(@"Save video succeed.");
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"" message:@"Save video succeed!" delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK",nil];
                                            [alert show];
                                            
                                        });
                                    }
                                    NSFileManager* fileManager=[NSFileManager defaultManager];
                                    [fileManager removeItemAtURL:outputFileURL error:nil];
                                }];

}

@end
