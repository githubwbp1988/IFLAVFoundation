//
//  IFLBaseCameraController.m
//  IFLAVFoundation
//
//  Created by erlich wang on 2022/7/6.
//

#import <UIKit/UIKit.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "IFLBaseCameraController.h"
#import "NSFileManager+IFLCat.h"

NSString *const IFLCameraErrorDomain = @"com.ifl.IFLCameraErrorDomain";
NSString *const IFLThumbnailCreatedNotification = @"IFLThumbnailCreated";

@interface IFLBaseCameraController () <AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate>

//@property(nonatomic, strong)AVCapturePhotoOutput *imageOutput;
@property(nonatomic, strong)AVCaptureStillImageOutput *imageOutput;
@property(nonatomic, strong)AVCaptureMovieFileOutput *movieOutput;

@property(nonatomic, readonly)BOOL cameraHasTorch;                      // 手电筒
@property(nonatomic, readonly)BOOL cameraHasFlash;                      // 闪光灯
@property(nonatomic, readonly)BOOL cameraSupportsTapToFocus;            // 聚焦
@property(nonatomic, readonly)BOOL cameraSupportsTapToExpose;           // 曝光
@property(nonatomic)AVCaptureTorchMode torchMode;                       // 手电筒模式
@property(nonatomic)AVCaptureFlashMode flashMode;                       // 闪光灯模式

@property(nonatomic, strong) NSURL *outputURL;

@property(nonatomic, strong)dispatch_queue_t videoQueue;

@end

@implementation IFLBaseCameraController

#pragma mark - AVCapturePhotoCaptureDelegate
- (void)captureOutput:(AVCapturePhotoOutput *)output didCapturePhotoForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings {
    NSLog(@"%s", __func__);
}
- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(NSError *)error {
    NSLog(@"%s", __func__);
    
//    NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:sampleBufferRef];
//    UIImage *image = [[UIImage alloc] initWithData:imageData];
    
    CIImage *ciImage = [CIImage imageWithCVImageBuffer:photo.pixelBuffer];
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef cgImage = [context createCGImage:ciImage fromRect:CGRectMake(0, 0, 400, 400)];
    
    UIImage *image = [[UIImage alloc] initWithCGImage:cgImage scale:1.0f orientation:[self currentImageOrientation]];

    // 捕捉图片成功后， 将图片传送出去
    [self writeImageToAssetsLibrary:image];
}

#pragma mark - AVCaptureFileOutputRecordingDelegate
- (void)captureOutput:(AVCaptureFileOutput *)output didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray<AVCaptureConnection *> *)connections error:(NSError *)error {
    if (error) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(mediaCaptureFailedWithError:)]) {
            [self.delegate mediaCaptureFailedWithError:error];
        }
    } else {
        [self writeVideoToAssetsLibrary:[self.outputURL copy]];
    }
    
    self.outputURL = nil;
}


- (BOOL)setupSession:(NSError **)error {
    
    // 创建捕捉会话
    self.captureSession = [[AVCaptureSession alloc] init];
    
    // 设置图像分辨率
    self.captureSession.sessionPreset = AVCaptureSessionPresetHigh;
    
    // 默认视频捕捉设备 iOS系统返回后置摄像头
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    // videoInput
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:error];
     
    // 判断videoInput有效
    if (!videoInput) {
        return NO;
    }
    
    // 能否被添加进会话
    if (![self.captureSession canAddInput:videoInput]) {
        return NO;
    }
    [self.captureSession addInput:videoInput];
    self.activeVideoInput = videoInput;
    
    // 默认音频捕捉设备 返回一个内置麦克风
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    
    // audioInput
    AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:error];
    
    // 判断audioInput 有效
    if (!audioInput) {
        return NO;
    }
    
    if (![self.captureSession canAddInput:audioInput]) {
        return NO;
    }
    [self.captureSession addInput:audioInput];
    
//    self.imageOutput = [[AVCapturePhotoOutput alloc] init];
    
