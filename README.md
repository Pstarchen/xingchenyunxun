# 星辰云巡 HarmonyOS App

同步开源鸿蒙版星辰云巡 App，提供服务器监控空间管理、设备诊断、历史趋势、告警同步和移动端通知能力。

## 开发环境

- DevEco Studio
- HarmonyOS SDK 6.1.0（API 23）
- Hvigor / OHPM

## 构建

1. 使用 DevEco Studio 打开项目根目录。
2. 等待依赖同步完成。
3. 在 DevEco Studio 中为本地构建配置自己的 HarmonyOS 签名证书。
4. 选择 `entry` 模块运行或构建。

签名证书、私钥、密码和本机配置不会随仓库分发。首次打开项目时，DevEco Studio 会根据本机环境生成 `local.properties`；签名材料请在本地管理，不要提交到 Git。

## 目录

- `entry/src/main/ets`：HarmonyOS 应用源码
- `entry/src/test`：本地单元测试
- `素材`：应用宣传图和实机截图
- `mock-monitor.mjs`：本地接口模拟数据

## 隐私与安全

仓库已排除 `local.properties`、`.deveco`、构建输出、依赖缓存以及 `*.p12`、`*.p7b`、`*.cer`、`*.jks` 等签名材料。连接服务器时使用你自己的地址和 API Token；不要在源码、测试数据或提交信息中写入真实凭据。

## 开源同步

本项目用于同步开源鸿蒙版星辰云巡 App。GitHub 仓库：<https://github.com/Pstarchen/xingchenyunxun>
Gitee 仓库：<https://gitee.com/starchen520/xingchenyunxun>
