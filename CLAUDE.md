# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a production-ready, comprehensive Scrapy-based web scraper for horse racing data from Horse Racing Nation (HRN). The project includes multiple specialized spiders, a complete data transformation pipeline using dbt, and production deployment configurations for scalable data collection and analysis.

## Architecture

- **Main Package**: `horse_racing_scraper_scrapy/` - Contains all Scrapy components
- **Spiders**: `horse_racing_scraper_scrapy/spiders/` - Contains multiple specialized spider implementations
- **Items**: `horse_racing_scraper_scrapy/items.py` - Data models for scraped items
- **Pipelines**: `horse_racing_scraper_scrapy/pipelines.py` - Data processing and PostgreSQL storage pipelines
- **Middlewares**: `horse_racing_scraper_scrapy/middlewares.py` - Playwright and custom middlewares
- **Settings**: `horse_racing_scraper_scrapy/settings.py` - Scrapy configuration
- **Database**: PostgreSQL with Supabase integration for data storage
- **dbt Transform**: `dbt_transform/` - Complete dbt project with staging → dimensions → facts architecture
- **Production Setup**: Docker containers, scheduling, monitoring, and deployment configurations
- **Data Quality**: Comprehensive test suite and validation rules with 9.16/10 pylint score

## Environment Setup

**Create and activate virtual environment:**
```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate  # On macOS/Linux
# or
venv\Scripts\activate     # On Windows

# Upgrade pip
pip install --upgrade pip
```

**Install dependencies:**
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

## Key Commands

**Running the race entries spider:**
```bash
scrapy crawl hrn_race_entries_spider
```

**Running the news spider:**
```bash
scrapy crawl hrn_news_spider
```

**Running the power rankings spider:**
```bash
scrapy crawl power_rankings
```

**Running with date filtering options:**
```bash
# Race entries with specific date range
scrapy crawl hrn_race_entries_spider -a start_date=2024-01-15 -a end_date=2024-01-20

# Single specific date
scrapy crawl hrn_race_entries_spider -a start_date=2024-01-15 -a end_date=2024-01-15

# News spider with page range
scrapy crawl hrn_news_spider -a start_page=1 -a end_page=5

# News spider with maximum pages
scrapy crawl hrn_news_spider -a start_page=1 -a num_pages=max

# Save output to file
scrapy crawl hrn_race_entries_spider -a start_date=2024-01-15 -o entries.json
```

**List available spiders:**
```bash
scrapy list
```

**Generate a new spider:**
```bash
scrapy genspider <spider_name> <domain>
```

**Interactive shell for debugging:**
```bash
scrapy shell <url>
```

**Test spider parsing:**
```bash
scrapy parse <url> --spider=<spider_name>
```

**Check spider for errors:**
```bash
scrapy check <spider_name>
```

## Settings Configuration

The project is configured with:
- `ROBOTSTXT_OBEY = True` - Respects robots.txt
- `CONCURRENT_REQUESTS_PER_DOMAIN = 1` - Conservative crawling
- `DOWNLOAD_DELAY = 1` - 1-second delay between requests
- `FEED_EXPORT_ENCODING = "utf-8"` - UTF-8 output encoding

## Playwright Integration

The project includes Playwright integration for JavaScript-rendered content:

- **PlaywrightMiddleware**: Handles browser automation for dynamic content
- **Spider**: `horse_racing_entries_playwright` - Enhanced spider using Playwright
- **Settings**: Playwright can be enabled per spider or globally in settings.py

**Playwright Configuration:**
- Browser: Chromium (configurable to Firefox/WebKit)
- Headless mode: Enabled by default
- Page load strategy: DOM content loaded + custom wait times
- Custom headers and viewport configuration

**Usage in spiders:**
```python
meta={
    'playwright': True,
    'playwright_wait_time': 5000,  # Wait 5 seconds
    'playwright_wait_for': 'selector',  # Wait for specific element
}
```

## Available Spiders

### Race Entries Spider: `hrn_race_entries_spider`
- **Purpose**: Scrape comprehensive race entries and track information
- **URL**: entries.horseracingnation.com/entries-results
- **Features**:
  - Uses Playwright for JavaScript-rendered content
  - Modular parsing architecture with separate methods for different data types
  - Built-in text cleaning to remove newlines and normalize whitespace
  - Generates date ranges dynamically between start and end dates
  - Extracts multiple data types from each track page

**Date Filtering Options:**
- `start_date=YYYY-MM-DD`: Start date for range
- `end_date=YYYY-MM-DD`: End date for range (defaults to 7 days from start_date if not provided)

**Data Types Extracted:**
- `track_info`: Track metadata, location, website, description
- `race_card`: Race details, restrictions, purse, wagering options, expert picks
- `race_entry`: Individual horse entries with trainer, jockey, odds, speed figures
- `hrn_speed_result`: HRN speed figures and rankings

### News Spider: `hrn_news_spider`
- **Purpose**: Scrape news articles from Horse Racing Nation
- **URL**: horseracingnation.com/news
- **Features**:
  - Paginated article extraction
  - Full article content scraping
  - Author and publication date extraction

