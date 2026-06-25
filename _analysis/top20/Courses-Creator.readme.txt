# Course Creator

A comprehensive system for converting markdown scripts into professional video courses with AI-powered enhancements.

## 🌟 Features

- **Video Course Generation**: Transform markdown content into engaging video courses
- **AI-Powered Enhancements**: Multiple LLM providers (OpenAI, Anthropic, Ollama) for content enhancement
- **TTS & Music**: High-quality text-to-speech (Bark, SpeechT5) and background music generation
- **Multi-Platform**: Desktop app (Electron), mobile app (React Native), and web player
- **Production Ready**: Docker deployment, Prometheus/Grafana monitoring, JWT authentication
- **Fully Tested**: Comprehensive test coverage with unit, integration, and e2e tests

## 🚀 Quick Start

### Prerequisites
- Docker 20.10+ and Docker Compose 2.0+
- 4GB+ RAM and 20GB+ storage
- API keys for LLM features (OpenAI, Anthropic) - optional for basic functionality

### One-Command Setup
```bash
# Clone and set up development environment
git clone https://github.com/your-org/course-creator.git
cd course-creator
cp .env.example .env
# Edit .env with your API keys (optional)
docker-compose --profile development up -d
```

### Access Services
- **API Server**: http://localhost:8080
- **Desktop App**: http://localhost:3000
- **Web Player**: http://localhost:3001
- **API Docs**: http://localhost:8080/docs
- **Monitoring**: http://localhost:3002 (Grafana - admin/admin123)

## 📁 Project Structure

```
course-creator/
├── core-processor/          # Go backend and processing engine
│   ├── api/                 # REST API handlers
│   ├── jobs/                # Background job processing
│   ├── llm/                 # LLM provider integrations
│   ├── metrics/             # Prometheus metrics
│   ├── mcp_servers/         # MCP server implementations
│   ├── pipeline/            # Video/audio processing pipeline
│   ├── repository/          # Database operations
│   ├── services/            # Business logic
│   └── tests/               # Test suites
├── creator-app/             # Electron desktop application
├── mobile-player/           # React Native mobile app
├── player-app/              # React web player
├── monitoring/              # Grafana/Prometheus configs
├── nginx/                   # Reverse proxy config
└── docker-compose.yml       # Full stack deployment
```

## ⚙️ Configuration

### Environment Variables
```bash
# Database
DB_HOST=postgres
DB_PORT=5432
DB_NAME=course_creator
DB_USER=course_creator
DB_PASSWORD=your_secure_password

# LLM Providers (optional but recommended)
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
OLLAMA_BASE_URL=http://localhost:11434

# Storage
STORAGE_TYPE=local
STORAGE_PATH=/app/storage
# Or S3:
# STORAGE_TYPE=s3
# AWS_ACCESS_KEY_ID=...
# AWS_SECRET_ACCESS_KEY=...
```

## 🔧 API Endpoints

### Authentication
- `POST /api/v1/auth/register` - Register new user
- `POST /api/v1/auth/login` - User login
- `POST /api/v1/auth/refresh` - Refresh JWT token

### Courses
- `POST /api/v1/courses/generate` - Generate course from markdown
- `GET /api/v1/courses` - List user courses
- `GET /api/v1/courses/:id` - Get course details

### Jobs
- `GET /api/v1/jobs` - List user jobs
- `GET /api/v1/jobs/:id` - Get job status
- `POST /api/v1/jobs/:id/cancel` - Cancel job

### System
- `GET /api/v1/health` - Health check
- `GET /api/v1/metrics` - Prometheus metrics

## 🛠️ Development

### Local Development Setup
```bash
# Backend (Go)
cd core-processor
go mod download
go run . server

# Desktop App
cd creator-app
npm install
npm run dev

# Mobile App
cd mobile-player
npm install
npm run ios  # or npm run android
```

### Testing
```bash
# Run all tests
go test ./...

# Run specific test suites
go test ./tests/unit
go test ./tests/integration
go test ./tests/e2e

# Run with coverage
go test -cover ./...
```

## 🐳 Deployment

### Docker Deployment
```bash
# Production
docker-compose up -d

# Development with hot reload
docker-compose --profile development up -d

# With monitoring
docker-compose --profile monitoring up -d
```

### One-Click Setup Script
```bash
# Automated development environment setup
./setup-dev.sh
```

### Monitoring
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3002
- **Health Check**: http://localhost:8080/api/v1/health
- **Metrics**: http://localhost:8080/api/v1/metrics

## 🤖 AI Service Integrations

### LLM Providers
- **OpenAI**: GPT-3.5, GPT-4 for content enhancement
- **Anthropic**: Claude for alternative LLM support
- **Ollama**: Local LLM deployment
- **Free Provider**: Mock provider for testing
- **Fallback**: Automatic provider switching on failures

### TTS Engines
- **Bark**: High-quality neural TTS with multiple voices
- **SpeechT5**: Alternative TTS with speaker embeddings
- **Text Splitting**: Automatic chunking for long content

### Image Analysis
- **LLaVA**: Visual content understanding
- **OCR**: Text extraction from images
- **Object Detection**: Identify elements in diagrams

