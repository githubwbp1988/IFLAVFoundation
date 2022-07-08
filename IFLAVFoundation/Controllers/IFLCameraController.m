//
//  IFLCameraController.m
//  IFLAVFoundation
//
//  Created by erlich wang on 2022/7/8.
//

#import <UIKit/UIGeometry.h>
#import "IFLCameraController.h"

@interface IFLCameraController () <AVCaptureMetadataOutputObjectsDelegate>

@property(nonatomic, strong)AVCaptureMetadataOutput *metaDataOutput;

@end

@implementation IFLCameraController

- (BOOL)setupSessionOutputs:(NSError **)error {
    
    self.metaDataOutput = [[AVCaptureMetadataOutput alloc] init];
    
    if ([self.captureSession canAddOutput:self.metaDataOutput]) {
        [self.captureSession addOutput:self.metaDataOutput];
        
        // 输出数据 -> 人脸数据
        // 只识别人脸数据
        NSArray *metaDataObjectType = @[AVMetadataObjectTypeFace];
        self.metaDataOutput.metadataObjectTypes = metaDataObjectType;
        
        // 创建主队列 人脸检测使用硬件加速器，需要在主线程执行
        dispatch_queue_t mainQueue = dispatch_get_main_queue();
        
        
        // 设置metaDataOutput代理，检测视频中一帧数据里，是否包含人脸数据
        [self.metaDataOutput setMetadataObjectsDelegate:self queue:mainQueue];
        return YES;
    }
    return NO;
}

#pragma mark - AVCaptureMetadataOutputObjectsDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    
    // metadataObjects包含捕获到的人脸数据
    for (AVMetadataFaceObject *faceObject in metadataObjects) {
        // faceID 唯一  bounds
        NSLog(@"FaceID: %li, bounds: %@", faceObject.faceID, NSStringFromCGRect(faceObject.bounds));
    }
    
    // 获取视屏中人脸的个数 位置 处理人脸
    // metadata数据 发送到 预览图层 IFLPreviewView
    [self.faceDetectionDelegate didDetectFaces:metadataObjects];
}

@end
