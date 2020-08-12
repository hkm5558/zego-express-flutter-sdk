//
//  ZegoExpressEngineMethodHandler.m
//  Pods-Runner
//
//  Created by Patrick Fu on 2020/5/8.
//  Copyright © 2020 Zego. All rights reserved.
//

#import "ZegoExpressEngineMethodHandler.h"
#import <ZegoExpressEngine/ZegoExpressEngine.h>

#import "ZegoExpressEngineEventHandler.h"

#import "ZegoPlatformViewFactory.h"
#import "ZegoTextureRendererController.h"

#import "ZegoUtils.h"
#import "ZegoLog.h"
#import <objc/message.h>

@interface ZegoExpressEngineMethodHandler ()

@property (nonatomic, assign) BOOL enablePlatformView;

@property (nonatomic, strong) id<FlutterTextureRegistry> textureRegistry;

@property (nonatomic, strong) ZegoExpressEngineEventHandler *eventHandler;

@property (nonatomic, strong) NSMutableDictionary<NSNumber *, ZegoMediaPlayer *> *mediaPlayerMap;

@end

@implementation ZegoExpressEngineMethodHandler

+ (instancetype)sharedInstance {
    static ZegoExpressEngineMethodHandler *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ZegoExpressEngineMethodHandler alloc] init];
    });
    return instance;
}


#pragma mark - Main

- (void)getVersion:(FlutterMethodCall *)call result:(FlutterResult)result {

    result([ZegoExpressEngine getVersion]);
}

- (void)createEngine:(FlutterMethodCall *)call result:(FlutterResult)result {
    // Set platform language to dart
    SEL selector = NSSelectorFromString(@"setPlatformLanguage:");
    if ([ZegoExpressEngine respondsToSelector:selector]) {
        ((void (*)(id, SEL, int))objc_msgSend)(ZegoExpressEngine.class, selector, 4);
    }

    unsigned int appID = [ZegoUtils unsignedIntValue:call.arguments[@"appID"]];
    NSString *appSign = call.arguments[@"appSign"];
    BOOL isTestEnv = [ZegoUtils boolValue:call.arguments[@"isTestEnv"]];
    int scenario = [ZegoUtils intValue:call.arguments[@"scenario"]];

    _enablePlatformView = [ZegoUtils boolValue:call.arguments[@"enablePlatformView"]];
    _textureRegistry = call.arguments[@"textureRegistry"];

    // Init the event handler
    self.eventHandler = [[ZegoExpressEngineEventHandler alloc] initWithSink:call.arguments[@"eventSink"]];

    // Create engine
    [ZegoExpressEngine createEngineWithAppID:appID appSign:appSign isTestEnv:isTestEnv scenario:(ZegoScenario)scenario eventHandler:self.eventHandler];

    // Init texture renderer
    if (!self.enablePlatformView) {
        [[ZegoTextureRendererController sharedInstance] initController];
    }

    result(nil);
}

- (void)destroyEngine:(FlutterMethodCall *)call result:(FlutterResult)result {

    [ZegoExpressEngine destroyEngine:nil];

    // Uninit texture renderer
    if (!self.enablePlatformView) {
        [[ZegoTextureRendererController sharedInstance] uninitController];
    }

    self.eventHandler = nil;

    result(nil);
}

- (void)uploadLog:(FlutterMethodCall *)call result:(FlutterResult)result {

    [[ZegoExpressEngine sharedEngine] uploadLog];

    result(nil);
}

- (void)setDebugVerbose:(FlutterMethodCall *)call result:(FlutterResult)result {

    BOOL enable = [ZegoUtils boolValue:call.arguments[@"enable"]];
    int language = [ZegoUtils intValue:call.arguments[@"language"]];

    [[ZegoExpressEngine sharedEngine] setDebugVerbose:enable language:(ZegoLanguage)language];

    result(nil);
}


#pragma mark - Room

- (void)loginRoom:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSString *roomID = call.arguments[@"roomID"];
    NSDictionary *userMap = call.arguments[@"user"];
    NSDictionary *configMap = call.arguments[@"config"];

    ZegoUser *userObject = [[ZegoUser alloc] initWithUserID:userMap[@"userID"] userName:userMap[@"userName"]];

    if (configMap && configMap.count > 0) {
        unsigned int maxMemberCount = [ZegoUtils unsignedIntValue:configMap[@"maxMemberCount"]];
        BOOL isUserStatusNotify = [ZegoUtils boolValue:configMap[@"isUserStatusNotify"]];
        NSString *token = configMap[@"token"];

        ZegoRoomConfig *configObject = [[ZegoRoomConfig alloc] init];
        configObject.maxMemberCount = maxMemberCount;
        configObject.isUserStatusNotify = isUserStatusNotify;
        configObject.token = token;

        [[ZegoExpressEngine sharedEngine] loginRoom:roomID user:userObject config:configObject];
    } else {
        [[ZegoExpressEngine sharedEngine] loginRoom:roomID user:userObject];
    }

    result(nil);
}

- (void)logoutRoom:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSString *roomID = call.arguments[@"roomID"];

    [[ZegoExpressEngine sharedEngine] logoutRoom:roomID];

    result(nil);
}


#pragma mark - Publisher

- (void)startPublishingStream:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSString *streamID = call.arguments[@"streamID"];
    int channel = [ZegoUtils intValue:call.arguments[@"channel"]];

    [[ZegoExpressEngine sharedEngine] startPublishingStream:streamID channel:(ZegoPublishChannel)channel];

    result(nil);
}

- (void)stopPublishingStream:(FlutterMethodCall *)call result:(FlutterResult)result {

    int channel = [ZegoUtils intValue:call.arguments[@"channel"]];

    [[ZegoExpressEngine sharedEngine] stopPublishingStream:(ZegoPublishChannel)channel];

    result(nil);
}

- (void)setStreamExtraInfo:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSString *extraInfo = call.arguments[@"extraInfo"];
    int channel = [ZegoUtils intValue:call.arguments[@"channel"]];

    [[ZegoExpressEngine sharedEngine] setStreamExtraInfo:extraInfo channel:(ZegoPublishChannel)channel callback:^(int errorCode) {
        result(@{@"errorCode": @(errorCode)});
    }];
}

