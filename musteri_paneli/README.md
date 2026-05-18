# Yerimebak AI - Digital Notary & Forensic Valuation System 🚀

[![Version](https://img.shields.io/badge/version-8.1.0-blue.svg)](https://github.com/your-repo/yerimebak)
[![Python](https://img.shields.io/badge/python-3.10%2B-blue.svg)](https://www.python.org/)
[![License](https://img.shields.io/badge/license-Proprietary-red.svg)]()

Yerimebak AI is an advanced, enterprise-grade vehicle intelligence platform. It utilizes an 11-engine AI architecture to perform forensic-level market analysis, providing highly accurate vehicle valuations, opportunity detections, and deterministic risk assessments.

## 🏛️ System Architecture

Our robust, production-ready architecture is designed for scalability and fault tolerance.

- **FastAPI Core**: High-performance, asynchronous REST & WebSocket APIs.
- **Unified AI Engine (v8.1)**: Multi-model orchestration (Gemma 3, Qwen 3) with fallback logic.
- **Market Data Lake**: Scalable real-time market scraping, normalization, and semantic caching.
- **Forensic Evidence Vault**: Immutable hashing (SHA3-512) for tamper-proof reports and diagnostics.
- **Microservices-oriented Scrapers**: Headless, anti-bot resilient scraping nodes.

## 📂 Project Structure

```text
yerimebak_ai/
├── data/                   # Data Lake exports, SQLite DBs, and runtime caches
├── docs/                   # Architectural blueprints and engineering guidelines
├── scripts/                # Utility, DB management, and maintenance scripts
├── tests/                  # Unit and integration test suites
├── yerimebak_ai_v5/        # Application Source Code
│   ├── api/                # FastAPI routing and middleware
│   ├── core/               # Domain engines (Valuation, Forensics, Market)
│   ├── dashboard/          # Frontend Web App (UX/UI Components)
│   ├── scrapers/           # Sub-systems for external data acquisition
│   ├── services/           # Orchestrators connecting API to Core logic
│   └── workers/            # Background tasks and watchdog processes
├── docker-compose.yml      # Multi-container orchestration config
├── Dockerfile              # Container definition for the main service
└── README.md               # You are here
```

> *(Documentation has been restructured for intuitive navigation and maintenance.)*

## 🚀 Getting Started

### 1. Environment Setup

Copy the environment template and configure your secrets:
```bash
cp .env.example .env
```

### 2. Local Execution (Development)

Ensure you have Python 3.10+ installed.

```bash
# Install dependencies
pip install -r requirements.txt

# Run database configuration
python scripts/maintenance/bootstrap.py

# Launch the Application
python -m yerimebak_ai_v5.main
```

### 3. Docker Deployment (Production)

For an isolated production build, run the platform using Docker Compose:

```bash
docker-compose up --build -d
```

## 🧪 Testing

Execute the test suites via pytest to validate component integrity.

```bash
pytest tests/
```

## 🔒 Security & Compliance

This platform enforces zero-trust data ingestion. All market sources are scrubbed before processing, anomalies are detected deterministically via the `risk_engine_v8` module, and outputs are cryptographically sealed via the `EvidenceVault`.

---
*Built with precision and engineered for scale.*
