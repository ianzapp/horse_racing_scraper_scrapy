import scrapy
from datetime import datetime, timedelta
from urllib.parse import urlencode
import re
import math
from ..items import RaceEntryItem


class BhRaceResultsSpider(scrapy.Spider):
    name = "bh_race_results_spider"
    allowed_domains = ["bloodhorse.com"]
    #start_urls = ["https://www.bloodhorse.com/horse-racing/race/race-results"]
    base_url = "https://www.bloodhorse.com/horse-racing/race/race-results/allracing"

    custom_settings = {
        'PLAYWRIGHT_ENABLED': True,
        'PLAYWRIGHT_HEADLESS': True,
        'PLAYWRIGHT_BROWSER_TYPE': 'chromium',
        'PLAYWRIGHT_TIMEOUT': 60000,
        'ROBOTSTXT_OBEY': False,
        'DOWNLOAD_DELAY': 3,
        'RANDOMIZE_DOWNLOAD_DELAY': True,
        'DOWNLOADER_MIDDLEWARES': {
            'horse_racing_scraper_scrapy.middlewares.PlaywrightMiddleware': 585,
        },
    }

    def __init__(self, start_date=None, end_date=None, region="Domestic",
                   state_bred="False", page="1", *args, **kwargs):
        super().__init__(*args, **kwargs)

        # Set default dates if not provided
        if not start_date:
            start_date = (datetime.now() - timedelta(days=1)).strftime("%m/%d/%Y")
        if not end_date:
            end_date = datetime.now().strftime("%m/%d/%Y")

        # Build URL parameters
        params = {
            'startDate': start_date,
            'endDate': end_date,
            'regionOptions': region,
            'searchStateBredPlacers': state_bred,
            'page': page
        }
        # Store as isntance variable
        self.params = params

        # Construct the URL
        self.start_urls = [f"{self.base_url}?{urlencode(params)}"]

        self.logger.info(f"Scraping with URL: {self.start_urls[0]}")

    def start_requests(self):
        yield scrapy.Request(
            self.base_url,
            meta={
                'playwright': True,
                'playwright_wait_time': 5000
            },
            callback=self.parse
        )

    def parse(self, response):
        """Parse main page and discover date ranges, then process each date individually"""
        self.logger.info(f"Processing main page: {response.url}")
        # Determine total number of pages
        h5_text = response.css('main .g-l8 h5::text').get()
        #self.logger.info(response.text[:2000])
        #self.logger.info(f"H5 Text: {h5_text}")

        # Extract the last number found
        last_number = re.findall(r'\d+', h5_text)[-1] if h5_text and re.findall(r'\d+', h5_text) else None
        last_page = math.ceil(int(last_number) / 25) if last_number else 1
        #self.logger.info(f"Total entries found: {last_number}")
        self.logger.info(f"Pages returned: {last_page}")

        for page in range(1, last_page + 1):
            # Build URL parameters
            params = {
                'startDate': self.params['startDate'],
                'endDate': self.params['endDate'],
                'regionOptions': self.params['regionOptions'],
                'searchStateBredPlacers': self.params['searchStateBredPlacers'],
                'page': page
            }

            # Construct the URL
            yield scrapy.Request(f"{self.base_url}?{urlencode(params)}", callback=self.parse_search_results)

    def parse_search_results(self, response):
        """Parse search results pages to extract"""
        self.logger.info(f"Processing search results page: {response.url}")