**Pagination Options:**
- `start_page=N`: Starting page number (default: 1)
- `end_page=N`: Ending page number
- `num_pages=N`: Number of pages to scrape from start_page
- `num_pages=max`: Scrape all available pages

**Data Extracted:**
- Article title, author, publication date
- Full article content
- Source URL

### Power Rankings Spider: `power_rankings`
- **Purpose**: Scrape HRN Power Rankings and drill into sire information
- **URL**: horseracingnation.com/polls/current/PowerRankings_Active
- **Features**:
  - Uses Playwright for dynamic content
  - Extracts comprehensive horse ranking data
  - Follows sire links to collect detailed breeding information
  - Follows horse detail pages for additional data

**Data Extracted (PowerRankingItem)**:
- HRN ranking position and horse details
- Performance statistics (starts, wins, earnings)
- Recent form and last race information
- Breeding information (sire, dam)
- Connections (owner, trainer, jockey)

**Data Extracted (SireItem)**:
- Basic sire information and breeding lines
- Racing record and achievements
- Stud information (fee, farm, location)
- Progeny statistics and performance metrics

## Data Pipeline

### PostgreSQL Storage
- **Database**: Supabase PostgreSQL instance
- **Pipeline**: `EnhancedRawJSONPipeline`
- **Features**:
  - Automatic deduplication using content hashes
  - Crawl run tracking with UUIDs
  - Item type classification based on data structure
  - Raw JSON storage in `raw_scraped_data` table
  - Crawl statistics and error tracking

### Data Transformation (dbt)
- **Location**: `dbt_transform/` directory
- **Purpose**: Transform raw JSON into normalized dimensional model
- **Architecture**: Staging → Dimensions → Facts
- **Features**:
  - Incremental processing for performance
  - Data quality tests and validation
  - Automated schema generation
  - Documentation generation

**dbt Setup and Usage:**
```bash
# Navigate to dbt directory
cd dbt_transform

# Install dbt packages
dbt deps

# Test database connection
dbt debug --profiles-dir .

# Run transformations (initial build)
dbt run --profiles-dir .

# Run data quality tests
dbt test --profiles-dir .

# Generate documentation
dbt docs generate --profiles-dir .
dbt docs serve --profiles-dir .
```

### Data Processing
- **Text Cleaning**: Automatic removal of newlines and whitespace normalization
- **Type Detection**: Items automatically categorized as `track_info`, `race_card`, `race_entry`, `news`, etc.
- **Deduplication**: Content-based deduplication using SHA-256 hashes
- **Error Handling**: Failed items tracked in crawl statistics

## Development Notes

- **Site Architecture**: Main page shows race schedules; individual track pages have comprehensive data
- **Dynamic Content**: Uses Playwright for JavaScript-rendered pages
- **Modular Design**: Separate parsing methods for different data types
- **Robust Selectors**: CSS selectors optimized for reliability and maintainability
- **Text Processing**: Built-in cleaning methods for consistent data quality
- **Virtual Environment**: Always use venv for dependency isolation
- **Dependencies**: Scrapy, Playwright, SQLAlchemy, psycopg2, dbt-core, dbt-postgres, Python 3.11+

## Project Workflow

### 1. Initial Setup
```bash
# Clone and setup environment
git clone <repository-url>
cd horse_racing_scraper_scrapy
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install scrapy playwright sqlalchemy psycopg2-binary
pip install "dbt-postgres>=1.6.0" "dbt-core>=1.6.0"
playwright install chromium
```

### 2. Run Data Collection
```bash
# Scrape recent race data
scrapy crawl hrn_race_entries_spider -a start_date=2024-01-15 -a end_date=2024-01-20

# Scrape news articles
scrapy crawl hrn_news_spider -a start_page=1 -a end_page=5
```

### 3. Transform Data
```bash
# Transform raw JSON into analytical tables
cd dbt_transform
dbt deps
dbt run --profiles-dir .
dbt test --profiles-dir .
```

### 4. Monitor and Maintain
```bash
# Check data quality
dbt test --profiles-dir .

# Update incrementally
dbt run --profiles-dir .

# View documentation
dbt docs generate --profiles-dir .
dbt docs serve --profiles-dir .
```

## DBT Column Ordering Standards

### Universal Temporal Column Rule
**ALL dimension and fact tables MUST end with temporal columns in this exact order:**

```sql
-- Temporal columns (standardized at end - ALWAYS LAST)
update_dt,          -- or scraped_at for fact tables (timestamp of last update)
last_seen_dt,       -- date last observed (dimensions only)
is_active,          -- boolean calculated field (dimensions only)
create_dt           -- record creation timestamp
```

**Exception:** Only override this ordering if explicitly requested by the user.

### Standard Column Ordering by Section

1. **Surrogate/Primary keys** - `dimension_key` or `fact_key`
2. **Natural/Business keys** - `track_name`, `race_date`, `horse_name`, etc.
3. **Foreign keys** - `track_key`, `horse_key`, `trainer_key`, etc.
4. **Descriptive attributes** - All business/domain-specific attributes
5. **Measures/Metrics** - Numeric values being analyzed (fact tables)
6. **Metadata** - `source_url`, `data_hash`, `business_key`
7. **Temporal columns** - ALWAYS LAST (see rule above)