//    // 字典：JPEG格式
//    [self.imageOutput capturePhotoWithSettings:[AVCapturePhotoSettings photoSettingsWithFormat:@{AVVideoCodecKey:AVVideoCodecJPEG}] delegate:self];
    
    // AVCaptureStillImageOutput 实例 从摄像头捕捉静态图片
    self.imageOutput = [[AVCaptureStillImageOutput alloc] init];
    
    // 配置字典：希望捕捉到JPEG格式的图片
    self.imageOutput.outputSettings = @{AVVideoCodecKey:AVVideoCodecJPEG};
    
    // 输出连接
    if ([self.captureSession canAddOutput:self.imageOutput]) {
        [self.captureSession addOutput:self.imageOutput];
    }
    
    // 创建AVCaptureMovieFileOutput实例 用于Quick Time 电影录制到文件系统
    self.movieOutput = [[AVCaptureMovieFileOutput alloc] init];
    
    if ([self.captureSession canAddOutput:self.movieOutput]) {
        [self.captureSession addOutput:self.movieOutput];
    }
    
    self.videoQueue = dispatch_queue_create("com.iflamer.videoqueue", NULL);
    
    return YES;
}

- (void)startSession {
    if (!self.captureSession) {
        return;
    }
    if ([self.captureSession isRunning]) {
        return;
    }
    if (!self.videoQueue) {
        return;
    }
    dispatch_async(self.videoQueue, ^{
        [self.captureSession startRunning];
    });
}

- (void)stopSession {
    if (!self.captureSession) {
        return;
    }
    if (![self.captureSession isRunning]) {
        return;
    }
    if (!self.videoQueue) {
        return;
    }
    dispatch_async(self.videoQueue, ^{
        [self.captureSession stopRunning];
    });
}

- (BOOL)setupSessionInputs:(NSError **)error {
    // Set up default camera device
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:error];
    if (videoInput) {
        if ([self.captureSession canAddInput:videoInput]) {
            [self.captureSession addInput:videoInput];
            self.activeVideoInput = videoInput;
        } else {
            NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"Failed to add video input."};
            *error = [NSError errorWithDomain:IFLCameraErrorDomain
                                         code:IFLCameraErrorFailedToAddInput
                                     userInfo:userInfo];
            return NO;
        }
    } else {
        return NO;
    }

    return YES;
}

- (BOOL)setupSessionOutputs:(NSError **)error {
    // Setup the still image output
    self.imageOutput = [[AVCaptureStillImageOutput alloc] init];
    // self.imageOutput.outputSettings = @{AVVideoCodecKey : AVVideoCodecJPEG};

    if ([self.captureSession canAddOutput:self.imageOutput]) {
        [self.captureSession addOutput:self.imageOutput];
    } else {
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"Failed to still image output."};
        *error = [NSError errorWithDomain:IFLCameraErrorDomain
                                     code:IFLCameraErrorFailedToAddOutput
                                 userInfo:userInfo];
        return NO;
    }
    return YES;
}

- (NSString *)sessionPreset {
    return AVCaptureSessionPresetHigh;
}

#pragma mark - Device Configuration   配置摄像头支持的方法
// 配置摄像头
- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position {
    // 获取可用视频设备
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    // 遍历
    for (AVCaptureDevice *device in devices) {
        if (device.position == position) {
            return device;
        }
    }
    return nil;
}

- (AVCaptureDevice *)activeCamera {
    // 返回当前捕捉会话对应到摄像头的device
    return self.activeVideoInput.device;
}

// 返回未激活的摄像头
- (AVCaptureDevice *)inactiveCamera {
    // 通过查找当前激活摄像头的 反向摄像头获得，如果设备只有一个摄像头，则返回nil
    if ([self cameraCount] <= 1) {
        return nil;
    }
    if ([self activeCamera].position == AVCaptureDevicePositionBack) {
        return [self cameraWithPosition:AVCaptureDevicePositionFront];
    }
    return [self cameraWithPosition:AVCaptureDevicePositionBack];
}

// 判断是否有超过1个摄像头可用
- (BOOL)canSwitchCamera {
    return [self cameraCount] > 1;
}

// 可用视频捕捉设备的数量
- (NSUInteger)cameraCount {
    return [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count];
}

