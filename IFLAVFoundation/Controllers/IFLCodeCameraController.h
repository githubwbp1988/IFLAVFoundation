//
//  IFLCodeCameraController.h
//  IFLAVFoundation
//
//  Created by erlich wang on 2022/7/9.
//

#import "IFLBaseCameraController.h"

NS_ASSUME_NONNULL_BEGIN

@protocol IFLCodeDetectionDelegate <NSObject>

- (void)didDetectCodes:(NSArray *)codes;

@end

@interface IFLCodeCameraController : IFLBaseCameraController

@property (weak, nonatomic) id<IFLCodeDetectionDelegate> codeDetectionDelegate;

@end

NS_ASSUME_NONNULL_END