- (void)startPreview:(FlutterMethodCall *)call result:(FlutterResult)result {

    int channel = [ZegoUtils intValue:call.arguments[@"channel"]];

    // Handle ZegoCanvas

    NSDictionary *canvasMap = call.arguments[@"canvas"];

    if (canvasMap && canvasMap.count > 0) {
        // Preview video

        // This parameter is actually viewID when using PlatformView, and is actually textureID when using Texture render
        int64_t viewID = [ZegoUtils longLongValue:canvasMap[@"view"]];
        int viewMode = [ZegoUtils intValue:canvasMap[@"viewMode"]];
        int backgroundColor = [ZegoUtils intValue:canvasMap[@"backgroundColor"]];

        if (self.enablePlatformView) {
            // Render with PlatformView
            ZegoPlatformView *platformView = [[ZegoPlatformViewFactory sharedInstance] getPlatformView:@(viewID)];

            if (platformView) {
                ZegoCanvas *canvas = [[ZegoCanvas alloc] initWithView:[platformView getUIView]];
                canvas.viewMode = (ZegoViewMode)viewMode;
                canvas.backgroundColor = backgroundColor;

                [[ZegoExpressEngine sharedEngine] startPreview:canvas channel:(ZegoPublishChannel)channel];
            } else {
                // Preview video without creating the PlatfromView in advance
                // Need to invoke dart `createPlatformView` method in advance to create PlatfromView and get viewID (PlatformViewID)
                // TODO: Throw Flutter Exception
            }

        } else {
            // Render with Texture
            if ([[ZegoTextureRendererController sharedInstance] addCapturedRenderer:viewID key:@(channel)]) {
                [[ZegoTextureRendererController sharedInstance] startRendering];
            } else {
                // Preview video without creating TextureRenderer in advance
                // Need to invoke dart `createTextureRenderer` method in advance to create TextureRenderer and get viewID (TextureID)
                // TODO: Throw Flutter Exception
            }

            // Using Custom Video Renderer
            [[ZegoExpressEngine sharedEngine] startPreview:nil channel:(ZegoPublishChannel)channel];
        }

    } else { /* if (canvas && canvas.count > 0) */

        // Preview audio only
        [[ZegoExpressEngine sharedEngine] startPreview:nil channel:(ZegoPublishChannel)channel];
    }

    result(nil);
}

- (void)stopPreview:(FlutterMethodCall *)call result:(FlutterResult)result {

    int channel = [ZegoUtils intValue:call.arguments[@"channel"]];
    [[ZegoExpressEngine sharedEngine] stopPreview:(ZegoPublishChannel)channel];

    if (!self.enablePlatformView) {
        // Stop Texture Renderer
        [[ZegoTextureRendererController sharedInstance] removeCapturedRenderer:@(channel)];
        [[ZegoTextureRendererController sharedInstance] stopRendering];
    }

    result(nil);
}

- (void)setVideoConfig:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSDictionary *configMap = call.arguments[@"config"];
    int capWidth = [ZegoUtils intValue:configMap[@"captureWidth"]];
    int capHeight = [ZegoUtils intValue:configMap[@"captureHeight"]];
    int encWidth = [ZegoUtils intValue:configMap[@"encodeWidth"]];
    int encHeight = [ZegoUtils intValue:configMap[@"encodeHeight"]];
    int bitrate = [ZegoUtils intValue:configMap[@"bitrate"]];
    int fps = [ZegoUtils intValue:configMap[@"fps"]];
    int codecID = [ZegoUtils intValue:configMap[@"codecID"]];

    ZegoVideoConfig *configObject = [[ZegoVideoConfig alloc] init];
    configObject.captureResolution = CGSizeMake(capWidth, capHeight);
    configObject.encodeResolution = CGSizeMake(encWidth, encHeight);
    configObject.bitrate = bitrate;
    configObject.fps = fps;
    configObject.codecID = (ZegoVideoCodecID)codecID;

    int channel = [ZegoUtils intValue:call.arguments[@"channel"]];

    [[ZegoExpressEngine sharedEngine] setVideoConfig:configObject channel:(ZegoPublishChannel)channel];

    result(nil);
}

- (void)getVideoConfig:(FlutterMethodCall *)call result:(FlutterResult)result {

    int channel = [ZegoUtils intValue:call.arguments[@"channel"]];

    ZegoVideoConfig *configObject = [[ZegoExpressEngine sharedEngine] getVideoConfig:(ZegoPublishChannel)channel];

    result(@{
        @"captureWidth": @(configObject.captureResolution.width),
        @"captureHeight": @(configObject.captureResolution.height),
        @"encodeWidth": @(configObject.encodeResolution.width),
        @"encodeHeight": @(configObject.encodeResolution.height),
        @"bitrate": @(configObject.bitrate),
        @"fps": @(configObject.fps),
        @"codecID": @(configObject.codecID)
    });
}

- (void)setVideoMirrorMode:(FlutterMethodCall *)call result:(FlutterResult)result {

    int mode = [ZegoUtils intValue:call.arguments[@"mirrorMode"]];
    int channel = [ZegoUtils intValue:call.arguments[@"channel"]];

    [[ZegoExpressEngine sharedEngine] setVideoMirrorMode:(ZegoVideoMirrorMode)mode channel:(ZegoPublishChannel)channel];

    result(nil);

}

- (void)setAppOrientation:(FlutterMethodCall *)call result:(FlutterResult)result {

    int orientation = [ZegoUtils intValue:call.arguments[@"orientation"]];
    UIInterfaceOrientation  uiOrientation = UIInterfaceOrientationUnknown;
    switch (orientation) {
        case 0:
            uiOrientation = UIInterfaceOrientationPortrait;
            break;
        case 1:
            uiOrientation = UIInterfaceOrientationLandscapeRight;
            break;
        case 2:
            uiOrientation = UIInterfaceOrientationPortraitUpsideDown;
            break;
        case 3:
            uiOrientation = UIInterfaceOrientationLandscapeLeft;
        default:
            break;
    }

    int channel = [ZegoUtils intValue:call.arguments[@"channel"]];

    [[ZegoExpressEngine sharedEngine] setAppOrientation:uiOrientation channel:(ZegoPublishChannel)channel];

    result(nil);
}

- (void)setAudioConfig:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSDictionary *configMap = call.arguments[@"config"];
    int bitrate = [ZegoUtils intValue:configMap[@"bitrate"]];
    int channel = [ZegoUtils intValue:configMap[@"channel"]];
    int codecID = [ZegoUtils intValue:configMap[@"codecID"]];

    ZegoAudioConfig *configObject = [[ZegoAudioConfig alloc] init];
    configObject.bitrate = bitrate;
    configObject.channel = channel;
    configObject.codecID = (ZegoAudioCodecID)codecID;

    [[ZegoExpressEngine sharedEngine] setAudioConfig:configObject];

    result(nil);
}

