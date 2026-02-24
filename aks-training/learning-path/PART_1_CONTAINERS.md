# Learning Path Part 1: Containers Deep Dive

> **Goal:** Master containerization from Dockerfile creation to production-ready images

---

## 🏗️ Foundational Structure: What You Need and Why

Before writing a single line of application code destined for a container, you need to understand the **foundational files and structures** that make containerization work. These aren't optional extras — they are the load-bearing walls of your container workflow. Missing or misconfiguring any one of them will result in bloated images, slow builds, failed deployments, or security vulnerabilities in production.

### The Essential File Structure

```
my-app/
├── Dockerfile              # The blueprint — tells Docker how to build your image
├── .dockerignore           # The filter — prevents unnecessary files entering the build context
├── docker-compose.yml      # The local orchestrator — runs multi-container setups locally
├── MyApp.csproj            # (or requirements.txt / package.json) — the dependency manifest
└── src/
    └── ...                 # Your application source code
```

### Why Each File Matters

| File | Role | What Happens Without It |
|------|------|--------------------------|
| `Dockerfile` | Defines the exact build recipe: base image, dependencies, code copy, and startup command | Without it, Docker has nothing to build. There is no image, no container. |
| `.dockerignore` | Prevents Git history, local secrets (`.env`), IDE files, and build artefacts from bloating the build context sent to the Docker daemon | Without it, every build sends gigabytes of irrelevant data, slowing builds significantly and risking leaking secrets into the image |
| `docker-compose.yml` | Lets you run your app alongside its dependencies (database, cache, message queue) locally with a single command | Without it, developers must manually run and link containers, leading to "works on my machine" syndrome |
| Dependency manifest (`.csproj`, `requirements.txt`, `package.json`) | Lists every library your app needs, pinned to specific versions | Without it pinned and copied *before* your source code, Docker cannot cache the expensive `restore`/`install` step—rebuilding every time any file changes |

### The Mental Model: Why Order Matters in a Dockerfile

Docker builds images in **layers**, and each layer is cached. The golden rule is: **copy what changes least, first**. Your dependency manifest changes far less often than your source code. If you copy dependencies first and install them, Docker will reuse that cached layer on every subsequent build — making rebuilds 10x faster.

```
[Layer 1] Base OS image         ← almost never changes → always cached
[Layer 2] System packages       ← rarely changes → usually cached
[Layer 3] Dependency manifest   ← changes when you add libraries → cached most times
[Layer 4] Install dependencies  ← expensive operation → cached when Layer 3 unchanged
[Layer 5] Application source    ← changes every commit → always rebuilt
[Layer 6] Run command           ← metadata, no layer cost
```

This ordering isn't just a best practice — in a team of 10 engineers committing several times a day, poor layer ordering can add **hours of wasted CI/CD time** across the team every week.

### The Multi-Stage Build Imperative

A single-stage Dockerfile that uses an SDK image in production is one of the most common beginner mistakes. The SDK (e.g., `.NET SDK`, `node:lts`) contains compilers, package managers, debug tools, and documentation — none of which your running application needs. The consequence:

- **Security surface**: Every tool in the image is a potential attack vector
- **Image size**: SDK images are 600–800MB vs a runtime image at 100–220MB
- **Pull time**: Larger images slow down cold starts in autoscaling scenarios

Multi-stage builds solve this by using a builder stage (with the full SDK) and a final stage (with only the runtime). Only the compiled output crosses the stage boundary. **This pattern is mandatory for any production workload.**

---

## 1. Write a Dockerfile for Your App

### Concept: What is a Dockerfile?

A Dockerfile is a text file containing instructions to build a container image. Think of it as a recipe that describes:
- Base operating system
- Dependencies to install
- Application code to copy
- Command to run

### Basic Structure

```dockerfile
# 1. Base Image - Starting point
FROM python:3.11-slim

# 2. Working Directory - Where commands run
WORKDIR /app

# 3. Copy Dependencies - Leverage caching
COPY requirements.txt .

# 4. Install Dependencies
RUN pip install --no-cache-dir -r requirements.txt

# 5. Copy Application Code
COPY . .

# 6. Expose Port - Documentation
EXPOSE 8080

# 7. Run Command
CMD ["python", "app.py"]
```

### Hands-On Exercise: Create Your First Dockerfile

**Step 1: Create a Simple .NET 8 Web API**

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/", () => "Hello from Container!");
app.MapGet("/health", () => Results.Ok(new { status = "healthy" }));

