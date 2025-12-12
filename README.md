# 网络调试助手 (Network Debug Tool)

一款基于 Flutter 开发的 Android 网络调试工具，支持 TCP Server、TCP Client、UDP、MQTT Client 四种通信模式，适用于嵌入式开发、物联网调试等场景。

### 功能特性

#### 通信模式
- **TCP Server** - 支持多客户端连接（最多50个），可选择本机IP，支持单播/广播
- **TCP Client** - TCP 客户端连接，支持 Ping 测试
- **UDP** - UDP 通信，支持指定本地端口和目标地址
- **MQTT Client** - MQTT 3.1.1 协议，支持 WebSocket/WSS，订阅/发布消息

#### 数据格式
- 文本 (UTF-8)
- Hex (十六进制)
- Base64
- 二进制
- JSON (自动格式化)

#### 编码支持
- UTF-8
- GBK
- GB2312  
- ASCII

#### 其他功能
- 实时统计：发送/接收字节数、包数、连接时长
- 发送历史：保存最近10条发送记录，支持持久化
- MQTT配置持久化：自动保存连接参数和Topic历史
- 暂停/继续接收数据
- Ping 网络测试
- 消息区分：发送/接收消息颜色区分，带时间戳
- 自动滚动：新消息自动滚动，手动滚动时暂停

### 截图

<!-- 可添加应用截图 -->

### 开发环境

- Flutter SDK: ^3.10.3
- Dart SDK: ^3.10.3
- Android SDK: 36
- 目标平台: Android

### 依赖包

| 包名 | 版本 | 用途 |
|------|------|------|
| mqtt_client | ^10.6.0 | MQTT 客户端 |
| provider | ^6.1.1 | 状态管理 |
| shared_preferences | ^2.2.2 | 本地存储 |
| uuid | ^4.2.1 | UUID 生成 |
| fast_gbk | ^1.0.0 | GBK 编码支持 |

### 快速开始

#### 1. 克隆项目
```bash
git clone https://github.com/YOUR_USERNAME/net_debug_tool.git
cd net_debug_tool
```

#### 2. 获取依赖
```bash
flutter pub get
```

#### 3. 运行应用
```bash
flutter run
```

#### 4. 构建 APK
```bash
flutter build apk --release
```

### 使用说明

#### TCP Server
1. 选择本机 IP 地址和端口
2. 点击"启动服务器"
3. 等待客户端连接
4. 可选择单个客户端发送或广播

#### TCP Client
1. 输入目标主机地址和端口
2. 可先使用 Ping 测试连通性
3. 点击"连接"建立连接
4. 输入数据并发送

#### UDP
1. 设置本地监听端口
2. 设置目标地址和端口
3. 点击"启动"
4. 收发 UDP 数据报

#### MQTT Client
1. 配置服务器地址、端口
2. 可选配置 WebSocket、用户名密码
3. 连接后在"订阅"页签添加订阅主题
4. 在"发布"页签发送消息

### License

MIT License

### 贡献

欢迎提交 Issue 和 Pull Request！