// 切换摄像头
- (BOOL)switchCamera {
    // 判断多少个摄像头
    if (![self canSwitchCamera]) {
        return NO;
    }
    
    // 获取反向设备
    AVCaptureDevice *oppositeVideoDevice = [self inactiveCamera];
    if (!oppositeVideoDevice) {
        return NO;
    }
    
    // 封装input
    NSError *error;
    AVCaptureDeviceInput *oppositeVideoInput = [AVCaptureDeviceInput deviceInputWithDevice:oppositeVideoDevice error:&error];
    
    if (!oppositeVideoInput) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(deviceConfigurationFailedWithError:)]) {
            [self.delegate deviceConfigurationFailedWithError:error];
        }
        return NO;
    }
    
    // 标注原配置变化开始
    [self.captureSession beginConfiguration];
    
    // 捕捉会话中，原本的捕捉输入设备移除
    [self.captureSession removeInput:self.activeVideoInput];
    
    // 新的input
    if (![self.captureSession canAddInput:oppositeVideoInput]) {
        // 无法加入 则将原本的视频捕捉设备重新加入到捕捉会话中
        [self.captureSession addInput:self.activeVideoInput];
    } else {
        [self.captureSession addInput:oppositeVideoInput];
        
        // 更新videoInput
        self.activeVideoInput = oppositeVideoInput;
    }
    
    // 配置完成后，commit configuration
    [self.captureSession commitConfiguration];
    
    return YES;
}

#pragma mark - 聚焦 曝光

- (BOOL)cameraSupportsTapToFocus {
    // 询问激活中的摄像头是否支持兴趣点对焦
    return [[self activeCamera] isFocusPointOfInterestSupported];
}

- (BOOL)cameraSupportsTapToExpose {
    // 询问设备是否支持对一个兴趣点进行曝光
    return [[self activeCamera] isExposurePointOfInterestSupported];
}

// 聚焦、曝光、重设聚焦、曝光的方法
- (void)focusAtPoint:(CGPoint)point {
    AVCaptureDevice *device = [self activeCamera];
    
    // 是否支持兴趣点对焦 是否自动对焦
    if (device.isFocusPointOfInterestSupported && [device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        NSError *error;
        // 锁定设备准备配置
        if ([device lockForConfiguration:&error]) {
            device.focusPointOfInterest = point;
            device.focusMode = AVCaptureFocusModeAutoFocus;
            
            // 释放锁定
            [device unlockForConfiguration];
        } else {
            [self.delegate deviceConfigurationFailedWithError:error];
        }
    }
}

static const NSString *IFLCameraAdjustingExposureContext;

- (void)exposeAtPoint:(CGPoint)point {
    AVCaptureDevice *device = [self activeCamera];
    AVCaptureExposureMode exposureMode = AVCaptureExposureModeContinuousAutoExposure;
    
    // 判断是否支持 AVCaptureExposureModeContinuousAutoExposure
    if (!(device.isExposurePointOfInterestSupported && [device isExposureModeSupported:exposureMode])) {
        return;
    }
    
    NSError *error;
    // 锁定设备配置
    if ([device lockForConfiguration:&error]) {
        // 配置期望值
        device.exposurePointOfInterest = point;
        device.exposureMode = exposureMode;
        
        // 判断设备是否支持锁定曝光模式
        if ([device isExposureModeSupported:AVCaptureExposureModeLocked]) {
            // 使用kvo确定设备的adjustingExposure属性的状态
            [device addObserver:self forKeyPath:@"adjustingExposure" options:NSKeyValueObservingOptionNew context:&IFLCameraAdjustingExposureContext];
        }
        
        //
        [device unlockForConfiguration];
        return;
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(deviceConfigurationFailedWithError:)]) {
        [self.delegate deviceConfigurationFailedWithError:error];
    }
}
- (void)resetFocusAndExposureModes {
    AVCaptureDevice *device = [self activeCamera];
    
    AVCaptureFocusMode focusMode = AVCaptureFocusModeContinuousAutoFocus;
    
    // 获取对焦兴趣点 连续自动对焦模式 是否被支持
    BOOL canResetFocus = device.isFocusPointOfInterestSupported && [device isFocusModeSupported:focusMode];
        
    //
    AVCaptureExposureMode exposureMode = AVCaptureExposureModeContinuousAutoExposure;
    
    BOOL canResetExposure = device.isExposurePointOfInterestSupported && [device isExposureModeSupported:exposureMode];
    
    // 捕捉设备空间左上角（0，0），右下角（1，1） 中心点则（0.5，0.5）
    CGPoint centerPoint = CGPointMake(0.5f, 0.5f);
    
    NSError *error;
    
    // 锁定设备 准备配置
    if ([device lockForConfiguration:&error]) {
        if (canResetFocus) {
            device.focusMode = focusMode;
            device.focusPointOfInterest = centerPoint;
        }
        
        if (canResetExposure) {
            device.exposureMode = exposureMode;
            device.exposurePointOfInterest = centerPoint;
        }
        
        [device unlockForConfiguration];
    } else {
        if (self.delegate && [self.delegate respondsToSelector:@selector(deviceConfigurationFailedWithError:)]) {
            [self.delegate deviceConfigurationFailedWithError:error];
        }
    }
}

