#pragma once

#include <memory>
#include <flutter/event_channel.h>

#include <ZegoExpressSDK.h>
using namespace ZEGO;

#define FTValue(varName) flutter::EncodableValue(varName)
#define FTMap flutter::EncodableMap
#define FTArray flutter::EncodableList

class ZegoExpressEngineEventHandler 
    : public EXPRESS::IZegoEventHandler
    //, public std::enable_shared_from_this<ZegoExpressEngineEventHandler>
{
public:
    ~ZegoExpressEngineEventHandler(){ std::cout << "event handler destroy" << std::endl;  }
    ZegoExpressEngineEventHandler() { std::cout << "event handler create" << std::endl; }

    /*static ZegoExpressEngineEventHandler & getInstance()
    {
        static ZegoExpressEngineEventHandler m_instance;
        return m_instance;
    }*/

    static std::shared_ptr<ZegoExpressEngineEventHandler>& getInstance()
    {
        if (!m_instance) {
            m_instance = std::shared_ptr<ZegoExpressEngineEventHandler>(new ZegoExpressEngineEventHandler);
        }

        return m_instance;
    }

    void setEventSink(std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> &&eventSink);
    void clearEventSink();
    //std::shared_ptr<ZegoExpressEngineEventHandler> getSharedPtr();

private:
    static std::shared_ptr<ZegoExpressEngineEventHandler> m_instance;

protected:
    void onDebugError(int errorCode, const std::string& funcName, const std::string& info) override;

    void onEngineStateUpdate(EXPRESS::ZegoEngineState state) override;

    void onRoomStateUpdate(const std::string& roomID, EXPRESS::ZegoRoomState state, int errorCode, const std::string& extendedData) override;

    void onRoomUserUpdate(const std::string& roomID, EXPRESS::ZegoUpdateType updateType, const std::vector<EXPRESS::ZegoUser>& userList) override;

    void onRoomOnlineUserCountUpdate(const std::string& roomID, int count) override;

    void onRoomStreamUpdate(const std::string& roomID, EXPRESS::ZegoUpdateType updateType, const std::vector<EXPRESS::ZegoStream>& streamList, const std::string& extendedData) override;

    void onRoomStreamExtraInfoUpdate(const std::string& roomID, const std::vector<EXPRESS::ZegoStream>& streamList) override;

    void onRoomExtraInfoUpdate(const std::string& roomID, const std::vector<EXPRESS::ZegoRoomExtraInfo>& roomExtraInfoList) override;

    void onPublisherStateUpdate(const std::string& streamID, EXPRESS::ZegoPublisherState state, int errorCode, const std::string& extendedData) override;

    void onPublisherQualityUpdate(const std::string& streamID, const EXPRESS::ZegoPublishStreamQuality& quality) override;

    void onPublisherCapturedAudioFirstFrame() override;

    //void onPublisherCapturedVideoFirstFrame(EXPRESS::ZegoPublishChannel channel) override;

    //void onPublisherRenderVideoFirstFrame(EXPRESS::ZegoPublishChannel channel) override;

    //void onPublisherVideoSizeChanged(int /*width*/, int /*height*/, EXPRESS::ZegoPublishChannel channel) override;

    //void onPublisherRelayCDNStateUpdate(const std::string& streamID, const std::vector<EXPRESS::ZegoStreamRelayCDNInfo>& infoList) override;

    void onPlayerStateUpdate(const std::string& streamID, EXPRESS::ZegoPlayerState state, int errorCode, const std::string& extendedData) override;

    void onPlayerQualityUpdate(const std::string& streamID, const EXPRESS::ZegoPlayStreamQuality& quality) override;

    void onPlayerMediaEvent(const std::string& streamID, EXPRESS::ZegoPlayerMediaEvent event) override;

    void onPlayerRecvAudioFirstFrame(const std::string& streamID) override;

    //void onPlayerRecvVideoFirstFrame(const std::string& streamID) override;

    //void onPlayerRenderVideoFirstFrame(const std::string& streamID) override;

    //void onPlayerVideoSizeChanged(const std::string& streamID, int width, int height) override;

    void onPlayerRecvSEI(const std::string& streamID, const unsigned char* data, unsigned int dataLength) override;

    //void onMixerRelayCDNStateUpdate(const std::string& /*taskID*/, const std::vector<EXPRESS::ZegoStreamRelayCDNInfo>& infoList) override;

    //void onMixerSoundLevelUpdate(const std::unordered_map<unsigned int, float>& soundLevels) override;

    void onAudioDeviceStateChanged(EXPRESS::ZegoUpdateType updateType, EXPRESS::ZegoAudioDeviceType deviceType, const EXPRESS::ZegoDeviceInfo& deviceInfo) override;

    void onAudioDeviceVolumeChanged(EXPRESS::ZegoAudioDeviceType deviceType, const std::string& deviceID, int volume) override;

    //void onVideoDeviceStateChanged(EXPRESS::ZegoUpdateType updateType, const EXPRESS::ZegoDeviceInfo& deviceInfo) override;

    void onCapturedSoundLevelUpdate(float soundLevel) override;

    void onRemoteSoundLevelUpdate(const std::unordered_map<std::string, float>& soundLevels) override;

    //void onCapturedAudioSpectrumUpdate(const EXPRESS::ZegoAudioSpectrum& audioSpectrum) override;

    //void onRemoteAudioSpectrumUpdate(const std::unordered_map<std::string, EXPRESS::ZegoAudioSpectrum>& audioSpectrums) override;

    void onDeviceError(int errorCode, const std::string& deviceName) override;

    void onRemoteCameraStateUpdate(const std::string& streamID, EXPRESS::ZegoRemoteDeviceState state) override;

    void onRemoteMicStateUpdate(const std::string& streamID, EXPRESS::ZegoRemoteDeviceState state) override;

private:
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> eventSink_;

private:
    //ZegoExpressEngineEventHandler() = default;
};