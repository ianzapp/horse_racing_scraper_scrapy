# Horse Racing Data Pipeline

A production-ready, comprehensive data pipeline for collecting and analyzing horse racing data from Horse Racing Nation (HRN). Features automated scraping, data transformation with dbt, and production deployment configurations for scalable data operations.

## ✨ Features

### Core Capabilities
- **🕷️ Advanced Web Scraping**: Multiple specialized spiders for race data, news, and rankings
- **🗄️ PostgreSQL Integration**: Automated storage with deduplication and crawl tracking
- **🚀 JavaScript Support**: Playwright integration for dynamic content rendering
- **🧹 Data Quality**: Built-in text cleaning and validation with 9.16/10 pylint score
- **📊 Data Transformation**: Complete dbt pipeline with staging → dimensions → facts architecture

### Production Features
- **🐳 Docker Deployment**: Complete containerized production setup
- **⏰ Automated Scheduling**: Daily data collection and evening results processing
- **📈 Monitoring**: Prometheus + Grafana dashboards for operational visibility
- **🔧 Error Recovery**: Comprehensive retry logic and failure handling
- **☁️ Cloud Ready**: Kubernetes and cloud deployment configurations

## Installation

### 1. Clone and Setup Environment
```bash
git clone <repository-url>
cd horse_racing_scraper_scrapy
```

### 2. Create Virtual Environment (Recommended)
```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate  # On macOS/Linux
# OR on Windows:
# venv\Scripts\activate

# Upgrade pip
pip install --upgrade pip
```

### 3. Install Dependencies
```bash
# Install all project dependencies
pip install -r requirements.txt

# Install Playwright browsers
playwright install chromium

# Install development tools (optional)
pip install pylint

# Verify installations
scrapy version
dbt --version
pylint --version
```

### 4. Setup dbt (Data Transformation)
```bash
# Navigate to dbt directory
cd dbt_transform

# Install dbt packages
dbt deps

# Test database connection
dbt debug --profiles-dir .
```

**Note**: PostgreSQL connection is pre-configured in `pipelines.py` for Supabase. You can also output to files instead.

## Available Spiders

### Race Entries Spider
Scrapes comprehensive race data including track info, race cards, and individual entries:

```bash
# Default: scrapes last 7 days to next 7 days
scrapy crawl hrn_race_entries_spider

# Specific date range
scrapy crawl hrn_race_entries_spider -a start_date=2024-01-15 -a end_date=2024-01-20

# Single date
scrapy crawl hrn_race_entries_spider -a start_date=2024-01-15 -a end_date=2024-01-15
```

### News Spider
Scrapes news articles with pagination support:

```bash
# Scrape first 5 pages
scrapy crawl hrn_news_spider -a start_page=1 -a end_page=5

# Scrape maximum available pages
scrapy crawl hrn_news_spider -a start_page=1 -a num_pages=max

# Scrape specific number of pages
scrapy crawl hrn_news_spider -a start_page=1 -a num_pages=10
```

### Power Rankings Spider
```bash
scrapy crawl power_rankings
```

## Output Options

### Save to Files
```bash
# JSON format
scrapy crawl hrn_race_entries_spider -a start_date=2024-01-15 -o entries.json

# CSV format
scrapy crawl hrn_news_spider -a start_page=1 -a end_page=3 -o news.csv

# JSONLINES format
scrapy crawl hrn_race_entries_spider -o entries.jl
```

### PostgreSQL Storage
Data is automatically stored in PostgreSQL when the pipeline is enabled. Each item includes:
- Content hash for deduplication
- Crawl run ID for tracking
- Item type classification
- Source URL and timestamp

### Data Transformation with dbt
Transform raw JSON data into normalized analytical tables:

```bash
# Navigate to dbt directory
cd dbt_transform

# Run initial transformation
dbt run --profiles-dir .

# Run data quality tests
dbt test --profiles-dir .

# Incremental updates (only new data)
dbt run --profiles-dir .

# Generate documentation
dbt docs generate --profiles-dir .
dbt docs serve --profiles-dir .
```

**dbt Models Created:**
- **Staging**: `stg_race_entries`, `stg_race_cards`, `stg_race_results`, `stg_track_info`, `stg_news`, `stg_race_payouts`, `stg_hrn_speed_results`
- **Dimensions**: `dim_tracks`, `dim_horses` (enhanced), `dim_trainers`, `dim_jockeys`
- **Facts**: `fct_races`, `fct_race_entries`, `fct_race_results`, `fct_race_payouts`, `fct_news`, `fct_horse_speed_figures`

## Data Structure

### Race Entry Items (`type: race_entry`)
- `track_name`: Track name
- `race_date`: Date in YYYY-MM-DD format
- `post_position`: Starting position (cleaned)
- `horse_name`: Horse name
- `speed_figure`: HRN speed figure (if available)
- `sire`: Sire name
- `trainer`: Trainer name (cleaned)
- `jockey`: Jockey name (cleaned)
- `odds`: Morning line odds (cleaned)
- `url`: Source URL

