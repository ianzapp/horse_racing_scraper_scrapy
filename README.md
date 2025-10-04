# Horse Racing Scraper

A comprehensive Scrapy-based web scraper for collecting horse racing data from Horse Racing Nation (HRN). This scraper extracts race entries, track information, news articles, and power rankings with PostgreSQL storage integration.

## Features

- **Multiple Data Types**: Race entries, track info, news articles, and power rankings
- **PostgreSQL Integration**: Automatic data storage with deduplication and crawl tracking
- **Modular Architecture**: Separate parsing methods for different content types
- **Text Processing**: Built-in cleaning for consistent data quality
- **JavaScript Support**: Uses Playwright for dynamic content rendering
- **Date Range Generation**: Flexible date filtering with automatic range creation
- **Robust Error Handling**: Comprehensive logging and error tracking

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd horse_racing_scraper_scrapy
```

2. Install dependencies:
```bash
pip install scrapy playwright sqlalchemy psycopg2-binary
playwright install chromium
```

3. Configure PostgreSQL connection in `pipelines.py` (optional - can also output to files)

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

## Data Quality Features

- **Text Cleaning**: `clean_text()` method removes newlines and normalizes whitespace
- **Type Safety**: Safe attribute access with fallbacks for missing data
- **Deduplication**: Content-based hashing prevents duplicate storage
- **Error Handling**: Comprehensive logging and graceful failure handling
- **Field Validation**: Consistent field mapping across all spider outputs

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
├── spiders/
│   ├── hrn_race_entries_spider.py     # Main race entries spider
│   ├── hrn_news_spider.py             # News articles spider
│   └── power_rankings.py              # Power rankings spider
├── items.py                           # Data models (Scrapy items)
├── pipelines.py                       # PostgreSQL storage pipeline
├── middlewares.py                     # Playwright middleware
└── settings.py                        # Scrapy configuration
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

## Troubleshooting

### Common Issues
- **Empty results**: Check if tracks are active on selected dates
- **Database errors**: Verify PostgreSQL connection and table schema
- **Text encoding**: Ensure UTF-8 encoding for international characters
- **JavaScript timeouts**: Increase Playwright wait times for slow-loading pages

### Debugging
```bash
# Enable debug logging
scrapy crawl hrn_race_entries_spider -L DEBUG

# Test specific URL
scrapy shell "https://entries.horseracingnation.com/entries-results/track/2024-01-15"

# Check pipeline processing
scrapy crawl hrn_race_entries_spider -s ITEM_PIPELINES='{"horse_racing_scraper_scrapy.pipelines.HorseRacingScraperScrapyPipeline": 300}'
```

## License

[Add your license here]
