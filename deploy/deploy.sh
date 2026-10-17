#!/bin/bash
# ============================================
# PRDS 云服务器部署脚本
#
# 使用方式:
#   chmod +x deploy/deploy.sh
#   ./deploy/deploy.sh                    # 拉取 :latest 并部署
#   ./deploy/deploy.sh v1.0.0             # 拉取指定版本并部署
#
# 前置条件:
#   1. 云服务器已安装 docker + docker compose
#   2. 当前目录有 .env 文件
# ============================================

set -e

# ── 配置 ──────────────────────────────────────────
GHCR_OWNER="laoma528"
IMAGE_NAME="prds"
REGISTRY="ghcr.io"
FULL_IMAGE="${REGISTRY}/${GHCR_OWNER}/${IMAGE_NAME}"
TAG="${1:-latest}"
IMAGE="${FULL_IMAGE}:${TAG}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.prod.yml"

echo "============================================"
echo "  PRDS 云服务器部署"
echo "============================================"
echo "镜像: ${IMAGE}"
echo ""

# ── 1. 检查 Docker ────────────────────────────────
command -v docker &>/dev/null || { echo "❌ 未安装 Docker"; exit 1; }
docker compose version &>/dev/null || { echo "❌ 未安装 Docker Compose"; exit 1; }

# ── 2. 准备 .env ─────────────────────────────────
if [ ! -f .env ]; then
  if [ -f .env.example ]; then
    cp .env.example .env
    echo "⚠️  已从 .env.example 生成 .env，请修改以下必填项后重新运行:"
    echo "  APP_SECRET_KEY    - 应用密钥"
    echo "  POSTGRES_PASSWORD  - 数据库密码"
    echo "  ADMIN_PASSWORD    - 管理后台密码"
    echo "  PANSOU_BASE_URL   - PanSou 服务地址"
    exit 1
  else
    echo "❌ 当前目录缺少 .env 文件，且未找到 .env.example"
    exit 1
  fi
fi

# 检查生产环境必改项
for key in APP_SECRET_KEY POSTGRES_PASSWORD ADMIN_PASSWORD; do
  val=$(grep "^${key}=" .env | cut -d= -f2-)
  if [[ "$val" == "change-me-in-production" || "$val" == "prds_secret" || "$val" == "admin789" ]]; then
    echo "⚠️  警告: ${key} 仍为默认值，生产环境请务必修改"
  fi
done

# ── 3. 确认外部网络 ───────────────────────────────
PANSOU_NET="pansou_pansou-network"
ASTRBOT_NET="astrbot_astrbot_network"
for net in "$PANSOU_NET" "$ASTRBOT_NET"; do
  if ! docker network inspect "$net" &>/dev/null; then
    echo "⚠️  网络 '$net' 不存在，正在创建..."
    docker network create "$net" 2>/dev/null || true
  fi
done

# ── 4. 创建数据持久化目录 ─────────────────────────
mkdir -p ../data/postgresql ../data/redis

# ── 5. 拉取镜像 ───────────────────────────────────
echo "📥 拉取镜像 ${IMAGE}..."
docker pull "$IMAGE"

# ── 6. 停止旧容器 ─────────────────────────────────
if docker inspect prds &>/dev/null; then
  echo "🛑 停止旧容器..."
  docker rm -f prds
fi

# ── 7. 启动服务 ───────────────────────────────────
echo "🚀 启动 PRDS..."
export IMAGE
docker compose -f "$COMPOSE_FILE" up -d --pull always

# ── 8. 等待服务就绪 ───────────────────────────────
echo "等待服务启动..."
for i in $(seq 1 30); do
  if curl -sf http://localhost:8088/api/v1/health &>/dev/null; then
    break
  fi
  sleep 2
done

# ── 9. 验证部署 ───────────────────────────────────
echo ""
echo "============================================"
if curl -sf http://localhost:8088/api/v1/health &>/dev/null; then
  SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
  ADMIN_PWD=$(grep "^ADMIN_PASSWORD=" .env 2>/dev/null | cut -d= -f2- | tr -d '[:space:]' || echo "见 .env")
  echo "  ✅ 服务正常运行"
  echo "  API 地址:    http://${SERVER_IP}:8088"
  echo "  管理后台:    http://${SERVER_IP}:8088/admin"
  echo "  管理密码:    ${ADMIN_PWD}"
  echo "  查看日志:    docker logs -f prds"
else
  echo "  ❌ 服务可能未正常启动，请检查日志:"
  echo "  docker logs prds"
  exit 1
fi
echo "============================================"
