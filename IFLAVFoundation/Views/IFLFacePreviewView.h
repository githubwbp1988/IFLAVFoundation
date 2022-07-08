//
//  IFLFacePreviewView.h
//  IFLAVFoundation
//
//  Created by erlich wang on 2022/7/8.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface IFLFacePreviewView : UIView

@property(nonatomic, strong)AVCaptureSession *session;

@end

NS_ASSUME_NONNULL_END
