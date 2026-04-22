# Nano Banana App

AI 图像生成 Android 客户端，基于 Nano Banana API（OpenAI DALL-E 兼容格式）。

## 功能

- **文生图**: 输入提示词生成图片
- **图生图**: 上传参考图 + 提示词生成图片
- **多模型支持**: nano-banana / nano-banana-hd / nano-banana-2 / 3.1-flash
- **自定义端点**: 支持自定义 API 服务地址
- **多比例**: 1:1, 4:3, 16:9, 9:16 等多种比例
- **深色/浅色主题**: 跟随系统

## 技术栈

- Flutter 3.x
- Riverpod (状态管理)
- Dio (HTTP 客户端)
- shared_preferences (本地存储)
- image_picker (图片选择)

## 使用方法

### 1. 配置 API

打开设置页面，填写：
- **API 端点**: 你的 API 服务地址（如 `https://api.example.com`）
- **API Key**: 你的 API 密钥

### 2. 选择模型

| 模型 | 说明 |
|------|------|
| nano-banana | 基础版 |
| nano-banana-hd | 4K 高清版 |
| nano-banana-2 | 支持自定义尺寸 (1K/2K/4K) |
| gemini-3.1-flash-image-preview | 最新版 |

### 3. 生成图片

- 输入提示词，点击发送按钮
- 可选：添加参考图进行图生图

## 构建 APK

```bash
# 获取依赖
flutter pub get

# 构建 release APK
flutter build apk

# 或分架构构建（文件更小）
flutter build apk --split-per-abi
```

APK 输出目录: `build/app/outputs/flutter-apk/`

## API 格式

使用 OpenAI DALL-E 兼容格式:

```
POST /v1/images/generations
Authorization: Bearer YOUR_API_KEY
Content-Type: application/json

{
  "model": "nano-banana",
  "prompt": "a cute cat",
  "aspect_ratio": "1:1",
  "response_format": "url",
  "image": ["base64或url"]  // 可选，图生图时使用
}
```

## 项目结构

```
lib/
├── main.dart                    # 入口
├── models/
│   ├── api_config.dart          # API 配置模型
│   └── generation_result.dart   # 生成结果模型
├── providers/
│   └── providers.dart           # Riverpod providers
├── screens/
│   ├── home_screen.dart         # 主页/生成页
│   └── settings_screen.dart     # 设置页
└── services/
    ├── nano_banana_service.dart # API 服务
    └── storage_service.dart     # 本地存储服务
```