app.Run();
```

```xml
<!-- MyApp.csproj -->
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
</Project>
```

**Step 2: Write the Dockerfile**

```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["MyApp.csproj", "./"]
RUN dotnet restore "MyApp.csproj"
COPY . .
RUN dotnet build "MyApp.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "MyApp.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "MyApp.dll"]
```

**Step 3: Build and Run**

```bash
# Build the image
docker build -t my-first-app:v1 .

# Run the container
docker run -p 8080:8080 -e ASPNETCORE_URLS=http://+:8080 my-first-app:v1

# Test it
curl http://localhost:8080
curl http://localhost:8080/health
```

### Industry Examples

**Netflix Tech Blog - Container Best Practices:**
- [Titus: Container Management Platform](https://netflixtechblog.com/titus-the-netflix-container-management-platform-is-now-open-source-f868c9fb5436)

**Google's Distroless Images:**
- GitHub: https://github.com/GoogleContainerTools/distroless
- Why: Minimal attack surface, no shell, no package manager

**Spotify's Dockerfile Best Practices:**
- Use specific base image tags (not `latest`)
- Minimize layers
- Use `.dockerignore` to exclude unnecessary files

---

## 2. Build and Run Locally

### Understanding the Build Process

**Build Context:**
```bash
docker build -t myapp:v1 .
#                        ↑
#                   Build context (current directory)
```

Docker sends all files in this directory to the Docker daemon. Use `.dockerignore` to exclude files:

```
# .dockerignore
.git
.venv
__pycache__
*.pyc
node_modules
.env
```

### Build Commands Deep Dive

```bash
# Basic build
docker build -t myapp:v1 .

# Build with build arguments
docker build --build-arg VERSION=1.2.3 -t myapp:v1 .

# Build for different platform (M1 Mac → Linux)
docker build --platform linux/amd64 -t myapp:v1 .

# No cache (force rebuild)
docker build --no-cache -t myapp:v1 .

# Multi-stage build (production)
docker build --target production -t myapp:v1 .
```

### Run Commands Deep Dive

```bash
# Basic run
docker run myapp:v1

# Run with port mapping
docker run -p 8080:8080 myapp:v1

# Run in background (detached)
docker run -d -p 8080:8080 myapp:v1

# Run with environment variables
docker run -e DB_HOST=localhost -p 8080:8080 myapp:v1

# Run with volume mount (for development)
docker run -v $(pwd):/app -p 8080:8080 myapp:v1

# Run with resource limits
docker run --memory=512m --cpus=0.5 -p 8080:8080 myapp:v1

# Run interactively (for debugging)
docker run -it myapp:v1 /bin/sh
```

### Debugging Containers

```bash
# View running containers
docker ps

# View all containers (including stopped)
docker ps -a

# View logs
docker logs <container-id>

# Follow logs (like tail -f)
docker logs -f <container-id>

# Execute command in running container
docker exec -it <container-id> /bin/sh

# Inspect container details
docker inspect <container-id>

# View resource usage
docker stats
```

### External Resources

**Official Docker Documentation:**
- Dockerfile Reference: https://docs.docker.com/engine/reference/builder/
- Best Practices: https://docs.docker.com/develop/dev-best-practices/

**Interactive Learning:**
- Play with Docker: https://labs.play-with-docker.com/
- Docker 101 Tutorial: https://www.docker.com/101-tutorial/

**Books:**
- "Docker Deep Dive" by Nigel Poulton
- "Docker in Action" by Jeff Nickoloff

---

## 3. Understand Layers and Caching

### How Docker Layers Work

Each instruction in a Dockerfile creates a layer:

```dockerfile
FROM python:3.11-slim      # Layer 1: Base image
WORKDIR /app               # Layer 2: Create directory
COPY requirements.txt .    # Layer 3: Copy file
RUN pip install ...        # Layer 4: Install packages
COPY . .                   # Layer 5: Copy app code
CMD ["python", "app.py"]   # Layer 6: Metadata (no layer)
```

**View Layers:**
```bash
docker history myapp:v1
```

### Layer Caching Strategy

Docker caches each layer. If a layer hasn't changed, Docker reuses it.

**❌ Bad Example (Cache Busting):**
```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:8.0
COPY . .                    # Changes every time you edit code
RUN dotnet restore          # Restores every time!
RUN dotnet build
CMD ["dotnet", "run"]
```

**✅ Good Example (Cache Optimization):**
```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:8.0
WORKDIR /src
COPY ["MyApp.csproj", "./"]  # Only changes when dependencies change
RUN dotnet restore           # Cached unless .csproj changes
COPY . .                     # Code changes don't invalidate restore
RUN dotnet build -c Release
CMD ["dotnet", "run"]
```

### Multi-Stage Builds

**Problem:** Build tools (SDK, compilers) bloat production images.

**Solution:** Multi-stage builds

```dockerfile
# Stage 1: Build
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["MyApp.csproj", "./"]
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app/publish