### Track Info Items (`type: track_info`)
- `track_name`: Track name
- `race_date`: Date in YYYY-MM-DD format
- `track_location`: Geographic location
- `track_description`: Track description
- `track_website`: Official website URL
- `url`: Source URL

### Race Card Items (`type: race_card`)
- `track_name`: Track name
- `race_date`: Date in YYYY-MM-DD format
- `race_time`: Race start time
- `race_number`: Race number
- `race_distance`: Distance and surface info
- `race_restrictions`: Age/sex restrictions
- `race_purse`: Purse information
- `race_wager`: Wagering options
- `race_report`: Expert picks and analysis
- `url`: Source URL

### News Items (`type: news`)
- `title`: Article title
- `author`: Article author
- `publication_date`: Publication date
- `content`: Full article content
- `url`: Source URL

## How It Works

### Race Entries Spider
1. **Date Range Generation**: Creates date list between start_date and end_date
2. **Track Discovery**: Visits main entries page for each date to find active tracks
3. **Modular Extraction**: Uses separate methods for track info, race cards, and entries
4. **Text Cleaning**: Applies consistent cleaning to remove newlines and extra whitespace
5. **Database Storage**: Stores data with automatic deduplication and type classification

### News Spider
1. **Pagination Discovery**: Identifies total available pages
2. **Article Collection**: Extracts article links from each news feed page
3. **Content Extraction**: Follows links to scrape full article content
4. **Author/Date Parsing**: Extracts publication metadata

## 🚀 Production Deployment

### Quick Start (Docker Compose)
```bash
# 1. Configure environment
cp .env.production .env
# Edit .env with your actual credentials

# 2. Deploy full production stack
docker-compose -f docker-compose.prod.yml up -d

# 3. Initialize database
docker-compose exec postgres psql -U $DB_USER -d horse_racing -f /docker-entrypoint-initdb.d/create_tables.sql

# 4. Run initial dbt setup
docker-compose run dbt dbt deps
docker-compose run dbt dbt run
```

### Production Features
- **🐳 Containerized Services**: Scrapy, dbt, PostgreSQL, Redis, Monitoring
- **⏰ Automated Scheduling**:
  - Daily pipeline (06:00): Collect entries, news, rankings
  - Evening pipeline (20:00): Collect results and payouts
  - Weekly backfill (Sunday 02:00): Historical data processing
- **📊 Monitoring Stack**: Prometheus + Grafana dashboards
- **🔄 Health Checks**: Database connectivity and service monitoring
- **📋 Logging**: Centralized application and error logs

### Monitoring Access
- **📈 Grafana**: http://localhost:3000 (admin/admin)
- **📚 dbt Docs**: http://localhost:8080
- **💾 Database**: localhost:5432
- **🔍 Logs**: `docker-compose logs -f [service-name]`

### Cloud Deployment Options
- **AWS**: ECS + RDS + ElastiCache + EventBridge
- **GCP**: Cloud Run + Cloud SQL + Scheduler
- **Azure**: Container Instances + SQL Database
- **Kubernetes**: Full YAML configurations provided

## 🧹 Data Quality Features

- **Text Cleaning**: `clean_text()` method removes newlines and normalizes whitespace
- **Type Safety**: Safe attribute access with fallbacks for missing data
- **Deduplication**: Content-based hashing prevents duplicate storage
- **Error Handling**: Comprehensive logging and graceful failure handling
- **Field Validation**: Consistent field mapping across all spider outputs
- **Code Quality**: 9.16/10 pylint score with comprehensive error handling

## Configuration

The scrapers use conservative, production-ready settings:
- 3-second download delay with randomization
- Playwright browser automation for dynamic content
- PostgreSQL integration with connection pooling
- UTF-8 encoding for international character support
- Comprehensive logging and monitoring

## Development

### Project Structure
```
horse_racing_scraper_scrapy/
├── horse_racing_scraper_scrapy/       # Main Scrapy package
│   ├── spiders/
│   │   ├── hrn_race_entries_spider.py # Main race entries spider
│   │   ├── hrn_news_spider.py         # News articles spider
│   │   └── power_rankings.py          # Power rankings spider
│   ├── items.py                       # Data models (Scrapy items)
│   ├── pipelines.py                   # PostgreSQL storage pipeline
│   ├── middlewares.py                 # Playwright middleware
│   └── settings.py                    # Scrapy configuration
├── dbt_transform/                     # dbt transformation project
│   ├── models/
│   │   ├── staging/                   # Clean and type raw data
│   │   └── marts/                     # Dimensional model
│   ├── tests/                         # Data quality tests
│   ├── dbt_project.yml               # dbt configuration
│   └── profiles.yml                   # Database connections
├── venv/                              # Virtual environment (created)
├── requirements_dbt.txt               # dbt dependencies
└── README.md                          # This file
```

### Available Commands
```bash
# List all spiders
scrapy list

# Test specific URL in shell
scrapy shell <url>

# Check spider for errors
scrapy check hrn_race_entries_spider

# View spider statistics
scrapy crawl hrn_race_entries_spider --logLevel=INFO
```

