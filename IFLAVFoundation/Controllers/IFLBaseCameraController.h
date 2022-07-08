//
//  IFLCameraController.h
//  IFLAVFoundation
//
//  Created by erlich wang on 2022/7/6.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const IFLCameraErrorDomain;
FOUNDATION_EXPORT NSString *const IFLThumbnailCreatedNotification;

@protocol IFLCameraControllerDelegate <NSObject>

// 发生错误事件是，需要在对象委托上调用一些方法来处理
- (void)deviceConfigurationFailedWithError:(NSError *)error;
- (void)mediaCaptureFailedWithError:(NSError *)error;
- (void)assetLibraryWriteFailedWithError:(NSError *)error;

@end

typedef NS_ENUM(NSInteger, IFLCameraErrorCode) {
    IFLCameraErrorFailedToAddInput = 98,
    IFLCameraErrorFailedToAddOutput,
};

@interface IFLBaseCameraController : NSObject

@property(nonatomic, weak)id<IFLCameraControllerDelegate> delegate;

@property(nonatomic, strong)AVCaptureSession *captureSession;           // 捕捉会话
@property(nonatomic, strong)AVCaptureDeviceInput *activeVideoInput;     //

@property(nonatomic, readonly)NSUInteger cameraCount;
@property(nonatomic, readonly)AVCaptureDevice *activeCamera;

- (BOOL)setupSession:(NSError **)error;
- (void)startSession;
- (void)stopSession;

// Override Hooks
- (BOOL)setupSessionInputs:(NSError **)error;
- (BOOL)setupSessionOutputs:(NSError **)error;
- (NSString *)sessionPreset;

- (BOOL)switchCamera;
- (BOOL)canSwitchCamera;

// 聚焦、曝光、重设聚焦、曝光的方法
- (void)focusAtPoint:(CGPoint)point;
- (void)exposeAtPoint:(CGPoint)point;
- (void)resetFocusAndExposureModes;

// 捕捉静态图片 & 视频的功能
// 捕捉静态图片
- (void)captureStillImage;

// 视频录制
// 开始录制
- (void)startRecording;

// 停止录制
- (void)stopRecording;

// 获取录制状态
- (BOOL)isRecording;

// 录制时间
- (CMTime)recordedDuration;

@end

NS_ASSUME_NONNULL_END
