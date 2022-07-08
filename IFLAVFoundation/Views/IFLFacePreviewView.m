//
//  IFLFacePreviewView.m
//  IFLAVFoundation
//
//  Created by erlich wang on 2022/7/8.
//

#import "IFLFacePreviewView.h"
#import "IFLFaceCameraController.h"

@interface IFLFacePreviewView () <IFLFaceDetectionDelegate>

@property(nonatomic, strong)CALayer *overlayLayer;

@property(nonatomic, strong)NSMutableDictionary *faceLayers;

@property(nonatomic, strong)AVCaptureVideoPreviewLayer *previewLayer;

@end

@implementation IFLFacePreviewView

static CGFloat IFLDegreesToRadians(CGFloat degrees) {
    return degrees * M_PI / 180;
}

static CATransform3D CATransform3DMakePerspective(CGFloat eyePosition) {
    
    // CATransform3D 图层的旋转，缩放，偏移，歪斜和应用的透
    // CATransform3DIdentity是单位矩阵，该矩阵没有缩放，旋转，歪斜，透视。该矩阵应用到图层上，就是设置默认值。
    CATransform3D transform = CATransform3DIdentity;
    
    // 透视效果（就是近大远小），是通过设置m34 m34 = -1.0 / D 默认是0.D越小透视效果越明显
    // D:eyePosition 观察者到投射面的距离  eyePosition 一般 （500 ～ 1000）
    transform.m34 = -1.0 / eyePosition;
    
    return transform;
    
}

#pragma mark - IFLFaceDetectionDelegate
- (void)didDetectFaces:(NSArray *)faces {
    // 摄像头坐标系 -> 屏幕坐标系
    NSArray *transformFaces = [self transformedFacesFromFaces:faces];
    
    // 如果人脸从摄像头消失了， 删除它的图层
    NSMutableArray *lostFaces = [self.faceLayers.allKeys mutableCopy];
    
    // 遍历所有的人脸数据
    for (AVMetadataFaceObject *face in transformFaces) {
        // faceID
        NSNumber *faceID = @(face.faceID);
        
        // faceID如果存在 人脸没有从摄像头移除，不需要删除
        // 应该先从删除列表中移除
        [lostFaces removeObject:faceID];
        
        // old face -> layer
        CALayer *layer = self.faceLayers[faceID];
        // 如果 layer 不存在，说明是个新的
        if (!layer) {
            layer = [self makeFaceLayer];
            [self.overlayLayer addSublayer:layer];
            
            self.faceLayers[faceID] = layer;
        }
        
        // 根据人脸的bounds 设置layer frame
        layer.frame = face.bounds;
        
        // 3D
        layer.transform = CATransform3DIdentity; // 矩阵
        
        // 人的头部 左右摇摆（注意不是摇头，像钟摆那样左右摆）
        if (face.hasRollAngle) {
            CATransform3D t = [self transformForRollAngle:face.rollAngle];
            
            // CATransform3DConcat 矩阵相乘
            layer.transform = CATransform3DConcat(layer.transform, t);
        }
        
        if (face.hasYawAngle) {
            CATransform3D t = [self transformForYawAngle:face.rollAngle];
            layer.transform = CATransform3DConcat(layer.transform, t);
        }
    }
    
    // 处理已经从镜头中消失的人脸图层
    // 人脸已消失，但它对应的图层并没有随之删除
    for (NSNumber *faceID in lostFaces) {
        CALayer *layer = self.faceLayers[faceID];
        [layer removeFromSuperlayer];
        
        [self.faceLayers removeObjectForKey:faceID];
    }
    
    // 人脸识别以后的细节处理
}

+ (Class)layerClass {
    // 在UIView 重写layerClass 类方法可以让开发者创建视图实例自定义图层了下
    // 重写layerClass方法并返回AVCaptureVideoPrevieLayer类对象
    return [AVCaptureVideoPreviewLayer class];
}


- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupView];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self setupView];
    }
    return self;
}

- (void)setupView {
    
    // 字典：用来记录人脸图层
    self.faceLayers = [NSMutableDictionary dictionary];
    // 图层的填充方式
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    // 添加一个透明的图层
    self.overlayLayer = [CALayer layer];
    
    self.overlayLayer.frame = self.bounds;
    
    // 图层上的图形发生3D变化 设置投影
    self.overlayLayer.sublayerTransform = CATransform3DMakePerspective(1000);
    
    [self.previewLayer addSublayer:self.overlayLayer];
}

