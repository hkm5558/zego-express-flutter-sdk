import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../zego_express_api.dart';
import 'zego_express_impl.dart';
import 'zego_express_texture_renderer_impl.dart';
import 'zego_express_platform_view_impl.dart'
    if (dart.library.html) 'zego_express_platform_view_impl_web.dart';

class ZegoExpressCanvasViewImpl {
  /// Create a Canvas View and return the callback ZegoCanvas's viewID
  static Future<Widget?> createCanvasView(Function(int viewID) onViewCreated,
      {Key? key}) async {
    Widget? widget;
    if (ZegoExpressImpl.isEngineCreated) {
      /// web only has PlatformView, windows only has TextureRenderer
      bool usePlatformView =
          ZegoExpressImpl.enablePlatformView && !Platform.isWindows;
      usePlatformView = usePlatformView || kIsWeb;
      if (usePlatformView) {
        widget = ZegoExpressPlatformViewImpl.createPlatformView(onViewCreated);
      } else {
        ZegoExpressTextureRenderer().init();
        final int textureID =
            await ZegoExpressTextureRenderer().createTextureRenderer(0, 0);
        widget = ZegoTextureWidget(
          stream: ZegoExpressTextureRenderer().getStream(textureID),
          textureID: textureID,
          updateTextureRendererSize:
              ZegoExpressTextureRenderer().updateTextureRendererSize,
        );
        onViewCreated.call(textureID);
      }
    }

    return widget;
  }

  /// Destroys the Canvas View and releases its resources
  /// If it returns false, it's probably because the `textureID` to be destroyed doesn't exist or ZegoExpressEngine not create.
  static Future<bool> destroyCanvasView(int viewID) async {
    if (ZegoExpressImpl.isEngineCreated) {
      /// web only has PlatformView, windows only has TextureRenderer
      bool usePlatformView =
          ZegoExpressImpl.enablePlatformView && !Platform.isWindows;
      usePlatformView = usePlatformView || kIsWeb;
      if (usePlatformView) {
        return await ZegoExpressImpl.methodChannel
            .invokeMethod('destroyPlatformView', {'viewID': viewID});
      } else {
        ZegoExpressTextureRenderer().removeTexture(viewID);
        return ZegoExpressTextureRenderer().destroyTextureRenderer(viewID);
      }
    }
    return false;
  }
}