# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Scrapy-based web scraper for horse racing data. The project follows standard Scrapy architecture with currently empty/template spider implementations.

## Architecture

- **Main Package**: `horse_racing_scraper_scrapy/` - Contains all Scrapy components
- **Spiders**: `horse_racing_scraper_scrapy/spiders/` - Contains spider implementations (currently only `__init__.py`)
- **Items**: `horse_racing_scraper_scrapy/items.py` - Data models for scraped items (currently template)
- **Pipelines**: `horse_racing_scraper_scrapy/pipelines.py` - Data processing pipelines (currently template)
- **Middlewares**: `horse_racing_scraper_scrapy/middlewares.py` - Spider and downloader middlewares (currently template)
- **Settings**: `horse_racing_scraper_scrapy/settings.py` - Scrapy configuration

## Key Commands

**Running the race entries spider:**
```bash
scrapy crawl hrn_daily_racing_entries
```

**Running the power rankings spider:**
```bash
scrapy crawl power_rankings
```

**Running with date filtering options:**
```bash
# Scrape today only
scrapy crawl hrn_daily_racing_entries -a today_only=true

# Scrape yesterday (1 day back)
scrapy crawl hrn_daily_racing_entries -a days_back=1

# Scrape next 3 days
scrapy crawl hrn_daily_racing_entries -a days_forward=3

# Scrape specific date range
scrapy crawl hrn_daily_racing_entries -a start_date=2024-01-15 -a end_date=2024-01-20

# Scrape single specific date
scrapy crawl hrn_daily_racing_entries -a start_date=2024-01-15 -a end_date=2024-01-15

# Save output to file
scrapy crawl hrn_daily_racing_entries -a days_back=1 -o yesterday_entries.json
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

## Spider Details

### Race Entries Spider: `hrn_daily_racing_entries`
- **Purpose**: Scrape daily race entries from tracks
- **URL**: entries.horseracingnation.com/entries-results
- **Features**:
  - Uses Playwright for JavaScript-rendered content
  - Dynamically discovers tracks active for each specific date
  - Supports flexible date filtering via command-line arguments
  - Handles multiple table formats (summary and detailed)

**Date Filtering Options:**
- `today_only=true`: Scrape only today's entries
- `days_back=N`: Scrape N days back from today
- `days_forward=N`: Scrape N days forward from today
- `start_date=YYYY-MM-DD`: Start date for range (generates dates dynamically)
- `end_date=YYYY-MM-DD`: End date for range (generates dates dynamically)

**Data Extracted (RaceEntryItem)**:
- Horse name, HRN power ranking, post position
- Jockey, trainer, morning line odds
- Track name, race date, race number
- Sire, age, sex information
- Entry URL and scrape timestamp

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

## Development Notes

- **Site Architecture**: Main page shows race schedules; individual track pages have entries
- **Dynamic Track Discovery**: Each date may have different active tracks
- **Multiple Fallback Strategies**: URL parameters, JavaScript navigation, known track attempts
- **Dependencies**: Scrapy, Playwright, Python 3.13+