# Stage 2: Production (Runtime only)
FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
COPY --from=build /app/publish .
USER $APP_UID
ENTRYPOINT ["dotnet", "MyApp.dll"]
```

**Result:**
- Build stage: 750MB (has .NET SDK)
- Production stage: 220MB (only .NET runtime + compiled app)

### Advanced: BuildKit and Cache Mounts

Enable BuildKit for better caching:

```bash
export DOCKER_BUILDKIT=1
```

```dockerfile
# syntax=docker/dockerfile:1

FROM python:3.11-slim

# Cache pip packages across builds
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt
```

### Real-World Example: Optimizing a .NET App

**Before (750MB - SDK image):**
```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:8.0
WORKDIR /app
COPY . .
RUN dotnet restore
RUN dotnet build
CMD ["dotnet", "run"]
```

**After (220MB - Runtime-only):**
```dockerfile
# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["*.csproj", "./"]
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app/publish /p:UseAppHost=false

# Production stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine
WORKDIR /app
COPY --from=build /app/publish .
USER $APP_UID
ENTRYPOINT ["dotnet", "MyApp.dll"]
```

**Even Better (120MB - AOT Compiled):**
```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["*.csproj", "./"]
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app/publish -r linux-musl-x64 --self-contained

FROM mcr.microsoft.com/dotnet/runtime-deps:8.0-alpine
WORKDIR /app
COPY --from=build /app/publish .
USER $APP_UID
ENTRYPOINT ["./MyApp"]
```

### Industry Examples

**Microsoft's .NET Container Optimization:**
- Reduced image size from 750MB to 110MB with Alpine
- Blog: https://devblogs.microsoft.com/dotnet/securing-containers-with-rootless

**Stack Overflow's .NET Containers:**
- Multi-stage builds for all services
- Standardized base images
- 70% reduction in image size

**Shopify's Container Optimization:**
- Reduced image size from 1.8GB to 180MB
- Build time: 15min → 2min
- Blog: https://shopify.engineering/optimizing-docker-images-ruby

### External Resources

**Docker Layer Caching:**
- Docker Docs: https://docs.docker.com/build/cache/
- BuildKit: https://github.com/moby/buildkit

**Image Optimization Tools:**
- Dive (analyze layers): https://github.com/wagoodman/dive
- Docker Slim: https://github.com/slimtoolkit/slim

**Security Scanning:**
- Trivy: https://github.com/aquasecurity/trivy
- Snyk: https://snyk.io/product/container-vulnerability-management/

---

## Practical Exercise: Build a Production-Ready Image

### Challenge: Optimize This Dockerfile

**Given (Bad):**
```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:latest
COPY . /app
WORKDIR /app
RUN dotnet restore
RUN dotnet build
CMD dotnet run
```

**Problems:**
1. Uses `latest` tag (not reproducible)
2. Large base image (SDK instead of runtime)
3. Runs as root
4. No layer caching for dependencies
5. Includes build tools in production

**Your Task:** Rewrite this Dockerfile following best practices.

**Solution:**
```dockerfile
# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project file and restore (caching)
COPY ["MyApp.csproj", "./"]
RUN dotnet restore

# Copy source and build
COPY . .
RUN dotnet publish -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine
WORKDIR /app

# Copy published app
COPY --from=build /app/publish .

# Use non-root user (built-in)
USER $APP_UID

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Run application
ENTRYPOINT ["dotnet", "MyApp.dll"]
```

---

## Next Steps

✅ **Completed:** Dockerfile creation, building, and optimization

➡️ **Next:** [Part 2: Kubernetes Basics](PART_2_KUBERNETES_BASICS.md)

### Additional Practice

1. **Containerize Your Own App:** Take an existing project and write a production-ready Dockerfile
2. **Experiment with Base Images:** Try alpine, slim, and distroless variants
3. **Measure Image Size:** Use `docker images` to compare before/after optimization
4. **Security Scan:** Run `trivy image myapp:v1` to find vulnerabilities

### Community Resources

- **Docker Community:** https://www.docker.com/community/
- **Stack Overflow:** Tag `docker` and `dockerfile`
- **Reddit:** r/docker
- **CNCF Slack:** #docker channel
