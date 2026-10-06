# 构建阶段
# --platform=$BUILDPLATFORM：Blazor WASM 的产物（.wasm 运行时 + IL dll + 静态资源）与 CPU 架构无关，
# 固定用「构建机架构」跑 dotnet publish，可避免 arm64 那条腿落进 QEMU 模拟（慢 5~10 倍且容易崩）。
# 最终运行镜像 nginx:alpine 仍按目标架构拉取，因此 amd64 / arm64 两份镜像都能正常产出。
FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:9.0 AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src

# 复制项目文件
COPY ["unattended-generator-web.csproj", "./"]
COPY ["Library/UnattendGenerator/UnattendGenerator.csproj", "Library/UnattendGenerator/"]

# 恢复依赖
RUN dotnet restore "unattended-generator-web.csproj"

# 复制所有源代码
COPY . .

# 发布项目
RUN dotnet publish "./unattended-generator-web.csproj" -c $BUILD_CONFIGURATION -o /app/publish

# 运行阶段 - 使用nginx服务静态文件
FROM nginx:alpine AS final
WORKDIR /usr/share/nginx/html

# 复制发布的WASM文件
COPY --from=build /app/publish/wwwroot .

# 复制nginx配置
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
