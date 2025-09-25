# Horse Racing Scraper

A Scrapy-based web scraper for collecting horse racing entry data from Horse Racing Nation (HRN). This scraper dynamically discovers active tracks for specific dates and extracts comprehensive race entry information.

## Features

- **Dynamic Track Discovery**: Automatically finds which tracks are active on specific dates
- **Flexible Date Filtering**: Scrape data for today, date ranges, or relative dates
- **JavaScript Support**: Uses Playwright for JavaScript-rendered content
- **Comprehensive Data**: Extracts horse details, jockey/trainer info, odds, and HRN power rankings
- **Multiple Fallback Strategies**: Ensures reliable data collection across different site scenarios

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd horse_racing_scraper_scrapy
```

2. Install dependencies:
```bash
pip install scrapy playwright
playwright install chromium
```

## Quick Start

Run the scraper with default settings (processes all available dates):
```bash
scrapy crawl hrn_daily_racing_entries
```

## Date Filtering Options

### Today Only
```bash
scrapy crawl hrn_daily_racing_entries -a today_only=true
```

### Relative Dates
```bash
# Yesterday
scrapy crawl hrn_daily_racing_entries -a days_back=1

# Last 3 days
scrapy crawl hrn_daily_racing_entries -a days_back=3

# Next 5 days
scrapy crawl hrn_daily_racing_entries -a days_forward=5
```

### Specific Date Ranges
```bash
# Single date
scrapy crawl hrn_daily_racing_entries -a start_date=2024-09-25 -a end_date=2024-09-25

# Date range
scrapy crawl hrn_daily_racing_entries -a start_date=2024-09-20 -a end_date=2024-09-25
```

### Save to File
```bash
# JSON format
scrapy crawl hrn_daily_racing_entries -a days_back=1 -o entries.json

# CSV format
scrapy crawl hrn_daily_racing_entries -a today_only=true -o entries.csv
```

## Data Structure

Each scraped entry contains:

- `horse_name`: Name of the horse
- `hrn_power_ranking`: HRN power ranking (if available)
- `post_position`: Starting position
- `jockey`: Jockey name
- `trainer`: Trainer name
- `morning_line_odds`: Morning line odds
- `track`: Track name
- `race_date`: Date of the race
- `race_number`: Race number
- `sire`: Sire name (if available)
- `age`: Horse age
- `sex`: Horse sex (M/F/G)
- `entry_url`: Source URL
- `scraped_at`: Timestamp of when data was collected

## How It Works

1. **Date Discovery**: Visits the main HRN entries page to discover available dates
2. **Dynamic Filtering**: Generates target dates based on your parameters
3. **Track Discovery**: For each date, discovers which tracks are active
4. **Data Extraction**: Visits each track page and extracts race entry data
5. **Multiple Strategies**: Uses fallback methods if primary discovery fails

## Configuration

The scraper is configured with conservative settings:
- 1 concurrent request per domain
- 2-second download delay
- Playwright browser automation enabled
- UTF-8 encoding for output

## Development

### Project Structure
```
horse_racing_scraper_scrapy/
├── spiders/
│   └── horse_racing_entries_fixed.py  # Main spider
├── items.py                           # Data models
├── pipelines.py                       # Data processing
├── middlewares.py                     # Playwright middleware
└── settings.py                        # Configuration
```

### Available Commands
```bash
# List spiders
scrapy list

# Test specific URL
scrapy shell <url>

# Check for errors
scrapy check hrn_daily_racing_entries
```

## Contributing

When making changes:
1. Test with different date ranges
2. Verify track discovery works for various dates
3. Check data quality and completeness
4. Update CLAUDE.md for development guidance

## License

[Add your license here]
