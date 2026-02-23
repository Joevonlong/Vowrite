# 安全清理检查清单

**每次发版前或涉及安全变更时必须执行。**

---

## API Key / 凭证

- [ ] API Key 仅存储在 macOS Keychain，不写入文件
- [ ] 代码中无硬编码的 API Key、Token、密码
- [ ] `.env` / `Secrets.swift` 在 `.gitignore` 中
- [ ] Git 历史中无泄露（执行: `git log -p | grep -i "sk-\|api.key\|secret\|token" | head -20`）

## 日志

- [ ] Release 构建中 `NSLog("[TextInjector]...")`  等调试日志已评估
  - 不输出用户语音内容
  - 不输出 API Key
  - 不输出完整请求/响应体
- [ ] 用户的语音文件录音后及时删除（`WhisperService` 中有 `removeItem`）

## 网络

- [ ] API 请求使用 HTTPS
- [ ] 无明文 HTTP 请求
- [ ] 请求中不携带不必要的用户信息

## 权限

- [ ] 仅请求必要权限（麦克风、辅助功能）
- [ ] 权限用途描述准确（`Info.plist` 中的 Usage Description）
- [ ] 未获得权限时功能优雅降级

## 剪贴板

- [ ] 粘贴后恢复原剪贴板内容
- [ ] 恢复延迟合理（当前 1.5 秒）

## 数据存储

- [ ] SwiftData 历史记录存储在用户本地，不上传
- [ ] UserDefaults 中不存储敏感信息
- [ ] 临时音频文件用后即删

## 依赖

- [ ] 无第三方依赖（当前纯 Swift + 系统框架）
- [ ] 如引入依赖，需审查其安全性

---

## 快速检查命令

```bash
# 检查代码中是否有硬编码密钥
grep -rn "sk-\|api_key\|apiKey.*=.*\"" VoxaApp/ --include="*.swift" | grep -v "Keychain\|placeholder\|example"

# 检查 Git 历史
git log -p | grep -i "sk-" | head -10

# 检查临时文件是否清理
ls /tmp/voxa_* 2>/dev/null && echo "WARNING: temp files exist" || echo "OK: no temp files"
```