#pragma mark - Image Capture Methods 拍摄静态图片
// 捕捉静态图片 & 视频的功能
// 捕捉静态图片
- (void)captureStillImage {
    // 获取连接
    AVCaptureConnection *connection = [self.imageOutput connectionWithMediaType:AVMediaTypeVideo];

    // 程序只支持纵向，但是如果用户横向拍照时，需要调整结果照片的方向
    // 判断是否支持设置视频方向
    if (connection.isVideoOrientationSupported) {
        // 获取方向
        connection.videoOrientation = [self currentVideoOrientation];
    }

    // 定义一个handler 返回 图片NSData数据
    id handler = ^(CMSampleBufferRef sampleBufferRef, NSError *error) {
        if (sampleBufferRef != NULL) {
            NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:sampleBufferRef];
            UIImage *image = [[UIImage alloc] initWithData:imageData];

            // 捕捉图片成功后， 将图片传送出去
            [self writeImageToAssetsLibrary:image];
        }
    };

    // 捕捉静态图片
    [self.imageOutput captureStillImageAsynchronouslyFromConnection:connection completionHandler:handler];
    
//    [self.imageOutput capturePhotoWithSettings:[AVCapturePhotoSettings photoSettingsWithFormat:@{AVVideoCodecKey:AVVideoCodecJPEG}] delegate:self];
}

#pragma mark - Video Capture Methods 捕捉视频

// 视频录制
// 开始录制
- (void)startRecording {
    if (![self isRecording]) {
        // 获取当前视频捕捉连接信息，用于捕捉视频数据配置一些核心属性
        AVCaptureConnection *videoConnection = [self.movieOutput connectionWithMediaType:AVMediaTypeVideo];
        
        // 判断是否支持设置videoOrientation 属性。
        if (videoConnection.isVideoOrientationSupported) {
            videoConnection.videoOrientation = [self currentVideoOrientation];
        }
        
        // 判断是否支持视频稳定 可以显著提高视频的质量。只会在录制视频文件涉及
        if ([videoConnection isVideoStabilizationSupported]) {
            videoConnection.enablesVideoStabilizationWhenAvailable = YES;
        }
        
        AVCaptureDevice *device = [self activeCamera];
        
        // 摄像头可以进行平滑对焦模式操作。即减慢摄像头镜头对焦速度。当用户移动拍摄时摄像头会尝试快速自动对焦。
        if (device.isSmoothAutoFocusEnabled) {
            NSError *error;
            if ([device lockForConfiguration:&error]) {
                device.smoothAutoFocusEnabled = YES;
                [device unlockForConfiguration];
            } else {
                [self.delegate deviceConfigurationFailedWithError:error];
            }
        }
        
        // 查找写入捕捉视频的唯一文件系统URL.
        self.outputURL = [self uniqueURL];
        
        // 在捕捉输出上调用方法 参数1:录制保存路径  参数2:代理
        [self.movieOutput startRecordingToOutputFileURL:self.outputURL recordingDelegate:self];
    }
}

// 停止录制
- (void)stopRecording {
    // 是否正在录制
    if ([self isRecording]) {
        [self.movieOutput stopRecording];
    }
}

