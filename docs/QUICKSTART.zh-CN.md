# CAFE2 测试部署说明

目前是待验收的测试候选版本。镜像是否已发布，以 GitHub Release 中实际提供的
`images.lock` 为准；文档中的镜像地址示例不代表已经发布。

## 首次安装

1. 安装 Docker Engine + Compose v2，或开启 Linux 容器的 Docker Desktop。
   当前验证的是 linux/amd64。Windows 在 PowerShell 中运行命令即可。
2. 源码构建使用 `git clone --recurse-submodules https://github.com/THU-ESIS/CAFE2_DOCKER.git`。
   使用镜像时下载对应 Release 的部署包，不需要在宿主机安装 Java、Node、NCL。
3. 进入仓库目录。Windows 运行 `powershell -NoProfile -File scripts/init-config.ps1`；
   Linux 运行 `sh scripts/init-config.sh`（需要 openssl）。脚本生成六个随机密码/配置
   文件，已有文件时会停止，不会覆盖已有数据库凭据。
4. 复制 `.env.example` 为 `.env`，设置 `CAFE_DATA_HOST` 为真实数据目录的绝对路径。
   Windows 可写 `D:/CAFE_DATA`。数据不会复制进镜像，容器内通过 `/CAFE_DATA` 只读访问。
5. 单机先选择 local：`docker compose --profile local build`，然后
   `docker compose --profile local up -d --no-build`。
   若使用 Release 镜像，运行 README 中显式加载 `images.lock` 的 pull/up 命令。

## 选择模式与完成部署

| 场景 | Compose 参数 | 网页部署选择 |
|---|---|---|
| 单机分析 | `--profile local` | `LOCAL` |
| 只安装中心节点 | `--profile central` | `DISTRIBUTED_CENTRAL` |
| 只安装工作节点 | `--profile worker` | `DISTRIBUTED_WORKER` |
| 本机中心+工作节点+Portal | `--profile all-in-one` | 分别部署 Central 和 Worker |

三个节点模式都保留，每种部署都带本机 MySQL 容器。Compose 启动容器后，仍需按原项目
流程提交网页部署表单；角色和节点地址保存在数据库中，通常不是每次启动都要重填。
不要在同一项目同时开启 local 和 worker，它们的默认 JDBC 指向同一个 CAFEWORKER 库。

Portal：`http://localhost:4000`。Central/Worker/Local 部署页面分别是
`http://localhost:8081/datamanager/web/deployment`、8082、8083。
表单 Root Path 填 `datamanager`。节点 IP/端口要填写实际可达地址；容器里的 localhost
只指该容器自身。跨机器的 Worker 要能访问 Central，Central 也要能回连 Worker。

all-in-one 或 portal+worker 时，在 `.env` 中把
`CAFE_PORTAL_CAFE_WORKER_URL` 改成 `http://worker:8080/datamanager`；local 模式用默认值。
这是后端容器间访问地址。提供给用户浏览器的结果链接仍需用浏览器能访问的主机地址。

## 真正验收哪些功能

部署完成后，到 Worker/Local 的 `/datamanager/web/parser` 提交 `/CAFE_DATA`。
文件按原项目要求放在 cmip5_data、cmip6_data、observation_data 下。
再到 Portal 注册/登录、查询已索引数据、提交一次 NCL 分析，并打开/下载结果。
最后重启容器，确认部署状态、数据索引和结果仍可用。网页能打开只代表启动检查通过。

使用 `docker compose --profile local ps` 和 `logs --tail=100` 查看状态；用
`docker compose --profile local stop` 停止。不要用 `down -v` 清理已有安装，
它会删除命名卷中的数据库和任务结果。数据库初始化脚本只在空卷首次启动时执行。

密码文件保存在宿主机 secrets 目录，运行时挂入容器，应用必须能读到密码才能连接数据库。
普通 Compose secrets 并不是加密保险箱；应限制宿主机文件权限，不上传这些文件。
当前保留的旧运行环境仍有安全维护欠账，先在受控测试网络验收。

镜像分发、离线打包及版本记录见 [RELEASING.md](RELEASING.md)。