- (void)getAudioConfig:(FlutterMethodCall *)call result:(FlutterResult)result {

    ZegoAudioConfig *configObject = [[ZegoExpressEngine sharedEngine] getAudioConfig];

    result(@{
        @"bitrate": @(configObject.bitrate),
        @"channel": @(configObject.channel),
        @"codecID": @(configObject.codecID)
    });
}

- (void)mutePublishStreamAudio:(FlutterMethodCall *)call result:(FlutterResult)result {

    BOOL mute = [ZegoUtils boolValue:call.arguments[@"mute"]];
    int channel = [ZegoUtils intValue:call.arguments[@"channel"]];

    [[ZegoExpressEngine sharedEngine] mutePublishStreamAudio:mute channel:(ZegoPublishChannel)channel];

    result(nil);
}

- (void)mutePublishStreamVideo:(FlutterMethodCall *)call result:(FlutterResult)result {

    BOOL mute = [ZegoUtils boolValue:call.arguments[@"mute"]];
    int channel = [ZegoUtils intValue:call.arguments[@"channel"]];

    [[ZegoExpressEngine sharedEngine] mutePublishStreamVideo:mute channel:(ZegoPublishChannel)channel];

    result(nil);
}

- (void)enableTrafficControl:(FlutterMethodCall *)call result:(FlutterResult)result {

    BOOL enable = [ZegoUtils boolValue:call.arguments[@"enable"]];
    int property = [ZegoUtils intValue:call.arguments[@"property"]];

    [[ZegoExpressEngine sharedEngine] enableTrafficControl:enable property:(ZegoTrafficControlProperty)property];

    result(nil);
}

- (void)setMinVideoBitrateForTrafficControl:(FlutterMethodCall *)call result:(FlutterResult)result {

    int bitrate = [ZegoUtils intValue:call.arguments[@"bitrate"]];
    int mode = [ZegoUtils intValue:call.arguments[@"mode"]];

    [[ZegoExpressEngine sharedEngine] setMinVideoBitrateForTrafficControl:bitrate mode:(ZegoTrafficControlMinVideoBitrateMode)mode];

    result(nil);
}

- (void)setCaptureVolume:(FlutterMethodCall *)call result:(FlutterResult)result {

    int volume = [ZegoUtils intValue:call.arguments[@"volume"]];

    [[ZegoExpressEngine sharedEngine] setCaptureVolume:volume];

    result(nil);
}

- (void)addPublishCdnUrl:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSString *targetURL = call.arguments[@"targetURL"];
    NSString *streamID = call.arguments[@"streamID"];

    [[ZegoExpressEngine sharedEngine] addPublishCdnUrl:targetURL streamID:streamID callback:^(int errorCode) {
        result(@{@"errorCode": @(errorCode)});
    }];
}

- (void)removePublishCdnUrl:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSString *targetURL = call.arguments[@"targetURL"];
    NSString *streamID = call.arguments[@"streamID"];

    [[ZegoExpressEngine sharedEngine] removePublishCdnUrl:targetURL streamID:streamID callback:^(int errorCode) {
        result(@{@"errorCode": @(errorCode)});
    }];
}

- (void)enablePublishDirectToCDN:(FlutterMethodCall *)call result:(FlutterResult)result {

    BOOL enable = [ZegoUtils boolValue:call.arguments[@"enable"]];

    ZegoCDNConfig *cdnConfig = nil;
    NSDictionary *config = call.arguments[@"config"];
    if (config && config.count > 0) {
        NSString *url = config[@"url"];
        NSString *authParam = config[@"authParam"];

        cdnConfig = [[ZegoCDNConfig alloc] init];
        cdnConfig.url = url;
        cdnConfig.authParam = authParam;
    }

    int channel = [ZegoUtils intValue:call.arguments[@"channel"]];

    [[ZegoExpressEngine sharedEngine] enablePublishDirectToCDN:enable config:cdnConfig channel:(ZegoPublishChannel)channel];

    result(nil);
}

- (void)setPublishWatermark:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSDictionary *watermarkMap = call.arguments[@"watermark"];
    ZegoWatermark *watermarkObject = nil;
    if (watermarkMap && watermarkMap.count > 0) {
        NSString *imageURL = watermarkMap[@"imageURL"];
        int left = [ZegoUtils intValue:watermarkMap[@"left"]];
        int top = [ZegoUtils intValue:watermarkMap[@"top"]];
        int bottom = [ZegoUtils intValue:watermarkMap[@"bottom"]];
        int right = [ZegoUtils intValue:watermarkMap[@"right"]];
        CGRect rect = CGRectMake(left, top, right - left, bottom - top);
        watermarkObject = [[ZegoWatermark alloc] initWithImageURL:imageURL layout:rect];
    }

    BOOL isPreviewVisible = [ZegoUtils boolValue:call.arguments[@"isPreviewVisible"]];
    int channel = [ZegoUtils intValue:call.arguments[@"channel"]];

    [[ZegoExpressEngine sharedEngine] setPublishWatermark:watermarkObject isPreviewVisible:isPreviewVisible channel:(ZegoPublishChannel)channel];

    result(nil);
}

- (void)sendSEI:(FlutterMethodCall *)call result:(FlutterResult)result {

    FlutterStandardTypedData *data = call.arguments[@"byteData"];
    int channel = [ZegoUtils intValue:call.arguments[@"channel"]];

    [[ZegoExpressEngine sharedEngine] sendSEI:data.data channel:(ZegoPublishChannel)channel];

    result(nil);
}

- (void)enableHardwareEncoder:(FlutterMethodCall *)call result:(FlutterResult)result {

    BOOL enable = [ZegoUtils boolValue:call.arguments[@"enable"]];

    [[ZegoExpressEngine sharedEngine] enableHardwareEncoder:enable];

    result(nil);
}

- (void)setCapturePipelineScaleMode:(FlutterMethodCall *)call result:(FlutterResult)result {

    int mode = [ZegoUtils intValue:call.arguments[@"mode"]];

    [[ZegoExpressEngine sharedEngine] setCapturePipelineScaleMode:(ZegoCapturePipelineScaleMode)mode];

    result(nil);
}


#pragma mark - Player

