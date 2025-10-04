# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a comprehensive Scrapy-based web scraper for horse racing data from Horse Racing Nation (HRN). The project includes multiple specialized spiders for different types of racing data and uses PostgreSQL for data storage.

## Architecture

- **Main Package**: `horse_racing_scraper_scrapy/` - Contains all Scrapy components
- **Spiders**: `horse_racing_scraper_scrapy/spiders/` - Contains multiple specialized spider implementations
- **Items**: `horse_racing_scraper_scrapy/items.py` - Data models for scraped items
- **Pipelines**: `horse_racing_scraper_scrapy/pipelines.py` - Data processing and PostgreSQL storage pipelines
- **Middlewares**: `horse_racing_scraper_scrapy/middlewares.py` - Playwright and custom middlewares
- **Settings**: `horse_racing_scraper_scrapy/settings.py` - Scrapy configuration
- **Database**: PostgreSQL with Supabase integration for data storage

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
- **Dependencies**: Scrapy, Playwright, SQLAlchemy, psycopg2, Python 3.13+

## Data Quality Features

- **Clean Text Extraction**: `clean_text()` helper method removes newlines and normalizes whitespace
- **Robust Cell Parsing**: Handles variable table structures with padding and truncation
- **Link Text Extraction**: Extracts both direct text and link text from HTML elements
- **Safe Pattern Matching**: Regex patterns with error handling for data extraction
- **Consistent Field Mapping**: Standardized field names across all spider outputs