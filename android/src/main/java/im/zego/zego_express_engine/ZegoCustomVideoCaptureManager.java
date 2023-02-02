package im.zego.zego_express_engine;

import android.graphics.SurfaceTexture;

import java.nio.ByteBuffer;
import java.util.HashMap;
import java.util.logging.Handler;

import im.zego.zegoexpress.ZegoExpressEngine;
import im.zego.zegoexpress.callback.IZegoCustomVideoCaptureHandler;
import im.zego.zegoexpress.constants.ZegoPublishChannel;
import im.zego.zegoexpress.constants.ZegoVideoFrameFormat;
import im.zego.zegoexpress.constants.ZegoVideoMirrorMode;
import im.zego.zegoexpress.entity.ZegoTrafficControlInfo;
import im.zego.zegoexpress.entity.ZegoVideoFrameParam;

public class ZegoCustomVideoCaptureManager extends IZegoCustomVideoCaptureHandler {

    private volatile static ZegoCustomVideoCaptureManager singleton;

    private ZegoVideoFrameParam mParam;
    private ZegoVideoMirrorMode mMirrorMode;

    private static IZegoFlutterCustomVideoCaptureHandler mHander;

    public ZegoCustomVideoCaptureManager() {

    }

    /**
     * Get the custom video capture manager instance
     */
    public static synchronized ZegoCustomVideoCaptureManager getInstance() {
        if (singleton == null) {
            singleton = new ZegoCustomVideoCaptureManager();
        }
        return singleton;
    }

    /**
     * Sets the event callback handler for custom video capture.
     * 
     * Developers need to pass in the callback object that implements [ZegoCustomVideoCaptureDelegate] and open [enableCustomVideoCapture] in the Dart API to make the custom capture module take effect.
     * When the developer calls [startPreview]/[stopPreview] or [startPublishingStream]/[stopPublishingStream] in the Dart API, the SDK will notify the developer  the start/stop of the custom video capture, and the developer can receive [onStart] and [onStop] Start and stop the external input source after the notification.
     * This API call is set at any time before [enableCustomVideoCapture] is enabled in Dart
     * @param handler the callback object that implements the [ZegoCustomVideoCaptureDelegate]
     */
    public void setCustomVideoCaptureHandler(IZegoFlutterCustomVideoCaptureHandler handler) {
        mHander = handler;
    }

    /**
     * Sets the video mirroring mode.
     *
     * This function can be called to set whether the local preview video and the published video have mirror mode enabled.
     *
     * @param mode Mirror mode for previewing or publishing the stream. 0: Only preview mirror. 1: Both preview and publish mirror. 2: No Mirror. 3. Only publish mirror. No mirror by default.
     * @param channel publish channel, It is consistent with Dart API
     */
    public void setVideoMirrorMode(int mode, int channel) {
        mMirrorMode = ZegoVideoMirrorMode.getZegoVideoMirrorMode(mode);
        ZegoExpressEngine.getEngine().setVideoMirrorMode(mMirrorMode, ZegoPublishChannel.getZegoPublishChannel(channel));
    }

    /**
     * Sends the video frames (Raw Data) produced by custom video capture to the SDK.
     *
     * This api need to be start called after the [onStart] callback notification and to be stop called call after the [onStop] callback notification.
     *
     * @param data video frame data
     * @param dataLength video frame data length
     * @param param video frame param
     * @param referenceTimeMillisecond video frame reference time, UNIX timestamp, in milliseconds.
     * @param channel publish channel, It is consistent with Dart API
     */
    public void sendRawData(ByteBuffer data, int dataLength, VideoFrameParam param, long referenceTimeMillisecond, PublishChannel channel) {
        if(mParam == null) {
            mParam = new ZegoVideoFrameParam();
        }
        mParam.format = ZegoVideoFrameFormat.getZegoVideoFrameFormat(param.format.value());
        mParam.width = param.width;
        mParam.height = param.height;
        mParam.rotation = param.rotation;
        mParam.strides[0] = param.strides[0];
        mParam.strides[1] = param.strides[1];
        mParam.strides[2] = param.strides[2];
        mParam.strides[3] = param.strides[3];

        ZegoExpressEngine.getEngine().sendCustomVideoCaptureRawData(data, dataLength, mParam, referenceTimeMillisecond, ZegoPublishChannel.getZegoPublishChannel(channel.value()));

        // Android 使用 Texture Renderer 和 PlatformView 行为一致
    }

    /**
     * Gets the SurfaceTexture instance.
     *
     * @param channel publish channel, It is consistent with Dart API
     * @return SurfaceTexture instance
     */
    public SurfaceTexture getSurfaceTexture(PublishChannel channel) {
        return ZegoExpressEngine.getEngine().getCustomVideoCaptureSurfaceTexture(ZegoPublishChannel.getZegoPublishChannel(channel.value()));
    }

    /**
     * Sends the video frames (Texture Data) produced by custom video capture to the SDK.
     *
     * This api need to be start called after the [onStart] callback notification and to be stop called call after the [onStop] callback notification.
     *
     * @param textureID texture ID
     * @param width Video frame width
     * @param height Video frame height
     * @param referenceTimeMillisecond Timestamp of this video frame
     * @param channel publish channel, It is consistent with Dart API
     */
    public void sendGLTextureData(int textureID, int width, int height, long referenceTimeMillisecond, PublishChannel channel) {
        ZegoExpressEngine.getEngine().sendCustomVideoCaptureTextureData(textureID, width, height, referenceTimeMillisecond, ZegoPublishChannel.getZegoPublishChannel(channel.value()));
    }

    /**
     * Internal function. Ignore this.
     */
    @Override
    public void onStart(ZegoPublishChannel channel) {
        //ZegoCustomVideoCaptureClient client = new ZegoCustomVideoCaptureClientImpl(channel);
        //mClients.put(channel.value(), client);

        //IZegoCustomVideoCaptureCallback callback = mHandlers.get(channel.value());
        if(mHander != null) {
            mHander.onStart(PublishChannel.getZegoPublishChannel(channel.value()));
        }
    }

    /**
     * Internal function. Ignore this.
     */
    @Override
    public void onStop(ZegoPublishChannel channel) {
        //mClients.remove(channel.value());
        //IZegoCustomVideoCaptureCallback callback = mHandlers.get(channel.value());
        if(mHander != null) {
            mHander.onStop(PublishChannel.getZegoPublishChannel(channel.value()));
        }
    }

    @Override
    public void onEncodedDataTrafficControl(ZegoTrafficControlInfo trafficControlInfo, ZegoPublishChannel channel) {
        if(mHander != null) {
            TrafficControlInfo trafficControlInfo1 = new TrafficControlInfo();
            trafficControlInfo1.bitrate = trafficControlInfo.bitrate;
            trafficControlInfo1.fps = trafficControlInfo.fps;
            trafficControlInfo1.height = trafficControlInfo.height;
            trafficControlInfo1.width = trafficControlInfo.width;
            mHander.onEncodedDataTrafficControl(trafficControlInfo1, PublishChannel.getZegoPublishChannel(channel.value()));
        }
    }
}