- (void)startPlayingStream:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSString *streamID = call.arguments[@"streamID"];

    // Handle ZegoPlayerConfig

    ZegoPlayerConfig *playerConfig = nil;

    NSDictionary *playerConfigMap = call.arguments[@"config"];

    if (playerConfigMap && playerConfigMap.count > 0) {

        playerConfig = [[ZegoPlayerConfig alloc] init];
        playerConfig.videoLayer = (ZegoPlayerVideoLayer)[ZegoUtils intValue:playerConfigMap[@"videoLayer"]];
        NSDictionary * cdnConfigMap = playerConfigMap[@"cdnConfig"];

        if (cdnConfigMap && cdnConfigMap.count > 0) {
            ZegoCDNConfig *cdnConfig = [[ZegoCDNConfig alloc] init];
            cdnConfig.url = cdnConfigMap[@"url"];
            cdnConfig.authParam = cdnConfigMap[@"authParam"];
            playerConfig.cdnConfig = cdnConfig;
        }
    }

    // Handle ZegoCanvas

    NSDictionary *canvasMap = call.arguments[@"canvas"];

    if (canvasMap && canvasMap.count > 0) {
        // Play video

        // This parameter is actually viewID when using PlatformView, and is actually textureID when using Texture render
        int64_t viewID = [ZegoUtils longLongValue:canvasMap[@"view"]];
        int viewMode = [ZegoUtils intValue:canvasMap[@"viewMode"]];
        int backgroundColor = [ZegoUtils intValue:canvasMap[@"backgroundColor"]];

        if (self.enablePlatformView) {
            // Render with PlatformView
            ZegoPlatformView *platformView = [[ZegoPlatformViewFactory sharedInstance] getPlatformView:@(viewID)];

            if (platformView) {
                ZegoCanvas *canvas = [[ZegoCanvas alloc] initWithView:[platformView getUIView]];
                canvas.viewMode = (ZegoViewMode)viewMode;
                canvas.backgroundColor = backgroundColor;

                if (playerConfig) {
                    [[ZegoExpressEngine sharedEngine] startPlayingStream:streamID canvas:canvas config:playerConfig];
                } else {
                    [[ZegoExpressEngine sharedEngine] startPlayingStream:streamID canvas:canvas];
                }
            } else {
                // Play video without creating the PlatfromView in advance
                // Need to invoke dart `createPlatformView` method in advance to create PlatfromView and get viewID (PlatformViewID)
                // TODO: Throw Flutter Exception
            }

        } else {
            // Render with Texture
            if ([[ZegoTextureRendererController sharedInstance] addRemoteRenderer:viewID key:streamID]) {
                [[ZegoTextureRendererController sharedInstance] startRendering];
            } else {
                // Play video without creating TextureRenderer in advance
                // Need to invoke dart `createTextureRenderer` method in advance to create TextureRenderer and get viewID (TextureID)
                // TODO: Throw Flutter Exception
            }

            // Using Custom Video Renderer
            if (playerConfig) {
                [[ZegoExpressEngine sharedEngine] startPlayingStream:streamID canvas:nil config:playerConfig];
            } else {
                [[ZegoExpressEngine sharedEngine] startPlayingStream:streamID canvas:nil];
            }
        }

    } else { /* if (canvas && canvas.count > 0) */

        // Play audio only
        if (playerConfig) {
            [[ZegoExpressEngine sharedEngine] startPlayingStream:streamID canvas:nil config:playerConfig];
        } else {
            [[ZegoExpressEngine sharedEngine] startPlayingStream:streamID canvas:nil];
        }
    }

    result(nil);
}

- (void)stopPlayingStream:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSString *streamID = call.arguments[@"streamID"];
    [[ZegoExpressEngine sharedEngine] stopPlayingStream:streamID];

    if (!self.enablePlatformView) {
        // Stop Texture render
        [[ZegoTextureRendererController sharedInstance] removeRemoteRenderer:streamID];
        [[ZegoTextureRendererController sharedInstance] stopRendering];
    }

    result(nil);
}

- (void)setPlayVolume:(FlutterMethodCall *)call result:(FlutterResult)result {

    int volume = [ZegoUtils intValue:call.arguments[@"volume"]];
    NSString *streamID = call.arguments[@"streamID"];

    [[ZegoExpressEngine sharedEngine] setPlayVolume:volume streamID:streamID];

    result(nil);
}

- (void)mutePlayStreamAudio:(FlutterMethodCall *)call result:(FlutterResult)result {

    BOOL mute = [ZegoUtils boolValue:call.arguments[@"mute"]];
    NSString *streamID = call.arguments[@"streamID"];

    [[ZegoExpressEngine sharedEngine] mutePlayStreamAudio:mute streamID:streamID];

    result(nil);
}

- (void)mutePlayStreamVideo:(FlutterMethodCall *)call result:(FlutterResult)result {

    BOOL mute = [ZegoUtils boolValue:call.arguments[@"mute"]];
    NSString *streamID = call.arguments[@"streamID"];

    [[ZegoExpressEngine sharedEngine] mutePlayStreamVideo:mute streamID:streamID];

    result(nil);
}

- (void)enableHardwareDecoder:(FlutterMethodCall *)call result:(FlutterResult)result {

    BOOL enable = [ZegoUtils boolValue:call.arguments[@"enable"]];

    [[ZegoExpressEngine sharedEngine] enableHardwareDecoder:enable];

    result(nil);
}

- (void)enableCheckPoc:(FlutterMethodCall *)call result:(FlutterResult)result {

    BOOL enable = [ZegoUtils boolValue:call.arguments[@"enable"]];

    [[ZegoExpressEngine sharedEngine] enableCheckPoc:enable];

    result(nil);
}


#pragma mark - Mixer

