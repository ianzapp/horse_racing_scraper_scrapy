import scrapy
from datetime import datetime, timedelta
from urllib.parse import urlencode
import re
import math
from ..items import RaceEntryItem


class HrnRaceEntriesSpider(scrapy.Spider):
    name = "hrn_race_entries_spider"
    allowed_domains = ["entries.horseracingnation.com"]
    start_urls = []
    base_url = "https://entries.horseracingnation.com/entries-results"

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

    def __init__(self, start_date=None, end_date=None, *args, **kwargs):
        super(HrnRaceEntriesSpider, self).__init__(*args, **kwargs)

        # Set default dates if not provided, normal date range 
        if not start_date:
            start_date = (datetime.now() - timedelta(days=7)).strftime("%Y-%m-%d")
        if not end_date:
            end_date = (datetime.now() + timedelta(days=7)).strftime("%Y-%m-%d")

        # Build URL parameters
        params = {
            'start_date': start_date,
            'end_date': end_date
        }
        # Store as isntance variable
        self.params = params

        # Construct the URLs
        dates = self.generate_date_range(start_date, end_date)
        for date in dates:
            self.start_urls.append(f"{self.base_url}/{date}")


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
        # Look for track links that are specific to this date
        track_links = response.css('main table tbody a[href*="/entries-results/"]::attr(href)').getall()
        track_links = [link.split('#')[0] for link in track_links]
        track_links = list(set(track_links))  # Remove duplicates
        
        self.logger.info(f"Found {len(track_links)} track links for date")
        for link in track_links:
            yield scrapy.Request(
                response.urljoin(link),
                meta={
                    'playwright': True,
                    'playwright_wait_time': 5000
                },
                callback=self.parse_track_entries
            )
    
    def parse_track_entries(self, response):
        self.logger.info(f"Processing track entries page: {response.url}")
        
        text = response.css('main h1::text').get().strip()
        self.track_name = text.split(" Entries")[0]
        self.formatted_date = datetime.strptime(
            re.sub(r'^.*for [A-Za-z]+,\s*', '', text),
            "%B %d, %Y"
        ).strftime("%Y-%m-%d")
        
        # Extract basic track info first
        ##yield from self.parse_track_info(response)

        ##yield from self.parse_hrn_speed_results(response)

        # Extract race entries and horse information
        yield from self.parse_races(response)


    def parse_track_info(self, response):

        track_location = self.clean_text(response.css('.track-info-header::text').get().split('-')[-1])
        track_description = self.clean_text(response.css('.track-info .col-lg-8 p::text').get())
        track_website = response.css('a.track-info-link::attr(href)').get()
        yield {
            'type': 'track_info',
            'track_name': self.track_name,
            'race_date': self.formatted_date,
            'track_location': track_location,
            'track_description': track_description,
            'track_website': track_website,
            'url': response.url
        }

    def parse_races(self, response):
        race_cards = response.css('.my-5')
        for race_card in race_cards:
            race_header = race_card.css('.race-header::text').get()
            cleaned_header = self.clean_text(race_header)
            match = re.search(r'Race # (\d+)', cleaned_header)
            race_number = match.group(1) if match else None
            race_time = response.css('time::attr(datetime)').get()
            race_distance = self.clean_text(race_card.css('.race-distance::text').get())
            race_restrictions = self.clean_text(race_card.css('.race-restrictions::text').get())
            race_purse = self.clean_text(race_card.css('.race-purse::text').get())
            race_wager = self.clean_text(race_card.css('.race-wager-text::text').get())
            #race_report = race_card.css('.report-data::text').get()
            after_br_text = race_card.xpath('//ul[@class="report-data"]//p/br/following-sibling::text()').getall()
            race_report = ' '.join(after_br_text).strip()
            
            yield {
                'type': 'race_card',
                'track_name': self.track_name,
                'race_date': self.formatted_date,
                'race_time': race_time,
                'race_number': race_number,
                'race_distance': race_distance,
                'race_restrictions': race_restrictions,
                'race_purse': race_purse,
                'race_wager': race_wager,
                'race_report': race_report,
                'url': response.url
            }

            race_entries = response.css('table.table-entries tbody tr')
            for race_entry in race_entries:
                post_position = self.clean_text(race_entry.css('td[data-label="Post Position"]::text').get())
                horse_name = self.clean_text(race_entry.css('td[data-label="Horse / Sire"] a.horse-link::text').get())
                speed_figure = race_entry.css('td[data-label="Horse / Sire"] span.small::text').get()
                if speed_figure:
                    speed_figure = speed_figure.strip('()')

                sire = self.clean_text(race_entry.css('td[data-label="Horse / Sire"] p::text').get())
                trainer = self.clean_text(race_entry.css('td[data-label="Trainer / Jockey"] p:first-child::text').get())
                jockey = self.clean_text(race_entry.css('td[data-label="Trainer / Jockey"] p:last-child::text').get())
                odds = self.clean_text(race_entry.css('td[data-label="Morning Line Odds"] p:first-child::text').get())
                                
                yield {
                    'type': 'race_entry',
                    'track_name': self.track_name,
                    'race_date': self.formatted_date,
                    'post_position': post_position,
                    'horse_name': horse_name,
                    'speed_figure': speed_figure,
                    'sire': sire,
                    'trainer': trainer,
                    'jockey': jockey,
                    'odds': odds,
                    'url': response.url
                }


    
    def parse_hrn_speed_results(self, response):
        #response.css('table.table-speed').get()
        #text = response.css('main h1::text').get().strip()
        #track_name = text.split(" Entries")[0]

        table = response.css('table.table-speed')
        rows = table.css('tbody tr')
        for row in rows:
            cells = [self.clean_text(cell) for cell in row.css('td *::text, td::text').getall()]
            # Remove empty cells
            cells = [cell for cell in cells if cell]
            # Pad to ensure we have at least 5 cells
            cells = (cells + [''] * 5)[:5]

            self.logger.info(f"Parsing HRN speed result row: {cells}")
            yield {
                'type': 'hrn_speed_result',
                'track_name': self.track_name,
                'race_date': self.formatted_date,
                'race_number': cells[0],
                'hrn': cells[1],
                'horse_name': cells[2],
                'sire': cells[3],
                'age': cells[4],
                'url': response.url
            }


    def parse_race_entries(self, response):
        for race in response.css('.race-card'):
            race_number = race.css('.race-number::text').get()

            for horse in race.css('.horse-entry'):
                yield {
                    'type': 'race_entry',
                    'track_name': self.track_name,
                    'race_date': self.formatted_date,
                    'race_time': race_time,
                    'race_number': race_number,
                    'horse_name': horse.css('.horse-name::text').get(),
                    'jockey': horse.css('.jockey::text').get(),
                    'trainer': horse.css('.trainer::text').get(),
                    'odds': horse.css('.odds::text').get(),
                    # ... more fields
                    'url': response.url
                } 
        

    def generate_date_range(self, start_date, end_date):
        """Generate a list of dates between start_date and end_date"""
        self.logger.info(f"Generating date range from {start_date} to {end_date}")
        if not start_date and not end_date:
            return []

        # Set defaults if only one date is provided
        if start_date and not end_date:
            end_date = start_date  # Single date
        elif end_date and not start_date:
            start_date = end_date  # Single date

        try:
            start_dt = datetime.strptime(start_date, '%Y-%m-%d')
            end_dt = datetime.strptime(end_date, '%Y-%m-%d')
        except ValueError as e:
            self.logger.error(f"Invalid date format: {e}. Use YYYY-MM-DD format")
            return []

        if start_dt > end_dt:
            self.logger.error(f"start_date ({start_date}) cannot be after end_date ({end_date})")
            return []

        # Generate all dates in the range
        date_list = []
        current_date = start_dt
        while current_date <= end_dt:
            date_list.append(current_date.strftime('%Y-%m-%d'))
            current_date += timedelta(days=1)

        self.logger.info(f"Generated date range: {date_list[0]} to {date_list[-1]} ({len(date_list)} dates)")
        return date_list

    def clean_text(self, text):
        """Remove newlines and normalize whitespace"""
        if text:
            return ' '.join(text.split()).strip()
        return text