//
//  IFLPreviewView.h
//  IFLAVFoundation
//
//  Created by erlich wang on 2022/7/8.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol IFLPreviewViewDelegate <NSObject>

- (void)tappedToFocusAtPoint:(CGPoint)point;            // 聚焦
- (void)tappedToExposeAtPoint:(CGPoint)point;           // 曝光
- (void)tappedToResetFocusAndExposure;                  // 点击重置聚焦&曝光

@end

@interface IFLPreviewView : UIView

// session用来关联AVCaptureVideoPreviewLayer 和 激活AVCaptureSession
@property(nonatomic, strong)AVCaptureSession *session;
@property(nonatomic, weak)id<IFLPreviewViewDelegate> delegate;

@property(nonatomic)BOOL tapToFocusEnabled;                     // 是否聚焦
@property(nonatomic)BOOL tapToExposeEnabled;                    // 是否曝光

@end

NS_ASSUME_NONNULL_END