- (void)startMixerTask:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSString *taskID = call.arguments[@"taskID"];
    ZegoMixerTask *taskObject = [[ZegoMixerTask alloc] initWithTaskID:taskID];

    // MixerInput
    NSArray<NSDictionary *> *inputListMap = call.arguments[@"inputList"];
    if (inputListMap && inputListMap.count > 0) {
        NSMutableArray<ZegoMixerInput *> *inputListObject = [[NSMutableArray alloc] init];
        for (NSDictionary *inputMap in inputListMap) {
            NSString *streamID = inputMap[@"streamID"];
            int contentType = [ZegoUtils intValue:inputMap[@"contentType"]];
            int left = [ZegoUtils intValue:inputMap[@"left"]];
            int top = [ZegoUtils intValue:inputMap[@"top"]];
            int right = [ZegoUtils intValue:inputMap[@"right"]];
            int bottom = [ZegoUtils intValue:inputMap[@"bottom"]];
            CGRect rect = CGRectMake(left, top, right - left, bottom - top);
            unsigned int soundLevelID = [ZegoUtils unsignedIntValue:inputMap[@"soundLevelID"]];
            ZegoMixerInput *inputObject = [[ZegoMixerInput alloc] initWithStreamID:streamID contentType:(ZegoMixerInputContentType)contentType layout:rect soundLevelID:soundLevelID];
            [inputListObject addObject:inputObject];
        }
        [taskObject setInputList:inputListObject];
    }

    // MixerOutput
    NSArray<NSDictionary *> *outputListMap = call.arguments[@"outputList"];
    if (outputListMap && outputListMap.count > 0) {
        NSMutableArray<ZegoMixerOutput *> *outputListObject = [[NSMutableArray alloc] init];
        for (NSDictionary *outputMap in outputListMap) {
            NSString *target = outputMap[@"target"];
            ZegoMixerOutput *outputObject = [[ZegoMixerOutput alloc] initWithTarget:target];
            [outputListObject addObject:outputObject];
        }
        [taskObject setOutputList:outputListObject];
    }

    // AudioConfig
    NSDictionary *audioConfigMap = call.arguments[@"audioConfig"];
    if (audioConfigMap && audioConfigMap.count > 0) {
        int bitrate = [ZegoUtils intValue:audioConfigMap[@"bitrate"]];
        int channel = [ZegoUtils intValue:audioConfigMap[@"channel"]];
        int codecID = [ZegoUtils intValue:audioConfigMap[@"codecID"]];
        ZegoMixerAudioConfig *audioConfigObject = [[ZegoMixerAudioConfig alloc] init];
        audioConfigObject.bitrate = bitrate;
        audioConfigObject.channel = (ZegoAudioChannel)channel;
        audioConfigObject.codecID = (ZegoAudioCodecID)codecID;

        [taskObject setAudioConfig:audioConfigObject];
    }

    // VideoConfig
    NSDictionary *videoConfigMap = call.arguments[@"videoConfig"];
    if (videoConfigMap && videoConfigMap.count > 0) {
        int width = [ZegoUtils intValue:videoConfigMap[@"width"]];
        int height = [ZegoUtils intValue:videoConfigMap[@"height"]];
        int fps = [ZegoUtils intValue:videoConfigMap[@"fps"]];
        int bitrate = [ZegoUtils intValue:videoConfigMap[@"bitrate"]];
        ZegoMixerVideoConfig *videoConfigObject = [[ZegoMixerVideoConfig alloc] init];
        videoConfigObject.resolution = CGSizeMake((CGFloat)width, (CGFloat)height);
        videoConfigObject.bitrate = bitrate;
        videoConfigObject.fps = fps;

        [taskObject setVideoConfig:videoConfigObject];
    }

    // Watermark
    NSDictionary *watermarkMap = call.arguments[@"watermark"];
    if (watermarkMap && watermarkMap.count > 0) {
        NSString *imageURL = watermarkMap[@"imageURL"];
        if (imageURL && [imageURL length] > 0) {
            int left = [ZegoUtils intValue:watermarkMap[@"left"]];
            int top = [ZegoUtils intValue:watermarkMap[@"top"]];
            int bottom = [ZegoUtils intValue:watermarkMap[@"bottom"]];
            int right = [ZegoUtils intValue:watermarkMap[@"right"]];
            CGRect rect = CGRectMake(left, top, right - left, bottom - top);
            ZegoWatermark *watermarkObject = [[ZegoWatermark alloc] initWithImageURL:imageURL layout:rect];

            [taskObject setWatermark:watermarkObject];
        }
    }

    // Background Image
    NSString *backgroundImageURL = call.arguments[@"backgroundImageURL"];

    if (backgroundImageURL.length > 0) {
        [taskObject setBackgroundImageURL:backgroundImageURL];
    }

    // Enable SoundLevel
    BOOL enableSoundLevel = [ZegoUtils boolValue:call.arguments[@"enableSoundLevel"]];

    [taskObject enableSoundLevel:enableSoundLevel];

    [[ZegoExpressEngine sharedEngine] startMixerTask:taskObject callback:^(int errorCode, NSDictionary * _Nullable extendedData) {

        NSString *extendedDataJsonString = @"{}";
        if (extendedData) {
            NSError *error;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:extendedData options:0 error:&error];
            if (!jsonData) {
                ZGLog(@"extendedData error: %@", error);
            }else{
                extendedDataJsonString = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
            }
        }

        result(@{
            @"errorCode": @(errorCode),
            @"extendedData": extendedDataJsonString
        });
    }];
}

- (void)stopMixerTask:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSString *taskID = call.arguments[@"taskID"];
    ZegoMixerTask *taskObject = [[ZegoMixerTask alloc] initWithTaskID:taskID];

    // MixerInput
    NSArray<NSDictionary *> *inputListMap = call.arguments[@"inputList"];
    if (inputListMap && inputListMap.count > 0) {
        NSMutableArray<ZegoMixerInput *> *inputListObject = [[NSMutableArray alloc] init];
        for (NSDictionary *inputMap in inputListMap) {
            NSString *streamID = inputMap[@"streamID"];
            int contentType = [ZegoUtils intValue:inputMap[@"contentType"]];
            int left = [ZegoUtils intValue:inputMap[@"left"]];
            int top = [ZegoUtils intValue:inputMap[@"top"]];
            int right = [ZegoUtils intValue:inputMap[@"right"]];
            int bottom = [ZegoUtils intValue:inputMap[@"bottom"]];
            CGRect rect = CGRectMake(left, top, right - left, bottom - top);
            unsigned int soundLevelID = [ZegoUtils unsignedIntValue:inputMap[@"soundLevelID"]];
            ZegoMixerInput *inputObject = [[ZegoMixerInput alloc] initWithStreamID:streamID contentType:(ZegoMixerInputContentType)contentType layout:rect soundLevelID:soundLevelID];
            [inputListObject addObject:inputObject];
        }
        [taskObject setInputList:inputListObject];
    }

    // MixerOutput
    NSArray<NSDictionary *> *outputListMap = call.arguments[@"outputList"];
    if (outputListMap && outputListMap.count > 0) {
        NSMutableArray<ZegoMixerOutput *> *outputListObject = [[NSMutableArray alloc] init];
        for (NSDictionary *outputMap in outputListMap) {
            NSString *target = outputMap[@"target"];
            ZegoMixerOutput *outputObject = [[ZegoMixerOutput alloc] initWithTarget:target];
            [outputListObject addObject:outputObject];
        }
        [taskObject setOutputList:outputListObject];
    }

    // no need to set audio config

    // no need to set video config

    // no need to set watermark

    // no need to set background image

    // no need to set enable sound level

    [[ZegoExpressEngine sharedEngine] stopMixerTask:taskObject callback:^(int errorCode) {
        result(@{@"errorCode": @(errorCode)});
    }];
}


