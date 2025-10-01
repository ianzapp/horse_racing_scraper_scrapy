import scrapy
from datetime import datetime
import re
from ..items import PowerRankingItem, SireItem


class PowerRankingsSpider(scrapy.Spider):
    name = "hrn_power_rankings_spider"
    allowed_domains = ["horseracingnation.com"]
    start_urls = ["https://www.horseracingnation.com/polls/current/PowerRankings_Active"]

    custom_settings = {
        'PLAYWRIGHT_ENABLED': True,
        'PLAYWRIGHT_HEADLESS': True,
        'PLAYWRIGHT_BROWSER_TYPE': 'chromium',
        'PLAYWRIGHT_TIMEOUT': 30000,
        'ROBOTSTXT_OBEY': False,
        'DOWNLOAD_DELAY': 2,
        'DOWNLOADER_MIDDLEWARES': {
            'horse_racing_scraper_scrapy.middlewares.PlaywrightMiddleware': 585,
        },
    }

    def start_requests(self):
        for url in self.start_urls:
            yield scrapy.Request(
                url,
                meta={
                    'playwright': True,
                    'playwright_wait_time': 5000
                },
                callback=self.parse
            )

    def parse(self, response):
        """Parse the power rankings main page"""
        self.logger.info(f"Processing power rankings page: {response.url}")

        start_page = 1
        page_numbers = response.css('ul.pagination li.page-item .page-link::text').re(r'\d+')
        if page_numbers:
            end_page = max(int(num) for num in page_numbers) + 1
            self.logger.info(f"Found {end_page} total links on page")
        else:
            end_page = 2  # Default to just one page if no pagination found 
        self.logger.info(f"Scraping pages from {start_page} to {end_page}")
        for page in range(start_page, end_page): 
            yield scrapy.Request(f"{response.url}?page={page}", callback=self.parse_power_rankings_page)

    def parse_power_rankings_page(self, response):
        """Parse individual power ranking pages to extract articles"""
        self.logger.info(f"Processing power ranking page: {response.url}")

         # Select all table rows from the rankings table
        table_rows = response.css('table tbody tr')

        self.logger.info(f"Found {len(table_rows)} ranking entries")

        for row in table_rows:
            # Extract data from each column
            rank = row.css('td:nth-child(1)::text').get()
            rating = row.css('td:nth-child(2)::text').get()

            # Extract horse name from first span with class "horse-name"
            horse_name = row.css('td:nth-child(4) span.horse-name a::text').get()
            # Extract sire from second span with class "text-small"
            sire = row.css('td:nth-child(4) span.text-small a::text').get()
            #race_info = row.css('td:nth-child(6)::text').getall()  # Last/next race

            # Parse trainer and jockey (usually first two text elements in column 5)
            trainer = row.css('td:nth-child(5) a:first-child::text').get()
            jockey = row.css('td:nth-child(5) a:last-child::text').get()

            self.logger.info(f"Extracted ranking - Rank: {rank}, Horse: {horse_name}, Sire: {sire}, Trainer: {trainer}, Jockey: {jockey}")  

            if rank != None and rank != "" and len(rank) != 0 and rating != None and rating != "" and len(rating):
                yield {
                    'rank': rank.strip() if rank else None,
                    'rating': rating.strip() if rating else None,
                    'horse_name': horse_name,
                    'sire': sire,
                    'trainer': trainer,
                    'jockey': jockey,
                    #'race_info': ' '.join([info.strip() for info in race_info]),
                    'url': response.url
                    #,'scraped_at': datetime.now().isoformat()
                }