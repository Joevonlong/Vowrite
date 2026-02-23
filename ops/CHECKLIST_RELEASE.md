# 发布前检查清单

**每次发版前必须逐项确认。** 未全部通过不得发布。

版本号: __________ 日期: __________

---

## 代码质量

- [ ] 所有功能测试通过（见 PROCESS.md 测试矩阵）
- [ ] `swift build -c release` 编译无 warning（或 warning 已评估）
- [ ] 无 TODO/FIXME 遗留在关键路径上
- [ ] 新增代码有必要的注释

## 安全

- [ ] 过一遍 `CHECKLIST_SECURITY.md`
- [ ] Git 历史无敏感信息泄露
- [ ] Release 构建中调试日志已降级

## 版本信息

- [ ] `Info.plist` 中 `CFBundleShortVersionString` 已更新
- [ ] `AboutTab` 中版本号已更新
- [ ] `RELEASE_NOTES.md` 已更新
- [ ] `README.md` 版本历史已更新
- [ ] Git tag 已创建且与版本号一致

## 构建与打包

- [ ] `ops/scripts/release.sh` 执行成功
- [ ] DMG 文件可正常挂载、拖拽安装
- [ ] 安装后首次启动正常
- [ ] 安装后权限请求流程正常

## 签名与公证（有 Developer ID 时）

- [ ] 代码签名有效 (`codesign --verify`)
- [ ] 公证通过 (`xcrun notarytool`)
- [ ] Staple 完成 (`xcrun stapler staple`)
- [ ] 用户下载后双击可直接打开（无「未知开发者」警告）

## 发布

- [ ] GitHub Release 创建，附上 DMG
- [ ] Release Notes 内容准确
- [ ] 官网下载链接已更新（如有）
- [ ] 旧版本下载仍可访问

---

**签字确认:** __________ **日期:** __________
