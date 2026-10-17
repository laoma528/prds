#!/bin/bash
# ============================================
# PRDS 本地构建并推送镜像到 GitHub Container Registry (GHCR)
#
# 使用方式:
#   chmod +x deploy/build-push.sh
#   ./deploy/build-push.sh                 # 构建并推送 :latest
#   ./deploy/build-push.sh v1.2.0          # 构建并推送指定 tag + :latest
#
# 前置条件:
#   1. 本地已安装 docker
#   2. 已登录 GHCR（只需一次，Token 需 write:packages 权限）:
#      echo $GITHUB_TOKEN | docker login ghcr.io -u laoma528 --password-stdin
# ============================================

set -e

# ── 配置 ──────────────────────────────────────────
GHCR_OWNER="laoma528"
IMAGE_NAME="prds"
REGISTRY="ghcr.io"
FULL_IMAGE="${REGISTRY}/${GHCR_OWNER}/${IMAGE_NAME}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

TAG="${1:-latest}"

echo "============================================"
echo "  PRDS 镜像构建并推送"
echo "============================================"
echo "镜像: ${FULL_IMAGE}"
echo "标签: ${TAG}"
echo ""

# ── 1. 检查 Docker ────────────────────────────────
command -v docker &>/dev/null || { echo "❌ 未安装 Docker"; exit 1; }

# ── 2. 构建镜像 ───────────────────────────────────
cd "$PROJECT_ROOT"
echo "🔨 开始构建镜像..."
docker build -t "${FULL_IMAGE}:${TAG}" -f Dockerfile .

# 同时打 :latest 标签（除非本身就是 latest）
if [ "$TAG" != "latest" ]; then
  docker tag "${FULL_IMAGE}:${TAG}" "${FULL_IMAGE}:latest"
fi

# ── 3. 推送镜像 ───────────────────────────────────
echo "📤 推送到 GHCR..."
docker push "${FULL_IMAGE}:${TAG}"
if [ "$TAG" != "latest" ]; then
  docker push "${FULL_IMAGE}:latest"
fi

# ── 4. 输出结果 ───────────────────────────────────
echo ""
echo "============================================"
echo "  ✅ 构建并推送成功"
echo "============================================"
echo "镜像地址:"
echo "  ${FULL_IMAGE}:${TAG}"
[ "$TAG" != "latest" ] && echo "  ${FULL_IMAGE}:latest"
echo ""
echo "在云服务器上部署:"
echo "  ./deploy/deploy.sh ${TAG}"