// 获取录制状态
- (BOOL)isRecording {
    return self.movieOutput.isRecording;
}

// 录制时间
- (CMTime)recordedDuration {

    return self.movieOutput.recordedDuration;
}

#pragma mark - 闪光灯 手电筒

// 判断是否有闪光灯
- (BOOL)cameraHasFlash {
    return [[self activeCamera] hasFlash];
}

// 闪光灯模式
- (AVCaptureFlashMode)flashMode {
    return [[self activeCamera] flashMode];
}

// 设置闪光灯
- (void)setFlashMode:(AVCaptureFlashMode)flashMode {

    // 获取会话
    AVCaptureDevice *device = [self activeCamera];
    
    // 判断是否支持闪光灯模式
    if ([device isFlashModeSupported:flashMode]) {
    
        // 如果支持，则锁定设备
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            // 修改闪光灯模式
            device.flashMode = flashMode;
            // 修改完成，解锁释放设备
            [device unlockForConfiguration];
        } else {
            if (self.delegate && [self.delegate respondsToSelector:@selector(deviceConfigurationFailedWithError:)]) {
                [self.delegate deviceConfigurationFailedWithError:error];
            }
        }
        
    }

}

// 是否支持手电筒
- (BOOL)cameraHasTorch {
    return [[self activeCamera] hasTorch];
}

// 手电筒模式
- (AVCaptureTorchMode)torchMode {

    return [[self activeCamera] torchMode];
}


// 设置是否打开手电筒
- (void)setTorchMode:(AVCaptureTorchMode)torchMode {

    AVCaptureDevice *device = [self activeCamera];
    
    if ([device isTorchModeSupported:torchMode]) {
        
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            device.torchMode = torchMode;
            [device unlockForConfiguration];
        } else {
            if (self.delegate && [self.delegate respondsToSelector:@selector(deviceConfigurationFailedWithError:)]) {
                [self.delegate deviceConfigurationFailedWithError:error];
            }
        }

    }
    
}


// 获取方向值
- (AVCaptureVideoOrientation)currentVideoOrientation {
    
    AVCaptureVideoOrientation orientation;
    
    // 获取UIDevice 的 orientation
    switch ([UIDevice currentDevice].orientation) {
        case UIDeviceOrientationPortrait:
            orientation = AVCaptureVideoOrientationPortrait;
            break;
        case UIDeviceOrientationLandscapeRight:
            orientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            orientation = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        default:
            orientation = AVCaptureVideoOrientationLandscapeRight;
            break;
    }
    
    return orientation;

    return 0;
}

// 获取方向值
- (UIImageOrientation)currentImageOrientation {
    
    UIImageOrientation orientation;
    
    // 获取UIDevice 的 orientation
    switch ([UIDevice currentDevice].orientation) {
        case UIDeviceOrientationPortrait:
            orientation = UIImageOrientationUp;
            break;
        case UIDeviceOrientationLandscapeRight:
            orientation = UIImageOrientationLeft;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            orientation = UIImageOrientationUp;
            break;
        default:
            orientation = UIImageOrientationRight;
            break;
    }
    
    return orientation;

    return 0;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (context != &IFLCameraAdjustingExposureContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    
    // 获取device
    AVCaptureDevice *device = (AVCaptureDevice *)object;
    
    // 判断设备是否不再调整曝光等级，确认设备的exposureMode是否可以设置为AVCaptureExposureModeLocked
    if (!device.isAdjustingExposure && [device isExposureModeSupported:AVCaptureExposureModeLocked]) {
        // 移除 adjustingExposure 观察者 self，不再接收后续变更通知
        [object removeObserver:self forKeyPath:@"adjustingExposure" context:&IFLCameraAdjustingExposureContext];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error;
            if ([device lockForConfiguration:&error]) {
                device.exposureMode = AVCaptureExposureModeLocked;
                
                [device unlockForConfiguration];
            } else {
                if (self.delegate && [self.delegate respondsToSelector:@selector(deviceConfigurationFailedWithError:)]) {
                    [self.delegate deviceConfigurationFailedWithError:error];
                }
            }
        });
    }
}