### Example Dimension Table Structure
```sql
SELECT
    -- 1. Surrogate key
    horse_key,
    horse_name,

    -- 2. Foreign keys
    sire_key,
    trainer_key,

    -- 3. Descriptive attributes
    age,
    sex,
    sire_name,

    -- 4. Temporal columns (ALWAYS LAST)
    update_dt,
    last_seen_dt,
    is_active,
    create_dt
FROM dim_horses
```

### Example Fact Table Structure
```sql
SELECT
    -- 1. Surrogate key
    entry_key,

    -- 2. Foreign keys
    race_key,
    horse_key,
    trainer_key,

    -- 3. Natural keys (frequently filtered)
    track_name,
    race_date,

    -- 4. Measures
    speed_figure,
    odds,

    -- 5. Metadata / Lineage (ALWAYS LAST)
    staging_id,   -- Link to staging (enables full lineage to raw_scraped_data)
    data_hash,    -- Content hash for deduplication
    scraped_dt    -- Scrape timestamp
FROM fct_race_entries
```

### Fact Table Metadata/Lineage Standard

**ALL fact tables MUST include these three fields in this exact order (ALWAYS LAST):**

```sql
-- Metadata / Lineage (ALWAYS LAST)
staging_id,   -- INTEGER: FK to staging table id (which links to raw_scraped_data.id)
data_hash,    -- TEXT: SHA-256 hash of content for deduplication
scraped_dt    -- TIMESTAMP: When the data was scraped
```

**DO NOT include `source_url` in fact tables** - it's redundant since you can get it via:
```sql
SELECT f.*, s.source_url
FROM fct_table f
JOIN stg_table s ON f.staging_id = s.id
```

**Exception:** User-facing URLs (like `article_url` in `fct_news`) can be kept for convenience.

**Rationale:**
- `staging_id` enables complete lineage: fact → staging → raw_scraped_data
- `data_hash` allows deduplication without joins
- `scraped_dt` tracks when data was collected
- Removing `source_url` reduces storage and follows DRY principle

## Data Quality Features

- **Clean Text Extraction**: `clean_text()` helper method removes newlines and normalizes whitespace
- **Robust Cell Parsing**: Handles variable table structures with padding and truncation
- **Link Text Extraction**: Extracts both direct text and link text from HTML elements
- **Safe Pattern Matching**: Regex patterns with error handling for data extraction
- **Consistent Field Mapping**: Standardized field names across all spider outputs
- **Code Quality**: 9.16/10 pylint score with comprehensive error handling and best practices

## Production Deployment

### Quick Start (Docker Compose)
```bash
# Configure environment
cp .env.production .env
# Edit .env with your credentials

# Deploy full stack
docker-compose -f docker-compose.prod.yml up -d

# Initialize database
docker-compose exec postgres psql -U $DB_USER -d horse_racing -f /docker-entrypoint-initdb.d/create_tables.sql

# Run initial dbt setup
docker-compose run dbt dbt deps
docker-compose run dbt dbt run
```

### Production Features
- **Automated Scheduling**: Daily pipelines at 06:00 and 20:00
- **Docker Containers**: Scrapy, dbt, PostgreSQL, Redis, Monitoring
- **Health Monitoring**: Prometheus + Grafana dashboards
- **Error Recovery**: Automatic retry logic and failure alerts
- **Scalable Architecture**: Support for Kubernetes and cloud deployment

### Production Pipeline Schedule
```
06:00 AM Daily Pipeline:
├── Scrape race entries → dbt staging → marts
├── Scrape power rankings → enhance dim_horses
├── Scrape news → fct_news
└── Generate documentation

20:00 PM Evening Pipeline:
├── Scrape race results → fct_race_results
├── Scrape payouts → fct_race_payouts
└── Update analytics tables

Sunday 02:00 AM:
└── Historical backfill (7 days)
```

### Monitoring Access
- **dbt Documentation**: http://localhost:8080
- **Grafana Dashboards**: http://localhost:3000
- **Application Logs**: `docker-compose logs -f`

## Code Quality & Testing

### Pylint Configuration
- **Score**: 9.16/10 (Excellent)
- **Configuration**: `.pylintrc` with project-specific rules
- **CI/CD**: GitHub Actions with multi-Python version testing
- **Standards**: PEP 8 compliance with Scrapy-specific adaptations

### Running Quality Checks
```bash
# Run pylint on entire project
pylint horse_racing_scraper_scrapy/

# Run specific file
pylint horse_racing_scraper_scrapy/spiders/hrn_news_spider.py

# Run dbt tests
cd dbt_transform
dbt test --profiles-dir .
```

### Error Handling Best Practices
- **Null Safety**: All CSS selectors check for None values
- **Graceful Degradation**: Missing data handled with defaults
- **Comprehensive Logging**: Detailed logs for debugging and monitoring
- **Exception Handling**: Try-catch blocks for external API calls
- **Data Validation**: Schema validation before database insertion