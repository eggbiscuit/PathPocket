# PathPocket 手机应用打包指南

本文档说明如何把 PathPocket 打包成 Android / iOS 手机应用。前端是 Flutter，编译成原生 App 后**通过网络连后端**（不把后端打进 App）。整体上线部署见 [`DEPLOYMENT.md`](DEPLOYMENT.md)，后端接口见 [`backend/API.md`](backend/API.md)。

当前工程信息：
- 包名 / Bundle ID：`com.example.pathpocket`（Android 与 iOS 一致）
- 版本号：`pubspec.yaml` 里的 `version: 1.0.0+1`（`1.0.0` 是 versionName，`+1` 是 versionCode / build number）
- Android `minSdk = 23`（Android 6.0 起）
- App 名称（Android label）：`pathpocket`

---

## 零、核心原则：后端地址必须构建时注入

App 里**不写死**后端地址，构建时用 `--dart-define` 注入：

```bash
--dart-define=BACKEND_BASE_URL=<后端公网 HTTPS 地址>
```

铁律：
- **必须是公网地址**（ngrok 或云主机 HTTPS），**绝不能用 `localhost`**——手机上的 localhost 是手机自己，连不到你的电脑。
- 不注入时默认 `http://localhost:8000`（见 `lib/core/config.dart`），只适合桌面端本地联调。
- ngrok 免费版地址每次重启会变，变了要用新地址重新构建。

> 已内置 `ngrok-skip-browser-warning` 请求头，原生 App 直连 ngrok 免费版不会被"Visit Site"拦截页挡住。

---

## 一、构建前准备

```bash
cd PathPocket
flutter pub get
# 生成 Drift 代码（首次检出或改过 app_database.dart 后必须）
dart run build_runner build --delete-conflicting-outputs
# 创建 config（gitignored）
cp lib/core/config.example.dart lib/core/config.dart
flutter doctor          # 确认 Android/iOS 工具链无红叉
```

---

## 二、Android 打包

### 1. 真机快速测试（热重载调试）

先确认设备已连上（手机开启 USB 调试）：

```bash
~/Library/Android/sdk/platform-tools/adb devices    # 看到设备号 + device
flutter devices                                     # Flutter 也应列出该设备
```

跑到手机（`<device-id>` 用上面查到的设备号）：

```bash
flutter run -d <device-id> \
  --dart-define=BACKEND_BASE_URL=https://你的后端地址.ngrok-free.app
```

改代码按 `r` 热重载、`R` 热重启（改根 widget / 依赖注入要用 `R`）。

### 2. 打 Release APK（直接发给别人装）

```bash
flutter build apk --release \
  --dart-define=BACKEND_BASE_URL=https://你的后端地址
# 产物：build/app/outputs/flutter-apk/app-release.apk
```

把 apk 发给任意安卓手机安装即可。小米 / HyperOS 需在设置里允许"USB 安装"或"未知来源安装"。

按 CPU 架构拆分体积更小的多个 APK：

```bash
flutter build apk --release --split-per-abi \
  --dart-define=BACKEND_BASE_URL=https://你的后端地址
# 产出 arm64-v8a / armeabi-v7a / x86_64 三个 APK，现代手机装 arm64-v8a
```

### 3. 打 App Bundle（上架 Google Play 用）

```bash
flutter build appbundle --release \
  --dart-define=BACKEND_BASE_URL=https://你的后端地址
# 产物：build/app/outputs/bundle/release/app-release.aab
```

### 4. 正式发布签名（重要）

当前 `android/app/build.gradle.kts` 的 release 用的是 **debug 签名**（第 34-37 行有 TODO）——能装能测，但**不能上架、也不适合正式分发**（每台机器 debug key 不同，升级会冲突）。正式发布前生成自己的签名：

```bash
# 1) 生成 keystore（放到仓库外，妥善保管，丢了就无法更新已上架应用）
keytool -genkey -v -keystore ~/pathpocket-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias pathpocket
```

```properties
# 2) 新建 android/key.properties（已被 .gitignore 忽略，切勿提交）
storePassword=你的keystore密码
keyPassword=你的key密码
keyAlias=pathpocket
storeFile=/Users/你/pathpocket-release.jks
```

```kotlin
// 3) android/app/build.gradle.kts：android { } 之前读取 key.properties
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// android { } 内，替换原来的 buildTypes.release：
signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String?
        keyPassword = keystoreProperties["keyPassword"] as String?
        storeFile = keystoreProperties["storeFile"]?.let { file(it) }
        storePassword = keystoreProperties["storePassword"] as String?
    }
}
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
    }
}
```

> 上架 Google Play 前还要把包名 `com.example.pathpocket` 改成你自己的唯一 ID（`com.example.` 前缀 Play 商店不接受）。改 `applicationId` + `namespace` + 各平台配置。

---

## 三、iOS 打包

iOS 打包必须在 **macOS + Xcode** 环境。

### 1. 真机测试

```bash
flutter devices    # 确认 iPhone 已连接（USB 或同网无线）
flutter run -d <iphone-device-id> \
  --dart-define=BACKEND_BASE_URL=https://你的后端地址
```

首次跑真机需要签名：用 Xcode 打开 `ios/Runner.xcworkspace` → 选中 Runner → Signing & Capabilities → 勾选 "Automatically manage signing" → Team 选你的 Apple ID（个人免费账号也行，但证书 7 天过期，到期重装即可）。

### 2. 打 Release / 归档上架

```bash
flutter build ipa --release \
  --dart-define=BACKEND_BASE_URL=https://你的后端地址
# 产物：build/ios/ipa/*.ipa
```

上架 App Store：用 Xcode 打开 `ios/Runner.xcworkspace` → Product → Archive → Distribute App，或用 `xcrun altool` / Transporter 上传。需要**付费 Apple Developer 账号**（$99/年）。

---

## 四、版本号管理

改 `pubspec.yaml`：

```yaml
version: 1.0.1+2   # 1.0.1 = 用户可见版本；+2 = 构建号（每次上架必须递增）
```

Android 的 versionCode、iOS 的 build number 都从这里读，无需分别改。

---

## 五、常见问题

- **注册/登录一直转圈** → `BACKEND_BASE_URL` 填成了 localhost 或后端没启动；填公网地址并确认 `curl <地址>/health` 返回 `{"status":"ok"}`。
- **登录返回一堆 HTML 解析失败** → ngrok 拦截页；本项目已加 `ngrok-skip-browser-warning` 头，若仍出现，确认用的是最新代码。
- **`adb devices` 显示 unauthorized** → 手机上"允许 USB 调试"弹窗没点允许，重插并勾选"一律允许"。
- **小米装 APK 被拦** → 开发者选项里开"USB 安装"，安装时允许"未知来源"。
- **iOS 真机 7 天后打不开** → 免费 Apple ID 证书过期，重新 `flutter run` 即可；长期用需付费开发者账号。
- **release APK 能装但升级冲突** → 还在用 debug 签名；按上面「正式发布签名」配置自己的 keystore。
- **ngrok 地址变了 App 连不上** → 免费版重启会换地址，用新地址重新 `flutter build`。
