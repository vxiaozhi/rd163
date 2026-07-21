# 研发日志 · R&D Log —— 常用命令管理
# 直接运行 `make` 显示帮助

HUGO  ?= hugo
PORT  ?= 1313
BIND  ?= 127.0.0.1

.DEFAULT_GOAL := help

.PHONY: help serve build new clean update-theme

help: ## 显示所有可用命令
	@awk 'BEGIN {FS = ":.*##"; printf "\n\033[1m研发日志 · R&D Log\033[0m —— 常用命令\n\n"} \
	/^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@printf "\n  变量(均可覆盖,如 make serve PORT=8080 BIND=0.0.0.0):\n"
	@printf "  \033[33mHUGO\033[0m=%s  \033[33mPORT\033[0m=%s  \033[33mBIND\033[0m=%s\n\n" "$(HUGO)" "$(PORT)" "$(BIND)"

serve: ## 本地预览(含草稿,默认 127.0.0.1:1313)
	$(HUGO) server -D --buildDrafts --bind $(BIND) --port $(PORT)

build: ## 生产构建到 public/(Caddy 自动接管即部署)
	$(HUGO) --minify

new: ## 新建文章,用法: make new name=content/posts/code/foo.md
ifeq ($(name),)
	@echo "✗ 缺少文章路径。用法: make new name=content/posts/<分类>/<文件名>.md"; exit 1
else
	$(HUGO) new "$(name)"
endif

clean: ## 清理构建产物(public/ resources/ .hugo_build.lock)
	rm -rf public/ resources/_gen/ .hugo_build.lock

update-theme: ## 更新 DoIt 主题到最新
	cd themes/DoIt && git checkout main && git pull origin main
	@echo "✓ 主题已更新,请提交 themes/DoIt 与 .gitmodules 的指针变更"