#pragma mark - Device

- (void)muteMicrophone:(FlutterMethodCall *)call result:(FlutterResult)result {

    BOOL mute = [ZegoUtils boolValue:call.arguments[@"mute"]];

    [[ZegoExpressEngine sharedEngine] muteMicrophone:mute];

    result(nil);
}

- (void)isMicrophoneMuted:(FlutterMethodCall *)call result:(FlutterResult)result {

    BOOL muted = [[ZegoExpressEngine sharedEngine] isMicrophoneMuted];

    result(@(muted));
}

- (void)muteSpeaker:(FlutterMethodCall *)call result:(FlutterResult)result {

    BOOL mute = [ZegoUtils boolValue:call.arguments[@"mute"]];

    [[ZegoExpressEngine sharedEngine] muteSpeaker:mute];

    result(nil);
}

- (void)isSpeakerMuted:(FlutterMethodCall *)call result:(FlutterResult)result {

    BOOL muted = [[ZegoExpressEngine sharedEngine] isSpeakerMuted];

    result(@(muted));
}

- (void)enableAudioCaptureDevice:(FlutterMethodCall *)call result:(FlutterResult)result {

    BOOL enable = [ZegoUtils boolValue:call.arguments[@"enable"]];

    [[ZegoExpressEngine sharedEngine] enableAudioCaptureDevice:enable];

    result(nil);
}

- (void)setBuiltInSpeakerOn:(FlutterMethodCall *)call result:(FlutterResult)result {

    BOOL enable = [ZegoUtils boolValue:call.arguments[@"enable"]];

    [[ZegoExpressEngine sharedEngine] setBuiltInSpeakerOn:enable];

    result(nil);
}

- (void)enableCamera:(FlutterMethodCall *)call result:(FlutterResult)result {

    BOOL enable = [ZegoUtils boolValue:call.arguments[@"enable"]];
    int channel = [ZegoUtils intValue:call.arguments[@"channel"]];

    [[ZegoExpressEngine sharedEngine] enableCamera:enable channel:(ZegoPublishChannel)channel];

    result(nil);
}

- (void)useFrontCamera:(FlutterMethodCall *)call result:(FlutterResult)result {

    BOOL enable = [ZegoUtils boolValue:call.arguments[@"enable"]];
    int channel = [ZegoUtils intValue:call.arguments[@"channel"]];

    [[ZegoExpressEngine sharedEngine] useFrontCamera:enable channel:(ZegoPublishChannel)channel];

    result(nil);
}

- (void)startSoundLevelMonitor:(FlutterMethodCall *)call result:(FlutterResult)result {

    [[ZegoExpressEngine sharedEngine] startSoundLevelMonitor];

    result(nil);
}

- (void)stopSoundLevelMonitor:(FlutterMethodCall *)call result:(FlutterResult)result {

    [[ZegoExpressEngine sharedEngine] stopSoundLevelMonitor];

    result(nil);
}

- (void)startAudioSpectrumMonitor:(FlutterMethodCall *)call result:(FlutterResult)result {

    [[ZegoExpressEngine sharedEngine] startAudioSpectrumMonitor];

    result(nil);
}

- (void)stopAudioSpectrumMonitor:(FlutterMethodCall *)call result:(FlutterResult)result {

    [[ZegoExpressEngine sharedEngine] stopSoundLevelMonitor];

    result(nil);
}

- (void)enableHeadphoneMonitor:(FlutterMethodCall *)call result:(FlutterResult)result {

    BOOL enable = [ZegoUtils boolValue:call.arguments[@"enable"]];

    [[ZegoExpressEngine sharedEngine] enableHeadphoneMonitor:enable];

    result(nil);
}

- (void)setHeadphoneMonitorVolume:(FlutterMethodCall *)call result:(FlutterResult)result {

    int volume = [ZegoUtils intValue:call.arguments[@"volume"]];

    [[ZegoExpressEngine sharedEngine] setHeadphoneMonitorVolume:volume];

    result(nil);
}


#pragma mark - Preprocess

- (void)enableAEC:(FlutterMethodCall *)call result:(FlutterResult)result {

    BOOL enable = [ZegoUtils boolValue:call.arguments[@"enable"]];

    [[ZegoExpressEngine sharedEngine] enableAEC:enable];

    result(nil);
}

- (void)setAECMode:(FlutterMethodCall *)call result:(FlutterResult)result {

    int mode = [ZegoUtils intValue:call.arguments[@"mode"]];

    [[ZegoExpressEngine sharedEngine] setAECMode:(ZegoAECMode)mode];

    result(nil);
}

- (void)enableAGC:(FlutterMethodCall *)call result:(FlutterResult)result {

    BOOL enable = [ZegoUtils boolValue:call.arguments[@"enable"]];

    [[ZegoExpressEngine sharedEngine] enableAGC:enable];

    result(nil);
}

- (void)enableANS:(FlutterMethodCall *)call result:(FlutterResult)result {

    BOOL enable = [ZegoUtils boolValue:call.arguments[@"enable"]];

    [[ZegoExpressEngine sharedEngine] enableANS:enable];

    result(nil);
}

- (void)setANSMode:(FlutterMethodCall *)call result:(FlutterResult)result {

    int mode = [ZegoUtils intValue:call.arguments[@"mode"]];

    [[ZegoExpressEngine sharedEngine] setANSMode:(ZegoANSMode)mode];

    result(nil);
}

- (void)enableBeautify:(FlutterMethodCall *)call result:(FlutterResult)result {

    int feature = [ZegoUtils intValue:call.arguments[@"featureBitmask"]];
    int channel = [ZegoUtils intValue:call.arguments[@"channel"]];

    [[ZegoExpressEngine sharedEngine] enableBeautify:(ZegoBeautifyFeature)feature channel:(ZegoPublishChannel)channel];

    result(nil);
}

