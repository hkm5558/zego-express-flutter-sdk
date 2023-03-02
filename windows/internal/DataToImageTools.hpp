#include <variant>
#include <Windows.h>
#include <vector>
#include "ZegoTextureRendererController.h"

std::pair<long, BYTE *> CreateFromHBITMAP(HBITMAP hBitmap) {
    HDC hdc = GetDC(NULL);
    HDC memdc = CreateCompatibleDC(hdc);
    SelectObject(memdc, hBitmap);
    BITMAP bm;
    GetObject(hBitmap, sizeof(BITMAP), &bm);
    BITMAPINFO bi;
    bi.bmiHeader.biSize = sizeof(bi.bmiHeader);
    bi.bmiHeader.biWidth = bm.bmWidth;
    bi.bmiHeader.biHeight = bm.bmHeight;
    bi.bmiHeader.biPlanes = 1;
    bi.bmiHeader.biBitCount = 32;
    bi.bmiHeader.biCompression = BI_RGB;
    bi.bmiHeader.biSizeImage = 0;
    bi.bmiHeader.biXPelsPerMeter = bm.bmWidth;
    bi.bmiHeader.biYPelsPerMeter = bm.bmHeight;
    bi.bmiHeader.biClrUsed = 0;
    bi.bmiHeader.biClrImportant = 0;
    int bitsize = bm.bmWidth * bm.bmHeight * 4;
    BYTE *buff = new BYTE[sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFO) + bitsize];
    BYTE *tmpbuff = buff;
    RtlZeroMemory(buff, sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFO) + bitsize);
    BITMAPFILEHEADER bf;
    bf.bfType = 0x4d42;
    bf.bfSize = bitsize + 14 + sizeof(BITMAPINFOHEADER);
    bf.bfOffBits = sizeof(bi.bmiHeader) + sizeof(bf);
    bf.bfReserved1 = 0;
    bf.bfReserved2 = 0;
    RtlMoveMemory(tmpbuff, &bf, sizeof(BITMAPFILEHEADER));
    tmpbuff += sizeof(BITMAPFILEHEADER);
    RtlMoveMemory(tmpbuff, &bi, sizeof(BITMAPINFO));
    tmpbuff += sizeof(BITMAPINFO);
    GetDIBits(memdc, hBitmap, 0, bm.bmHeight, tmpbuff, &bi, DIB_PAL_COLORS);
    return std::pair(sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFO) + bitsize, buff);
}

std::pair<long, BYTE *> makeBtimap(const std::vector<uint8_t> *frame,
                                   std::pair<int32_t, int32_t> size) {
    auto bufferLen = frame->size();
    auto width = size.first;
    auto height = size.second;
    // rgba -> bgra  视频帧数据格式转换，windows只支持bgra
    std::vector<uint8_t> destBuffer_;
    {
        std::vector<uint8_t> srcBuffer_(*frame);
        destBuffer_.resize(bufferLen);
        FlutterDesktopPixel *src = reinterpret_cast<FlutterDesktopPixel *>(srcBuffer_.data());
        VideoFormatBGRAPixel *dst = reinterpret_cast<VideoFormatBGRAPixel *>(destBuffer_.data());

        for (uint32_t y = 0; y < height; y++) {
            for (uint32_t x = 0; x < width; x++) {
                uint32_t sp = (y * width) + x;
                {
                    dst[sp].r = src[sp].r;
                    dst[sp].g = src[sp].g;
                    dst[sp].b = src[sp].b;
                    dst[sp].a = 255;
                }
            }
        }
    }
    BITMAPINFO bi;
    bi.bmiHeader.biSize = sizeof(bi.bmiHeader);
    bi.bmiHeader.biWidth = width;
    bi.bmiHeader.biHeight = height;
    bi.bmiHeader.biPlanes = 1;
    bi.bmiHeader.biBitCount = 32;
    bi.bmiHeader.biCompression = BI_RGB;
    bi.bmiHeader.biSizeImage = 0;

    bi.bmiHeader.biXPelsPerMeter = width;
    bi.bmiHeader.biYPelsPerMeter = height;
    bi.bmiHeader.biClrUsed = 0;
    bi.bmiHeader.biClrImportant = 0;
    // int bitsize=height*height*3;
    BYTE *buff = new BYTE[sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFO) + bufferLen];
    BYTE *tmpbuff = buff;
    RtlZeroMemory(buff, sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFO) + bufferLen);
    BITMAPFILEHEADER bf;
    bf.bfType = 0x4d42;
    bf.bfSize = bufferLen + 14 + sizeof(BITMAPINFOHEADER);
    bf.bfOffBits = sizeof(bi.bmiHeader) + sizeof(bf);
    bf.bfReserved1 = 0;
    bf.bfReserved2 = 0;
    RtlMoveMemory(tmpbuff, &bf, sizeof(BITMAPFILEHEADER));
    tmpbuff += sizeof(BITMAPFILEHEADER);
    RtlMoveMemory(tmpbuff, &bi, sizeof(BITMAPINFO));
    tmpbuff += sizeof(BITMAPINFO);
    RtlMoveMemory(tmpbuff, destBuffer_.data(), bufferLen);
    return std::pair(sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFO) + bufferLen, buff);
}

std::pair<long, BYTE *> makeBtimapByBGRABuffer(unsigned char *buffer, unsigned int length,
                                   std::pair<int32_t, int32_t> size) {
    auto bufferLen = length;
    auto width = size.first;
    auto height = size.second;
    std::vector<uint8_t> destBuffer_(buffer, buffer + length);

    BITMAPINFO bi;
    bi.bmiHeader.biSize = sizeof(bi.bmiHeader);
    bi.bmiHeader.biWidth = width;
    bi.bmiHeader.biHeight = -height;
    bi.bmiHeader.biPlanes = 1;
    bi.bmiHeader.biBitCount = 32;
    bi.bmiHeader.biCompression = BI_RGB;
    bi.bmiHeader.biSizeImage = 0;

    bi.bmiHeader.biXPelsPerMeter = width;
    bi.bmiHeader.biYPelsPerMeter = height;
    bi.bmiHeader.biClrUsed = 0;
    bi.bmiHeader.biClrImportant = 0;
    // int bitsize=height*height*3;
    BYTE *buff = new BYTE[sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFO) + bufferLen];
    BYTE *tmpbuff = buff;
    RtlZeroMemory(buff, sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFO) + bufferLen);
    BITMAPFILEHEADER bf;
    bf.bfType = 0x4d42;
    bf.bfSize = bufferLen + 14 + sizeof(BITMAPINFOHEADER);
    bf.bfOffBits = sizeof(bi.bmiHeader) + sizeof(bf);
    bf.bfReserved1 = 0;
    bf.bfReserved2 = 0;
    RtlMoveMemory(tmpbuff, &bf, sizeof(BITMAPFILEHEADER));
    tmpbuff += sizeof(BITMAPFILEHEADER);
    RtlMoveMemory(tmpbuff, &bi, sizeof(BITMAPINFO));
    tmpbuff += sizeof(BITMAPINFO);
    RtlMoveMemory(tmpbuff, destBuffer_.data(), bufferLen);
    return std::pair(sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFO) + bufferLen, buff);
}
