# Motion Note 本机飞书授权中转

这套中转只用于个人测试。飞书 App Secret 只在本机进程内使用，不会写入 iPhone App、Git 或网页。

1. 在“下载”文件夹双击 `cloudflared-darwin-arm64.tgz`，解压出 `cloudflared`。
2. 在此文件夹的终端运行：`./start-feishu-test.sh`。
3. 脚本会显示临时 HTTPS 地址；将它加上 `/feishu/callback` 后，填入飞书开放平台的安全设置。
4. 按回车后，在终端隐藏输入 App Secret。
5. 在手机 Motion Note 的“训练档案”中粘贴同一个 HTTPS 地址，点“连接飞书”。

首次版本只验证 OAuth 授权是否成功。文档读取、令牌加密持久化会在这一步验证通过后添加。