- (void)setBeautifyOption:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSDictionary *option = call.arguments[@"option"];
    ZegoBeautifyOption *optionObject = [[ZegoBeautifyOption alloc] init];
    optionObject.polishStep = [ZegoUtils doubleValue:option[@"polishStep"]];
    optionObject.whitenFactor = [ZegoUtils doubleValue:option[@"whitenFactor"]];
    optionObject.sharpenFactor = [ZegoUtils doubleValue:option[@"sharpenFactor"]];

    int channel = [ZegoUtils intValue:call.arguments[@"channel"]];

    [[ZegoExpressEngine sharedEngine] setBeautifyOption: optionObject channel:(ZegoPublishChannel)channel];

    result(nil);
}

- (void)setAudioEqualizerGain:(FlutterMethodCall *)call result:(FlutterResult)result {

    int bandIndex = [ZegoUtils intValue:call.arguments[@"bandIndex"]];
    float bandGain = [ZegoUtils floatValue:call.arguments[@"bandGain"]];

    [[ZegoExpressEngine sharedEngine] setAudioEqualizerGain:bandIndex bandGain:bandGain];

    result(nil);
}

- (void)setVoiceChangerParam:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSDictionary *paramMap = call.arguments[@"param"];
    ZegoVoiceChangerParam *param = [[ZegoVoiceChangerParam alloc] init];
    param.pitch = [ZegoUtils floatValue:paramMap[@"pitch"]];

    [[ZegoExpressEngine sharedEngine] setVoiceChangerParam:param];

    result(nil);
}

- (void)setReverbParam:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSDictionary *paramMap = call.arguments[@"param"];
    ZegoReverbParam *param = [[ZegoReverbParam alloc] init];
    param.damping = [ZegoUtils floatValue:paramMap[@"damping"]];
    param.dryWetRatio = [ZegoUtils floatValue:paramMap[@"dryWetRatio"]];
    param.reverberance = [ZegoUtils floatValue:paramMap[@"reverberance"]];
    param.roomSize = [ZegoUtils floatValue:paramMap[@"roomSize"]];

    [[ZegoExpressEngine sharedEngine] setReverbParam:param];

    result(nil);
}

- (void)enableVirtualStereo:(FlutterMethodCall *)call result:(FlutterResult)result {

    BOOL enable = [ZegoUtils boolValue:call.arguments[@"enable"]];
    int angle = [ZegoUtils intValue:call.arguments[@"angle"]];

    [[ZegoExpressEngine sharedEngine] enableVirtualStereo:enable angle:angle];

    result(nil);
}


#pragma mark - IM

- (void)sendBroadcastMessage:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSString *roomID = call.arguments[@"roomID"];
    NSString *message = call.arguments[@"message"];

    [[ZegoExpressEngine sharedEngine] sendBroadcastMessage:message roomID:roomID callback:^(int errorCode, unsigned long long messageID) {
        result(@{
            @"errorCode": @(errorCode),
            @"messageID": @(messageID)
        });
    }];
}

- (void)sendBarrageMessage:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSString *roomID = call.arguments[@"roomID"];
    NSString *message = call.arguments[@"message"];

    [[ZegoExpressEngine sharedEngine] sendBarrageMessage:message roomID:roomID callback:^(int errorCode, NSString * _Nonnull messageID) {
        result(@{
            @"errorCode": @(errorCode),
            @"messageID": messageID
        });
    }];
}

- (void)sendCustomCommand:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSString *roomID = call.arguments[@"roomID"];
    NSString *command = call.arguments[@"command"];
    NSArray<NSDictionary *> *userListMap = call.arguments[@"toUserList"];

    NSMutableArray<ZegoUser *> *userListObject = nil;
    if (userListMap && userListMap.count > 0) {
        userListObject = [[NSMutableArray alloc] init];
        for(NSDictionary *userMap in userListMap) {
            ZegoUser *userObject = [[ZegoUser alloc] initWithUserID:userMap[@"userID"] userName:userMap[@"userName"]];
            [userListObject addObject:userObject];
        }
    }

    [[ZegoExpressEngine sharedEngine] sendCustomCommand:command toUserList:userListObject roomID:roomID callback:^(int errorCode) {
        result(@{
            @"errorCode": @(errorCode)
        });
    }];
}


#pragma mark - MediaPlayer

- (void)createMediaPlayer:(FlutterMethodCall *)call result:(FlutterResult)result {

    if (!self.mediaPlayerMap) {
        self.mediaPlayerMap = [NSMutableDictionary dictionary];
    }

    ZegoMediaPlayer *mediaPlayer = [[ZegoExpressEngine sharedEngine] createMediaPlayer];

    if (mediaPlayer) {
        NSNumber *index = mediaPlayer.index;

        [mediaPlayer setEventHandler:_eventHandler];
        self.mediaPlayerMap[index] = mediaPlayer;

        result(index);
    } else {
        result(@(-1));
    }
}

- (void)destroyMediaPlayer:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSNumber *index = call.arguments[@"index"];
    ZegoMediaPlayer *mediaPlayer = self.mediaPlayerMap[index];

    if (mediaPlayer) {
        [[ZegoExpressEngine sharedEngine] destroyMediaPlayer:mediaPlayer];
    }

    [self.mediaPlayerMap removeObjectForKey:index];

    result(nil);
}

- (void)mediaPlayerLoadResource:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSNumber *index = call.arguments[@"index"];
    ZegoMediaPlayer *mediaPlayer = self.mediaPlayerMap[index];

    if (mediaPlayer) {

        NSString *path = call.arguments[@"path"];

        [mediaPlayer loadResource:path callback:^(int errorCode) {
            result(@{
                @"errorCode": @(errorCode)
            });
        }];
    }
}

- (void)mediaPlayerStart:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSNumber *index = call.arguments[@"index"];
    ZegoMediaPlayer *mediaPlayer = self.mediaPlayerMap[index];

    [mediaPlayer start];

    result(nil);
}

- (void)mediaPlayerStop:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSNumber *index = call.arguments[@"index"];
    ZegoMediaPlayer *mediaPlayer = self.mediaPlayerMap[index];

    [mediaPlayer stop];

    result(nil);
}

- (void)mediaPlayerPause:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSNumber *index = call.arguments[@"index"];
    ZegoMediaPlayer *mediaPlayer = self.mediaPlayerMap[index];

    [mediaPlayer pause];

    result(nil);
}

- (void)mediaPlayerResume:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSNumber *index = call.arguments[@"index"];
    ZegoMediaPlayer *mediaPlayer = self.mediaPlayerMap[index];

    [mediaPlayer resume];

    result(nil);
}