### Database Schema
```sql
-- Main data table
CREATE TABLE raw_scraped_data (
    id SERIAL PRIMARY KEY,
    spider_name VARCHAR(255),
    source_url TEXT,
    raw_data JSONB,
    crawl_run_id UUID,
    data_hash VARCHAR(64),
    item_type VARCHAR(50),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Crawl tracking table
CREATE TABLE crawl_runs (
    id UUID PRIMARY KEY,
    spider_name VARCHAR(255),
    source_domain VARCHAR(255),
    configuration JSONB,
    status VARCHAR(50),
    total_items INTEGER DEFAULT 0,
    failed_items INTEGER DEFAULT 0,
    started_at TIMESTAMP DEFAULT NOW(),
    finished_at TIMESTAMP,
    updated_at TIMESTAMP DEFAULT NOW()
);
```

## Contributing

When making changes:
1. Test with different date ranges and pagination options
2. Verify data quality using the `clean_text()` helper
3. Check PostgreSQL storage and deduplication
4. Update CLAUDE.md for development guidance
5. Test modular parsing methods individually
6. Ensure proper error handling and logging

## Complete Workflow Example

### Daily Data Collection and Transformation
```bash
# 1. Activate virtual environment
source venv/bin/activate

# 2. Collect today's race data
scrapy crawl hrn_race_entries_spider -a start_date=$(date +%Y-%m-%d) -a end_date=$(date +%Y-%m-%d)

# 3. Collect latest news (first 3 pages)
scrapy crawl hrn_news_spider -a start_page=1 -a end_page=3

# 4. Transform new data
cd dbt_transform
dbt run --profiles-dir .
dbt test --profiles-dir .
cd ..

# 5. Check results
echo "Data collection and transformation complete!"
```

## 🔧 Troubleshooting

### Environment Issues
- **pip install errors**: Use quotes around version specs: `pip install "dbt-postgres>=1.6.0"`
- **Virtual environment**: Always activate venv: `source venv/bin/activate`
- **Python path issues**: Use `python3 -m pip` instead of `pip` if needed
- **Docker issues**: Ensure Docker Desktop is running: `docker --version`

### Scraping Issues
- **Empty results**: Check if tracks are active on selected dates
- **Database errors**: Verify PostgreSQL connection and table schema
- **Text encoding**: Ensure UTF-8 encoding for international characters
- **JavaScript timeouts**: Increase Playwright wait times for slow-loading pages
- **Pylint errors**: Run `pylint horse_racing_scraper_scrapy/` to check code quality

### dbt Issues
- **Connection errors**: Check `dbt_transform/profiles.yml` database credentials
- **Missing dependencies**: Run `dbt deps` in dbt_transform directory
- **Test failures**: Check data quality, may need to adjust validation ranges
- **Models not found**: Ensure models are in correct directory structure

### Production Issues
- **Container failures**: Check logs with `docker-compose logs [service-name]`
- **Database connectivity**: Verify network and firewall settings
- **Scheduling problems**: Check Redis connectivity and scheduler logs
- **Memory issues**: Increase container memory limits in docker-compose.yml
- **Monitoring access**: Ensure ports 3000 (Grafana) and 8080 (dbt docs) are available

### Debugging
```bash
# Scrapy debugging
scrapy crawl hrn_race_entries_spider -L DEBUG

# Test specific URL
scrapy shell "https://entries.horseracingnation.com/entries-results/track/2024-01-15"

# dbt debugging
cd dbt_transform
dbt debug --profiles-dir .
dbt compile --select model_name --profiles-dir .
```

## 📋 Quick Reference

### Key Files
- **🕷️ Spiders**: `horse_racing_scraper_scrapy/spiders/`
- **📊 dbt Models**: `dbt_transform/models/`
- **🐳 Production**: `docker-compose.prod.yml`
- **⚙️ Config**: `.pylintrc`, `requirements.txt`
- **📚 Docs**: `PRODUCTION_DEPLOYMENT.md`

### Essential Commands
```bash
# Development
source venv/bin/activate                    # Activate environment
scrapy list                                # List spiders
pylint horse_racing_scraper_scrapy/        # Check code quality

# Data Collection
scrapy crawl hrn_race_entries_spider       # Collect race data
scrapy crawl hrn_news_spider               # Collect news
scrapy crawl power_rankings                # Collect rankings

# Data Transformation
cd dbt_transform && dbt run --profiles-dir .   # Transform data
dbt test --profiles-dir .                      # Test data quality
dbt docs serve --profiles-dir .               # View documentation

# Production
docker-compose -f docker-compose.prod.yml up -d    # Deploy
docker-compose logs -f                             # Monitor logs
```

### Performance Metrics
- **📈 Pylint Score**: 9.16/10 (Excellent)
- **🔧 Error Handling**: Null-safe CSS selectors
- **🚀 Processing**: Incremental dbt models
- **📊 Data Quality**: 91 validation tests
- **🌐 Coverage**: 17 dbt models, 7 item types

## License

MIT License - See LICENSE file for details
