import scrapy
from datetime import datetime, timedelta
import re
from ..items import RaceEntryItem


class HrnDailyRacingEntriesSpider(scrapy.Spider):
    name = "hrn_daily_racing_entries_fixed"
    allowed_domains = ["entries.horseracingnation.com"]
    start_urls = ["https://entries.horseracingnation.com/entries-results"]

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
                    'playwright_wait_time': 3000,
                    'playwright_wait_for': 'table',
                },
                callback=self.parse
            )

    def parse(self, response):
        """Parse main page and discover date ranges, then process each date individually"""
        self.logger.info(f"Processing main page: {response.url}")

        # Extract ALL track links to discover the date range
        all_track_links = response.css('a[href*="/entries-results/"]::attr(href)').getall()
        self.logger.info(f"Found {len(all_track_links)} total links on page")

        # Discover all available dates from the links
        available_dates = set()
        date_pattern = re.compile(r'/(\d{4}-\d{2}-\d{2})')

        for link in all_track_links:
            match = date_pattern.search(link)
            if match:
                available_dates.add(match.group(1))

        available_dates = sorted(list(available_dates))
        self.logger.info(f"Discovered {len(available_dates)} available dates: {available_dates[0] if available_dates else 'none'} to {available_dates[-1] if available_dates else 'none'}")

        # Filter dates based on spider arguments
        available_dates = self.filter_dates_by_arguments(available_dates)
        self.logger.info(f"Will process {len(available_dates)} dates after filtering")

        # For each date, we need to discover which tracks are active
        # The main page shows today's tracks, so we need to navigate to each date
        for date in available_dates:
            # Try to navigate to the main page but for a specific date
            # This might work if the site has date navigation or URL parameters
            main_page_for_date = f"https://entries.horseracingnation.com/entries-results?date={date}"
            self.logger.info(f"Trying to discover tracks for {date} via: {main_page_for_date}")

            yield scrapy.Request(
                main_page_for_date,
                meta={
                    'playwright': True,
                    'playwright_wait_time': 5000,
                    'date': date,
                },
                callback=self.parse_date_specific_main_page,
                errback=self.try_alternative_date_discovery,
                dont_filter=True
            )

    def parse_date_specific_main_page(self, response):
        """Parse main page for a specific date to discover active tracks"""
        date = response.meta['date']
        self.logger.info(f"Parsing main page for date {date}: {response.url}")

        # Look for track links that are specific to this date
        track_links = response.css('a[href*="/entries-results/"]::attr(href)').getall()

        # Filter to only links that contain our target date
        date_specific_links = [link for link in track_links if f"/{date}" in link]

        self.logger.info(f"Found {len(date_specific_links)} tracks active on {date}")

        if date_specific_links:
            for link in date_specific_links:
                full_url = response.urljoin(link)
                self.logger.info(f"Following track for {date}: {full_url}")

                yield scrapy.Request(
                    full_url,
                    meta={
                        'playwright': True,
                        'playwright_wait_time': 8000,
                        'playwright_wait_for': 'table',
                    },
                    callback=self.parse_track_page
                )
        else:
            # If date parameter didn't work, try JavaScript navigation or alternative approach
            self.logger.info(f"Date parameter approach didn't work for {date}, trying alternative")
            yield from self.try_javascript_date_navigation(response, date)

    def try_alternative_date_discovery(self, failure):
        """Alternative approach when date parameter doesn't work"""
        date = failure.request.meta['date']
        self.logger.info(f"Date parameter failed for {date}, trying JavaScript approach")

        # Go to main page and try to navigate using JavaScript date picker
        yield scrapy.Request(
            "https://entries.horseracingnation.com/entries-results",
            meta={
                'playwright': True,
                'playwright_wait_time': 5000,
                'date': date,
                'use_js_navigation': True,
            },
            callback=self.parse_with_js_navigation,
            dont_filter=True
        )

    def try_javascript_date_navigation(self, response, date):
        """Try to navigate to a specific date using JavaScript"""
        self.logger.info(f"Attempting JavaScript navigation to {date}")

        # This would require JavaScript execution to click date picker, change date, etc.
        # For now, we'll use the existing track discovery from today's links as fallback
        yield from self.fallback_track_discovery(response, date)

    def parse_with_js_navigation(self, response):
        """Parse page after attempting JavaScript date navigation"""
        date = response.meta['date']
        self.logger.info(f"Attempting JS navigation for {date} on: {response.url}")

        # This is where we'd execute JavaScript to navigate to the specific date
        # For now, fallback to existing approach
        yield from self.fallback_track_discovery(response, date)

    def fallback_track_discovery(self, response, target_date):
        """Fallback: use existing track names but for the target date"""
        # Extract track names from current page
        all_track_links = response.css('a[href*="/entries-results/"]::attr(href)').getall()
        track_names = set()

        for link in all_track_links:
            if '/entries-results/' in link:
                parts = link.split('/')
                if len(parts) >= 4 and parts[2] != '' and not re.match(r'^\d{4}-', parts[2]):
                    track_names.add(parts[2])

        self.logger.info(f"Fallback: trying {len(track_names)} known tracks for {target_date}")

        # Try each known track for the target date
        for track_name in track_names:
            track_url = f"https://entries.horseracingnation.com/entries-results/{track_name}/{target_date}"
            yield scrapy.Request(
                track_url,
                meta={
                    'playwright': True,
                    'playwright_wait_time': 8000,
                    'playwright_wait_for': 'table',
                },
                callback=self.parse_track_page,
                errback=self.handle_track_not_found,  # Silently handle tracks not active on this date
                dont_filter=True
            )

    def handle_track_not_found(self, failure):
        """Silently handle tracks that aren't active on specific dates"""
        # This is expected - not all tracks run every day
        pass

    def parse_track_page(self, response):
        """Parse individual track page with race entries"""
        self.logger.info(f"Processing track page: {response.url}")

        # Extract track name from URL or page
        track_name = self.extract_track_name(response)
        date = self.extract_date(response)

        # Find race tables - look for tables with horse-related headers
        all_tables = response.css('table')
        race_tables = []

        for table in all_tables:
            # Check if table has horse-related headers
            headers = table.css('th::text').getall()
            header_text = ' '.join(headers).lower()

            if any(keyword in header_text for keyword in ['horse', 'trainer', 'jockey', 'sire']):
                race_tables.append(table)

        self.logger.info(f"Found {len(race_tables)} race tables")

        # Process each race table
        race_number = 1
        for table in race_tables:
            headers = table.css('th::text').getall()
            headers = [h.strip() for h in headers if h.strip()]

            # Determine table type based on headers
            if self.is_summary_table(headers):
                # Summary table: ['Race', 'HRN', 'Horse', 'Sire', 'Age']
                yield from self.extract_from_summary_table(table, track_name, date, response)
            elif self.is_detailed_table(headers):
                # Detailed table: ['Horse (last) / Sire', 'Trainer / Jockey', 'ML']
                yield from self.extract_from_detailed_table(table, track_name, date, race_number, response)
                race_number += 1

    def is_summary_table(self, headers):
        """Check if this is a summary table format"""
        header_text = ' '.join(headers).lower()
        return 'hrn' in header_text and 'horse' in header_text and 'sire' in header_text

    def is_detailed_table(self, headers):
        """Check if this is a detailed table format"""
        header_text = ' '.join(headers).lower()
        return 'horse (last)' in header_text or ('trainer' in header_text and 'jockey' in header_text)

    def extract_from_summary_table(self, table, track_name, date, response):
        """Extract data from summary table format: Race | HRN | Horse | Sire | Age"""
        self.logger.info("Processing summary table")

        rows = table.css('tbody tr')
        if not rows:
            rows = table.css('tr')[1:]  # Skip header row

        for row in rows:
            cells = row.css('td::text').getall()
            cells = [self.clean_text(cell) for cell in cells if self.clean_text(cell)]

            if len(cells) >= 5:
                item = RaceEntryItem()

                # Basic info
                item['track'] = track_name
                item['race_date'] = date
                item['entry_url'] = response.url
                item['scraped_at'] = datetime.now().isoformat()

                # From table cells
                item['race_number'] = cells[0]  # Race
                item['hrn_power_ranking'] = cells[1]  # HRN
                item['horse_name'] = cells[2]  # Horse
                item['sire'] = cells[3]  # Sire

                # Parse age field like "5G" or "3F"
                age_field = cells[4] if len(cells) > 4 else ""
                if age_field:
                    item['age'] = re.sub(r'[^0-9]', '', age_field)  # Extract numbers
                    sex_match = re.search(r'[MFGmfg]', age_field)
                    if sex_match:
                        item['sex'] = sex_match.group().upper()

                yield item

    def extract_from_detailed_table(self, table, track_name, date, race_number, response):
        """Extract data from detailed table format with horse names, trainers, jockeys"""
        self.logger.info(f"Processing detailed table for race {race_number}")

        rows = table.css('tbody tr')
        if not rows:
            rows = table.css('tr')[1:]  # Skip header row

        post_position = 1
        for row in rows:
            cells = row.css('td')

            if len(cells) >= 3:
                item = RaceEntryItem()

                # Basic info
                item['track'] = track_name
                item['race_date'] = date
                item['race_number'] = race_number
                item['post_position'] = str(post_position)
                item['entry_url'] = response.url
                item['scraped_at'] = datetime.now().isoformat()

                # Extract post position from first cell if it's a number
                first_cell_text = self.clean_text(cells[0].css('::text').get())
                if first_cell_text and first_cell_text.isdigit():
                    item['post_position'] = first_cell_text

                # Extract horse name and HRN power ranking from horse cell
                horse_cell = cells[2] if len(cells) > 2 else cells[1]
                horse_texts = horse_cell.css('::text').getall()
                horse_texts = [self.clean_text(t) for t in horse_texts if self.clean_text(t)]

                if horse_texts:
                    # Horse name is usually the first non-empty, non-numeric text
                    for text in horse_texts:
                        if text and not text.isdigit() and len(text) > 2 and '(' not in text:
                            item['horse_name'] = text
                            break

                    # Look for HRN power ranking in parentheses like "(102)"
                    for text in horse_texts:
                        if '(' in text and ')' in text:
                            hrn_match = re.search(r'\((\d+\*?)\)', text)
                            if hrn_match:
                                item['hrn_power_ranking'] = hrn_match.group(1)

                    # Look for sire name (usually last text entry)
                    if len(horse_texts) > 1:
                        # Sire is often the last meaningful text
                        potential_sire = horse_texts[-1]
                        if potential_sire and len(potential_sire) > 3 and '(' not in potential_sire:
                            item['sire'] = potential_sire

                # Extract trainer and jockey from trainer cell
                trainer_cell = cells[3] if len(cells) > 3 else None
                if trainer_cell:
                    trainer_texts = trainer_cell.css('::text').getall()
                    trainer_texts = [self.clean_text(t) for t in trainer_texts if self.clean_text(t)]

                    if len(trainer_texts) >= 2:
                        item['trainer'] = trainer_texts[0]
                        item['jockey'] = trainer_texts[1]

                # Extract morning line odds from odds cell (usually last cell)
                odds_cell = cells[-1] if cells else None
                if odds_cell:
                    # Get all text from the cell
                    odds_texts = odds_cell.css('::text').getall()
                    cleaned_odds_texts = [self.clean_text(t) for t in odds_texts if self.clean_text(t)]
                    odds_text = ' '.join(cleaned_odds_texts) if cleaned_odds_texts else ''

                    if odds_text and ('/' in odds_text or '.' in odds_text):
                        item['morning_line_odds'] = odds_text

                # Only yield if we have meaningful data
                if item.get('horse_name') or item.get('post_position'):
                    yield item

                post_position += 1

    def extract_track_name(self, response):
        """Extract track name from URL or page title"""
        # Try to extract from URL
        url_match = re.search(r'/entries-results/([^/]+)/', response.url)
        if url_match:
            track_slug = url_match.group(1)
            track_name = track_slug.replace('-', ' ').title()
            return track_name

        # Try to extract from page title
        title = response.css('title::text').get()
        if title:
            # Extract track name from title like "Hawthorne Race Course Entries & Results"
            track_match = re.search(r'(.+?)\s+Entries', title)
            if track_match:
                return track_match.group(1)

        return "Unknown Track"

    def extract_date(self, response):
        """Extract race date from URL or page"""
        # Try to extract from URL
        date_match = re.search(r'/(\d{4}-\d{2}-\d{2})', response.url)
        if date_match:
            return date_match.group(1)

        # Try to extract from page title
        title = response.css('title::text').get()
        if title:
            date_match = re.search(r'(\d{1,2}-\d{1,2}-\d{4})', title)
            if date_match:
                return date_match.group(1)

        return datetime.now().strftime('%Y-%m-%d')

    def filter_dates_by_arguments(self, available_dates):
        """Filter available dates based on spider arguments or generate date range dynamically"""
        # Get arguments with defaults
        start_date = getattr(self, 'start_date', None)
        end_date = getattr(self, 'end_date', None)
        days_back = getattr(self, 'days_back', None)
        days_forward = getattr(self, 'days_forward', None)
        today_only = getattr(self, 'today_only', None)

        # Convert string arguments to proper types
        if today_only and today_only.lower() in ['true', '1', 'yes']:
            today = datetime.now().strftime('%Y-%m-%d')
            return [today]  # Generate today's date regardless of available_dates

        if days_back:
            try:
                days_back = int(days_back)
                start_date = (datetime.now() - timedelta(days=days_back)).strftime('%Y-%m-%d')
                self.logger.info(f"Setting start_date to {days_back} days back: {start_date}")
            except ValueError:
                self.logger.warning(f"Invalid days_back value: {days_back}")

        if days_forward:
            try:
                days_forward = int(days_forward)
                end_date = (datetime.now() + timedelta(days=days_forward)).strftime('%Y-%m-%d')
                self.logger.info(f"Setting end_date to {days_forward} days forward: {end_date}")
            except ValueError:
                self.logger.warning(f"Invalid days_forward value: {days_forward}")

        # If start_date or end_date are specified, generate the date range dynamically
        if start_date or end_date:
            return self.generate_date_range(start_date, end_date)

        # Otherwise, use the available dates from the page (current behavior)
        self.logger.info(f"No date parameters specified, using available dates from page: {len(available_dates)} dates")
        return available_dates

    def generate_date_range(self, start_date, end_date):
        """Generate a list of dates between start_date and end_date"""
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
        """Clean and normalize extracted text"""
        if text:
            return text.strip().replace('\n', ' ').replace('\r', '').replace('\t', ' ')
        return None