- (void)mediaPlayerSeekTo:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSNumber *index = call.arguments[@"index"];
    ZegoMediaPlayer *mediaPlayer = self.mediaPlayerMap[index];

    if (mediaPlayer) {

        unsigned long long millisecond = [ZegoUtils unsignedLongLongValue:call.arguments[@"millisecond"]];

        [mediaPlayer seekTo:millisecond callback:^(int errorCode) {
            result(@{
                @"errorCode": @(errorCode)
            });
        }];
    }
}

- (void)mediaPlayerEnableRepeat:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSNumber *index = call.arguments[@"index"];
    ZegoMediaPlayer *mediaPlayer = self.mediaPlayerMap[index];

    BOOL enable = [ZegoUtils boolValue:call.arguments[@"enable"]];

    [mediaPlayer enableRepeat:enable];

    result(nil);
}

- (void)mediaPlayerEnableAux:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSNumber *index = call.arguments[@"index"];
    ZegoMediaPlayer *mediaPlayer = self.mediaPlayerMap[index];

    BOOL enable = [ZegoUtils boolValue:call.arguments[@"enable"]];

    [mediaPlayer enableAux:enable];

    result(nil);
}

- (void)mediaPlayerMuteLocal:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSNumber *index = call.arguments[@"index"];
    ZegoMediaPlayer *mediaPlayer = self.mediaPlayerMap[index];

    BOOL mute = [ZegoUtils boolValue:call.arguments[@"mute"]];

    [mediaPlayer muteLocal:mute];

    result(nil);
}

- (void)mediaPlayerSetVolume:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSNumber *index = call.arguments[@"index"];
    ZegoMediaPlayer *mediaPlayer = self.mediaPlayerMap[index];

    int volume = [ZegoUtils intValue:call.arguments[@"volume"]];

    [mediaPlayer setVolume:volume];

    result(nil);
}

- (void)mediaPlayerSetProgressInterval:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSNumber *index = call.arguments[@"index"];
    ZegoMediaPlayer *mediaPlayer = self.mediaPlayerMap[index];

    unsigned long long millisecond = [ZegoUtils unsignedLongLongValue:call.arguments[@"millisecond"]];

    [mediaPlayer setProgressInterval:millisecond];

    result(nil);
}

- (void)mediaPlayerGetVolume:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSNumber *index = call.arguments[@"index"];
    ZegoMediaPlayer *mediaPlayer = self.mediaPlayerMap[index];

    if (mediaPlayer) {
        int volume = mediaPlayer.volume;
        result(@(volume));
    } else {
        result(@(0));
    }
}

- (void)mediaPlayerGetTotalDuration:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSNumber *index = call.arguments[@"index"];
    ZegoMediaPlayer *mediaPlayer = self.mediaPlayerMap[index];

    if (mediaPlayer) {
        unsigned long long totalDuration = mediaPlayer.totalDuration;
        result(@(totalDuration));
    } else {
        result(@(0));
    }
}

- (void)mediaPlayerGetCurrentProgress:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSNumber *index = call.arguments[@"index"];
    ZegoMediaPlayer *mediaPlayer = self.mediaPlayerMap[index];

    if (mediaPlayer) {
        unsigned long long currentProgress = mediaPlayer.currentProgress;
        result(@(currentProgress));
    } else {
        result(@(0));
    }
}

- (void)mediaPlayerGetCurrentState:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSNumber *index = call.arguments[@"index"];
    ZegoMediaPlayer *mediaPlayer = self.mediaPlayerMap[index];

    if (mediaPlayer) {
        ZegoMediaPlayerState currentState = mediaPlayer.currentState;
        result(@(currentState));
    } else {
        result(@(0));
    }
}


#pragma mark - Record

- (void)startRecordingCapturedData:(FlutterMethodCall *)call result:(FlutterResult)result {

    NSDictionary *configMap = call.arguments[@"config"];

    ZegoDataRecordConfig *config = [[ZegoDataRecordConfig alloc] init];
    config.filePath = configMap[@"filePath"];
    config.recordType = (ZegoDataRecordType)[ZegoUtils intValue:configMap[@"recordType"]];

    int channel = [ZegoUtils intValue:call.arguments[@"channel"]];

    [[ZegoExpressEngine sharedEngine] startRecordingCapturedData:config channel:(ZegoPublishChannel)channel];

    result(nil);
}

- (void)stopRecordingCapturedData:(FlutterMethodCall *)call result:(FlutterResult)result {

    int channel = [ZegoUtils intValue:call.arguments[@"channel"]];

    [[ZegoExpressEngine sharedEngine] stopRecordingCapturedData:(ZegoPublishChannel)channel];

    result(nil);
}


#pragma mark - PlatformView Utils

- (void)destroyPlatformView:(FlutterMethodCall *)call result:(FlutterResult)result {

    int viewID = [ZegoUtils intValue:call.arguments[@"viewID"]];
    [[ZegoPlatformViewFactory sharedInstance] destroyPlatformView:@(viewID)];

    result(nil);
}


#pragma mark - TextureRenderer Utils

- (void)createTextureRenderer:(FlutterMethodCall *)call result:(FlutterResult)result {

    int viewWidth = [ZegoUtils intValue:call.arguments[@"width"]];
    int viewHeight = [ZegoUtils intValue:call.arguments[@"height"]];

    int64_t textureID = [[ZegoTextureRendererController sharedInstance] createTextureRenderer:_textureRegistry viewWidth:viewWidth viewHeight:viewHeight];

    result(@(textureID));
}

- (void)updateTextureRendererSize:(FlutterMethodCall *)call result:(FlutterResult)result {

    int64_t textureID = [ZegoUtils longLongValue:call.arguments[@"textureID"]];
    int viewWidth = [ZegoUtils intValue:call.arguments[@"width"]];
    int viewHeight = [ZegoUtils intValue:call.arguments[@"height"]];
    [[ZegoTextureRendererController sharedInstance] updateTextureRenderer:textureID viewWidth:viewWidth viewHeight:viewHeight];

    result(nil);
}

- (void)destroyTextureRenderer:(FlutterMethodCall *)call result:(FlutterResult)result {

    int64_t textureID = [ZegoUtils longLongValue:call.arguments[@"textureID"]];
    [[ZegoTextureRendererController sharedInstance] destroyTextureRenderer:textureID];

    result(nil);
}


@end