## 📊 Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Desktop App   │    │   Mobile App    │    │   Web Player    │
│   (Electron)    │    │ (React Native) │    │    (React)      │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                    ┌─────────────┴─────────────┐
                    │      REST API           │
                    │   (Gin + Go 1.24)      │
                    └─────────────┬─────────────┘
                                 │
          ┌────────────────────────┼────────────────────────┐
          │                      │                      │
    ┌─────┴─────┐        ┌─────┴─────┐        ┌─────┴─────┐
    │   LLMs    │        │   TTS     │        │   Jobs    │
    │Providers  │        │  Engines  │        │   Queue   │
    └───────────┘        └───────────┘        └───────────┘
```

## 🔐 Security

- JWT-based authentication with refresh tokens
- Rate limiting (100 req/min default)
- Input validation and sanitization
- HTTPS in production
- No credentials in code (use environment variables)
- CORS configuration for cross-origin requests

## 📈 Performance

- Horizontal scaling support with Docker Compose
- Connection pooling for database
- Async job processing with Redis
- CDN-ready static assets
- Optimized for 1080p+ video output
- Metrics collection with Prometheus

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Write tests for your changes (100% coverage required)
4. Run all tests: `go test ./...`
5. Commit your changes: `git commit -m 'Add amazing feature'`
6. Push to the branch: `git push origin feature/amazing-feature`
7. Open a Pull Request

### Code Standards
- Go: `gofmt` and `golint`
- TypeScript: Prettier and ESLint
- 100% test coverage required
- All PRs must pass CI checks

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: [docs/](./docs/)
- **API Reference**: [docs/api/](./docs/api/)
- **Deployment Guide**: [DEPLOYMENT.md](./DEPLOYMENT.md)
- **Issues**: [GitHub Issues](https://github.com/your-org/course-creator/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-org/course-creator/discussions)

## 🗺️ Roadmap

### v1.0 (Current)
- ✅ Basic course generation
- ✅ Multi-LLM provider support
- ✅ Desktop app
- ✅ Web player
- ✅ Docker deployment
- ✅ Authentication & authorization
- ✅ Monitoring with Prometheus/Grafana

### v1.1 (Next)
- [ ] Mobile app completion
- [ ] Advanced video editing features
- [ ] Multi-language course support
- [ ] Course templates library
- [ ] Real-time progress tracking

### v2.0 (Future)
- [ ] Real-time collaboration
- [ ] AI-powered content suggestions
- [ ] Whiteboard animation support
- [ ] Interactive quizzes and assessments
- [ ] SCORM/xAPI export

---

Built with ❤️ for course creators worldwide.
- Go 1.21+
- Node.js 18+
- FFmpeg (optional, for video processing)
- React Native development environment (for mobile)

### Backend Setup

```bash
cd core-processor
go mod tidy
go build .
./core-processor server
```

The API server will start on http://localhost:8080

### Desktop App Setup

```bash
cd creator-app
npm install
npm run build
npm start
```

### Mobile App Setup

```bash
cd mobile-player
npm install
# For iOS
npm run ios
# For Android
npm run android
```

## Usage

### Creating a Course

1. **Write Markdown**: Create a course script in markdown format
2. **Use Desktop App**: Open the creator app, select your markdown file
3. **Configure Options**: Choose voice, quality, background music
4. **Generate**: Click generate to create the video course
5. **Play**: Use the mobile or desktop player to view the course

### Markdown Format

```markdown
# Course Title

This is the course description.

## Introduction

Welcome to the course!

## Main Content

This is the main content section.
```

## API Reference

### Generate Course
```http
POST /api/v1/courses/generate
Content-Type: application/json

{
  "markdown_path": "/path/to/course.md",
  "output_dir": "/path/to/output",
  "options": {
    "voice": "bark",
    "backgroundMusic": true,
    "languages": ["en"],
    "quality": "standard"
  }
}
```

### Get Courses
```http
GET /api/v1/courses
```

### Get Course
```http
GET /api/v1/courses/{id}
```

## Architecture

### Processing Pipeline
1. **Markdown Parsing**: Extract structure, content, and metadata
2. **TTS Generation**: Convert text to speech using MCP servers
3. **Video Assembly**: Combine audio, visuals, and text overlays
4. **Post-Processing**: Add subtitles, background music, final packaging

### MCP Servers
- **Bark TTS**: High-quality text-to-speech
- **SpeechT5**: Alternative TTS engine
- **Suno**: Background music generation
- **LLaVA**: Image analysis and description
- **Pix2Struct**: UI parsing for diagrams

## Development

### Running Tests
```bash
cd core-processor
go test ./...
```

### Building
```bash
# Backend
cd core-processor && go build .

# Desktop app
cd creator-app && npm run build

# Mobile app
cd mobile-player && npm run android # or ios
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Roadmap

- [ ] Real-time video preview
- [ ] Advanced video editing tools
- [ ] Multi-language support
- [ ] Cloud storage integration
- [ ] Collaborative editing
- [ ] Analytics and engagement tracking