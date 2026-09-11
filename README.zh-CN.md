# CAFE2 Docker 部署

[English](README.md)

支持 Central、Worker、Local 三种模式，包含 Portal 和 MySQL。
当前平台为 **linux/amd64**，属于测试候选版：已检查启动，真实数据索引和完整分析仍待验收。

## 使用发布镜像安装

到 [Releases](https://github.com/THU-ESIS/CAFE2_DOCKER/releases) 下载并解压部署包。
包内的 `images.lock` 固定镜像版本。电脑只需安装 Docker Engine + Compose v2，
或启用 Linux 容器的 Docker Desktop，不用另装 Java、Node、NCL。

进入解压目录，首次生成配置：

Windows PowerShell：
```powershell
powershell -NoProfile -File scripts/init-config.ps1
Copy-Item .env.example .env
```

Linux（需要 openssl）：
```sh
sh scripts/init-config.sh
cp .env.example .env
```

编辑 `.env`，将 `CAFE_DATA_HOST` 改为已有数据目录，例如 `D:/CAFE_DATA`
或 `/srv/CAFE_DATA`，然后运行：
```sh
docker compose --env-file .env --env-file images.lock --profile local pull
docker compose --env-file .env --env-file images.lock --profile local up -d --no-build
```

## 选择模式并使用

按需要替换上面的 `--profile local`：

| 参数 | 启动容器 | 网页部署模式 |
|---|---|---|
| local | MySQL、Local、Portal | LOCAL |
| central | MySQL、Central | DISTRIBUTED_CENTRAL |
| worker | MySQL、Worker | DISTRIBUTED_WORKER |
| all-in-one | MySQL、Central、Worker、Portal | 分别配置中心和工作节点 |

all-in-one 或 `--profile portal --profile worker` 时，在 `.env` 设置
`CAFE_PORTAL_CAFE_WORKER_URL=http://worker:8080/datamanager`。
不要在同一项目同时运行 local 和 worker，它们默认使用同一数据库。

Portal 地址为 http://localhost:4000。
节点部署页为 `http://localhost:端口/datamanager/web/deployment`：
Central 用 8081，Worker 用 8082，Local 用 8083。
首次提交部署表单，选择对应模式，填写可达的主机/IP、端口，Root Path 填 `datamanager`。
Worker 还要填写 Central 地址，两者必须互相可达。容器里的 localhost 只代表该容器。

在 Worker/Local 的 `/datamanager/web/parser` 页面提交 `/CAFE_DATA` 来索引数据。
数据保持原来的 `cmip5_data`、`cmip6_data`、`observation_data` 目录结构
（[原项目指南](https://github.com/THU-ESIS/CAFE2_NODE/blob/v1.11.0/README.md)）。
随后在 Portal 注册/登录、检索数据、提交分析并检查结果。
给浏览器使用的结果地址必须是浏览器能够访问的地址。

## 自行构建

```sh
git clone --recurse-submodules https://github.com/THU-ESIS/CAFE2_DOCKER.git
cd CAFE2_DOCKER
```

按前述步骤生成配置、编辑 `.env`，然后：
```sh
docker compose --profile local build
docker compose --profile local up -d --no-build
```

自行构建使用本地镜像标签，不加载 Release 的 images.lock。
源码提交由子模块固定；NCL 脚本已内置镜像；数据通过 `/CAFE_DATA` 只读挂载，不复制进镜像。

## 日常管理

用 `docker compose --profile local ps`、`logs --tail=100`、`stop` 查看状态、日志和停止服务。
镜像部署时，命令也加上 `--env-file .env --env-file images.lock`。
`secrets/` 是宿主机上的密码文件，运行时只读挂入容器，不要上传。
生成脚本遇到已有文件会停止；也可以手动填写配置。
脚本生成数据库凭据和应用密钥，不创建 Portal 登录账号。Windows 应限制该目录的文件访问权限。

MySQL 仅在空数据卷首次启动时初始化。升级前备份数据库、密码配置和任务结果。
**已有安装不要执行 `down -v`，它会删除命名数据卷。**
默认端口向宿主机网络开放，请先在受控网络测试；旧依赖仍需独立安全审查。

[维护、发布与离线传递](docs/MAINTAINING.md)
