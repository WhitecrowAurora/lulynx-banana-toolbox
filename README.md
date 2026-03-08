# Lulynx's Banana Toolbox

A Flutter Android client for Nano Banana compatible image generation APIs.

一个基于 Nano Banana 兼容 API 的 Flutter Android 图像生成客户端。

## Features / 功能

- Text-to-image generation  
  文生图：输入提示词生成图片

- Image-to-image generation with reference images  
  图生图：上传参考图并结合提示词生成图片

- Multiple model support  
  多模型支持：`nano-banana` / `nano-banana-hd` / `nano-banana-2` / `3.1-flash`  
  The app can also fetch the model list from the API and automatically recognize Banana-related models.  
  也支持从 API 获取模型列表，并自动识别 Banana 系列模型

- Custom API endpoint  
  自定义端点：支持自定义 API 服务地址

- Multiple aspect ratios  
  多比例：支持 `1:1`, `4:3`, `16:9`, `9:16` 等多种比例

- Light and dark theme support  
  深色 / 浅色主题：跟随系统

## Tech Stack / 技术栈

- Flutter 3.x
- Riverpod
- Dio
- shared_preferences
- image_picker

## Getting Started / 使用方法

### 1. Configure API / 配置 API

Open the settings page and fill in:  
打开设置页面，填写：

- **API Endpoint / API 端点**: your API service address, for example `https://api.example.com`
- **API Key / API Key**: your API key

### 2. Select Model / 选择模型

| Model | Description |
|------|------|
| nano-banana | Base model |
| nano-banana-hd | 4K HD model |
| nano-banana-2 | Supports custom size (1K / 2K / 4K) |
| gemini-3.1-flash-image-preview | Latest model |

中文说明：

| 模型 | 说明 |
|------|------|
| nano-banana | 基础版 |
| nano-banana-hd | 4K 高清版 |
| nano-banana-2 | 支持自定义尺寸（1K / 2K / 4K） |
| gemini-3.1-flash-image-preview | 最新版 |

### 3. Generate Images / 生成图片

- Enter a prompt and tap the send button  
  输入提示词，点击发送按钮

- Optionally add reference images for image-to-image generation  
  可选：添加参考图进行图生图

## Build APK / 构建 APK

```bash
# Install dependencies
flutter pub get

# Build release APK
flutter build apk

# Build split APKs (smaller output)
flutter build apk --split-per-abi
```

APK output directory / APK 输出目录：

```text
build/app/outputs/flutter-apk/
```

## API Compatibility / API 格式

This app uses an OpenAI DALL-E compatible request format.  
本项目使用 OpenAI DALL-E 兼容格式。

```http
POST /v1/images/generations
Authorization: Bearer YOUR_API_KEY
Content-Type: application/json
```

Example request body / 请求示例：

```json
{
  "model": "nano-banana",
  "prompt": "a cute cat",
  "aspect_ratio": "1:1",
  "response_format": "url",
  "image": ["base64 or url"]
}
```

Notes / 说明：
- The `image` field is optional and is used for image-to-image generation.
- `image` 字段是可选的，用于图生图场景。

## License / 许可证

GPL-3.0
