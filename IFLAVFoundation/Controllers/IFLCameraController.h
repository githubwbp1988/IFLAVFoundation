//
//  IFLCameraController.h
//  IFLAVFoundation
//
//  Created by erlich wang on 2022/7/8.
//

#import "IFLBaseCameraController.h"

NS_ASSUME_NONNULL_BEGIN

@protocol IFLFaceDetectionDelegate <NSObject>

- (void)didDetectFaces:(NSArray *)faces;

@end

@interface IFLCameraController : IFLBaseCameraController

@property(nonatomic, weak) id<IFLFaceDetectionDelegate> faceDetectionDelegate;

@end

NS_ASSUME_NONNULL_END
