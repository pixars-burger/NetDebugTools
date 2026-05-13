# 网络调试助手 (Network Debug Tool)

基于 Flutter 的网络调试工具，面向嵌入式、物联网和协议联调场景。当前版本重点支持 Android 设备，提供多协议收发调试与 RTSP 拉流预览。

## 当前版本支持

### 协议调试
- TCP Server：多客户端接入、单播/广播发送、连接状态与收发统计。
- TCP Client：目标主机连接、发送/接收消息、支持 Ping 连通性测试。
- UDP：本地端口监听、目标地址发送、实时收发数据报。
- MQTT Client：MQTT 3.1.1，支持订阅/发布、Topic 管理、连接参数持久化。
- RTSP（Phase 1）：拉流预览、开始/停止控制、错误重连、基础 OSD 统计。

### 数据能力
- 数据格式：Text、Hex、Base64、Binary、JSON（自动格式化）。
- 文本编码：UTF-8、GBK、GB2312、ASCII。
- 消息能力：时间戳、发送/接收区分、自动滚动、暂停接收。

### RTSP（当前实现范围）
- 用户输入 RTSP 地址后可直接开始拉流。
- 默认 RTSP over TCP（优先稳定连通）。
- 基础状态统计：播放状态、首帧耗时、分辨率、重连次数、错误信息。
- 横屏优化：视频区域优先展示，控制按钮悬浮化，OSD 叠加。
- 地址持久化：保存上次拉流地址，旋转屏幕后可恢复。

## 开发环境

- Flutter SDK: ^3.10.3
- Dart SDK: ^3.10.3
- Android SDK: 36
- 主要目标平台: Android

## 主要依赖

| 包名 | 版本 | 用途 |
|------|------|------|
| mqtt_client | ^10.6.0 | MQTT 客户端 |
| provider | ^6.1.1 | 状态管理 |
| shared_preferences | ^2.2.2 | 本地配置持久化 |
| fast_gbk | ^1.0.0 | GBK 编码支持 |
| media_kit | ^1.1.11 | RTSP 播放核心 |
| media_kit_video | ^1.2.5 | 视频渲染控件 |
| media_kit_libs_video | ^1.0.5 | 播放底层库 |

## 快速开始

1) 获取代码
```bash
git clone https://github.com/YOUR_USERNAME/net_debug_tool.git
cd net_debug_tool
```

2) 安装依赖
```bash
flutter pub get
```

3) 运行应用（建议 Android 真机）
```bash
flutter run
```

4) 构建 APK
```bash
flutter build apk --release
```

## 基础使用

### TCP Server
1. 配置本机 IP 和端口并启动服务。
2. 等待客户端接入后进行单播或广播发送。

### TCP Client
1. 输入主机地址和端口，可先执行 Ping。
2. 建立连接后发送数据，观察接收和统计信息。

### UDP
1. 设置本地监听端口和目标地址端口。
2. 启动后进行 UDP 收发调试。

### MQTT Client
1. 配置 Broker 地址、端口及可选账号参数。
2. 连接后订阅 Topic，在发布区发送消息。

### RTSP
1. 进入 RTSP 标签页，点击设置按钮输入 `rtsp://...` 地址。
2. 点击开始拉流，实时查看视频与 OSD 统计。
3. 点击停止拉流结束会话，异常断流会自动尝试重连。

## 署名与致谢

本项目基于 Flutter 生态开发，未直接拷贝第三方仓库业务代码；运行能力依赖以下开源项目与仓库：

- Flutter: https://github.com/flutter/flutter
- Dart SDK: https://github.com/dart-lang/sdk
- provider: https://github.com/rrousselGit/provider
- mqtt_client: https://github.com/shamblett/mqtt_client
- shared_preferences (Flutter Plugins): https://github.com/flutter/plugins
- fast_gbk: https://github.com/CaiJingLong/flutter_fast_gbk
- media_kit / media_kit_video / media_kit_libs_video: https://github.com/media-kit/media-kit

感谢以上开源项目作者与社区贡献者。

## License

MIT License