/*
    Assets Library 框架
    用来让开发者通过代码方式访问iOS photo
    注意：会访问到相册，需要修改plist 权限。否则会导致项目崩溃
 */

- (void)writeImageToAssetsLibrary:(UIImage *)image {

    // 创建ALAssetsLibrary  实例
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    
    // 参数1:图片（参数为CGImageRef 所以image.CGImage）
    // 参数2:方向参数 转为NSUInteger
    // 参数3:写入成功、失败处理
    [library writeImageToSavedPhotosAlbum:image.CGImage
                              orientation:(NSUInteger)image.imageOrientation
                          completionBlock:^(NSURL *assetURL, NSError *error) {
        // 成功后，发送捕捉图片通知。用于绘制程序的左下角的缩略图
        if (!error) {
            [self postThumbnailNotifification:image];
        } else {
            // 失败打印错误信息
            id message = [error localizedDescription];
            NSLog(@">>>>%@>>>>", message);
        }
    }];
}

// 写入捕捉到的视频
- (void)writeVideoToAssetsLibrary:(NSURL *)videoURL {
    // ALAssetsLibrary 实例 提供写入视频的接口
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc]init];
    
    // 写资源库写入前，检查视频是否可被写入 
    if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:videoURL]) {
        // 创建block块
        ALAssetsLibraryWriteVideoCompletionBlock completionBlock;
        completionBlock = ^(NSURL *assetURL,NSError *error) {
            if (error) {
                if (self.delegate && [self.delegate respondsToSelector:@selector(assetLibraryWriteFailedWithError:)]) {
                    [self.delegate assetLibraryWriteFailedWithError:error];
                }
            } else {
                // 用于界面展示视频缩略图
                [self generateThumbnailForVideoAtURL:videoURL];
            }
            
        };
        
        // 执行实际写入资源库的动作
        [library writeVideoAtPathToSavedPhotosAlbum:videoURL completionBlock:completionBlock];
    }
}

// 发送缩略图通知
- (void)postThumbnailNotifification:(UIImage *)image {
    
    // 回到主队列
    dispatch_async(dispatch_get_main_queue(), ^{
        //发送请求
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc postNotificationName:@"IFLThumbnailCreated" object:image];
    });
}

// 写入视频唯一文件系统URL
- (NSURL *)uniqueURL {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    // temporaryDirectoryWithTemplateString  可以将文件写入的目的创建一个唯一命名的目录；
    NSString *dirPath = [fileManager temporaryDirectoryWithTemplateString:@"iflcamera.XXXXXX"];
    
    if (dirPath) {
        NSString *filePath = [dirPath stringByAppendingPathComponent:@"iflcamera_movie.mov"];
        return  [NSURL fileURLWithPath:filePath];
    }
    
    return nil;
    
}

// 获取视频左下角缩略图
- (void)generateThumbnailForVideoAtURL:(NSURL *)videoURL {

    // 在videoQueue 上，
    dispatch_async(self.videoQueue, ^{
        // 建立新的AVAsset & AVAssetImageGenerator
        AVAsset *asset = [AVAsset assetWithURL:videoURL];
        
        AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
        
        // 设置maximumSize 宽为100，高为0 根据视频的宽高比来计算图片的高度
        imageGenerator.maximumSize = CGSizeMake(100.0f, 0.0f);
        
        // 捕捉视频缩略图会考虑视频的变化（如视频的方向变化），如果不设置，缩略图的方向可能出错
        imageGenerator.appliesPreferredTrackTransform = YES;
        
        // 获取CGImageRef图片 注意需要自己管理它的创建和释放
        CGImageRef imageRef = [imageGenerator copyCGImageAtTime:kCMTimeZero actualTime:NULL error:nil];
        
        // 将图片转化为UIImage
        UIImage *image = [UIImage imageWithCGImage:imageRef];
        
        // 释放CGImageRef imageRef 防止内存泄漏
        CGImageRelease(imageRef);
        
        // 回到主线程
        dispatch_async(dispatch_get_main_queue(), ^{
            // 发送通知，传递最新的image
            [self postThumbnailNotifification:image];
            
        });
        
    });
    
}

@end