// 获得layer
- (AVCaptureVideoPreviewLayer *)previewLayer {
    return (AVCaptureVideoPreviewLayer *)self.layer;
}

- (AVCaptureSession *)session {
    return self.previewLayer.session;
}

- (void)setSession:(AVCaptureSession *)session {
    self.previewLayer.session = session;
}

// 将设备的坐标空间的人脸转换为视图空间的对象集合
- (NSArray *)transformedFacesFromFaces:(NSArray *)faces {

    NSMutableArray *transformFaces = [NSMutableArray array];
    
    for (AVMetadataObject *face in faces) {
        // 将摄像头的人脸数据 转换为 视图上的可展示的数据
        // 简单说：UIKit的坐标 与 摄像头坐标系统（0，0）-（1，1）不一样。所以需要转换
        // 转换需要考虑图层、镜像、视频重力、方向等因素 在iOS6.0之前需要开发者自己计算，但iOS6.0后提供方法
        AVMetadataObject *transformedFace = [self.previewLayer transformedMetadataObjectForMetadataObject:face];
        
        // 转换成功后，加入到数组中
        [transformFaces addObject:transformedFace];
    }
    
    return transformFaces;
}

- (CALayer *)makeFaceLayer {

    // 创建一个layer
    CALayer *layer = [CALayer layer];
    
    // 边框宽度为5.0f
    layer.borderWidth = 5.0f;
    
    // 边框颜色为红色
    layer.borderColor = [UIColor redColor].CGColor;
    
    layer.contents = (id)[UIImage imageNamed:@"551.png"].CGImage;
    
    // 返回layer
    return layer;
}

// 将 RollAngle 的 rollAngleInDegrees 值转换为 CATransform3D
- (CATransform3D)transformForRollAngle:(CGFloat)rollAngleInDegrees {

    // 将人脸对象得到的RollAngle 单位“度” 转为Core Animation 需要的弧度值
    CGFloat rollAngleInRadians = IFLDegreesToRadians(rollAngleInDegrees);

    // 将结果赋给CATransform3DMakeRotation x,y,z轴为0，0，1 得到绕Z轴倾斜角旋转转换
    return CATransform3DMakeRotation(rollAngleInRadians, 0.0f, 0.0f, 1.0f);
    
}


// 将 YawAngle 的 yawAngleInDegrees 值转换为 CATransform3D (需要考虑设备本身的方向 竖拍 还是横拍)
- (CATransform3D)transformForYawAngle:(CGFloat)yawAngleInDegrees {

    // 将角度转换为弧度值
    CGFloat yawAngleInRaians = IFLDegreesToRadians(yawAngleInDegrees);
    
    // 将结果CATransform3DMakeRotation x,y,z轴为0，-1，0 得到绕Y轴选择。
    // 由于overlayer 需要应用sublayerTransform，所以图层会投射到z轴上，人脸从一侧转向另一侧会有3D 效果
    CATransform3D yawTransform = CATransform3DMakeRotation(yawAngleInRaians, 0.0f, -1.0f, 0.0f);
    
    // 因为应用程序的界面固定为垂直方向，但需要为设备方向计算一个相应的旋转变换
    // 如果不这样，会造成人脸图层的偏转效果不正确
    return CATransform3DConcat(yawTransform, [self orientationTransform]);
}

- (CATransform3D)orientationTransform {
    CGFloat angle = 0.0;
    // 拿到设备方向
    switch ([UIDevice currentDevice].orientation) {
        case UIDeviceOrientationPortraitUpsideDown:     // 方向: 下
            angle = M_PI;
            break;
        case UIDeviceOrientationLandscapeRight:         // 方向：右
            angle = -M_PI / 2.0f;
            break;
        case UIDeviceOrientationLandscapeLeft:          // 方向：左
            angle = M_PI /2.0f;
            break;
        default:                                        // 其他 正常竖着方向
            angle = 0.0f;
            break;
    }
    return CATransform3DMakeRotation(angle, 0.0f, 0.0f, 1.0f);
}


@end
