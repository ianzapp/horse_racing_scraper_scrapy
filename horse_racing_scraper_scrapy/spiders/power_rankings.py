import scrapy
from datetime import datetime
import re
from ..items import PowerRankingItem, SireItem


class PowerRankingsSpider(scrapy.Spider):
    name = "power_rankings"
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
                    'playwright_wait_time': 5000,
                    'playwright_wait_for': 'table',
                },
                callback=self.parse
            )

    def parse(self, response):
        """Parse the power rankings main page"""
        self.logger.info(f"Processing power rankings page: {response.url}")

        # Debug: Count how many rows we're processing
        all_tables = response.css('table')
        total_rows = sum(len(table.css('tbody tr, tr')) for table in all_tables)
        self.logger.info(f"Found {len(all_tables)} tables with total {total_rows} rows on page")

        # Look for the rankings table
        tables = response.css('table')
        self.logger.info(f"Found {len(tables)} tables on page")

        # Find the main rankings table (likely has horse names and rankings)
        ranking_table = None
        for table in tables:
            headers = table.css('th::text').getall()
            header_text = ' '.join(headers).lower()

            # Look for table with ranking-related headers
            if any(keyword in header_text for keyword in ['rank', 'horse', 'power', 'rating']):
                ranking_table = table
                break

        if not ranking_table:
            # Try looking for div-based rankings or other structures
            self.logger.warning("No ranking table found, looking for alternative structures")
            yield from self.parse_alternative_structure(response)
            return

        self.logger.info("Processing main rankings table")

        # Extract rankings from table rows
        rows = ranking_table.css('tbody tr')
        if not rows:
            rows = ranking_table.css('tr')[1:]  # Skip header row

        for row_num, row in enumerate(rows, 1):
            ranking_item = self.extract_ranking_from_row(row, response, row_num)
            if ranking_item:
                yield ranking_item
                # Note: Removed link following to reduce data volume and focus on rankings table only

        # Handle pagination
        yield from self.handle_pagination(response)

    def parse_alternative_structure(self, response):
        """Try to parse rankings from alternative page structures"""
        self.logger.info("Attempting to parse alternative ranking structure")

        # Look for ranking items in divs, lists, or other structures
        ranking_items = response.css('[class*="rank"], [class*="power"], [class*="horse"]')

        if ranking_items:
            self.logger.info(f"Found {len(ranking_items)} potential ranking elements")

            for item in ranking_items:
                # Extract what we can from each element
                horse_name = self.extract_horse_name_from_element(item)
                if horse_name:
                    ranking_item = PowerRankingItem()
                    ranking_item['horse_name'] = horse_name
                    ranking_item['source_url'] = response.url
                    ranking_item['scraped_at'] = datetime.now().isoformat()

                    # Try to extract other data
                    self.populate_ranking_item_from_element(ranking_item, item, response)
                    yield ranking_item

        # Handle pagination even for alternative structures
        yield from self.handle_pagination(response)

    def extract_ranking_from_row(self, row, response, row_number):
        """Extract ALL ranking data from a table row"""
        cells = row.css('td')
        if not cells:
            return None

        item = PowerRankingItem()

        # Basic metadata
        item['source_url'] = response.url
        item['scraped_at'] = datetime.now().isoformat()
        item['ranking_date'] = datetime.now().strftime('%Y-%m-%d')

        # Get all cell texts for comprehensive extraction
        cell_data = []
        for cell in cells:
            # Extract both text and links from each cell
            cell_info = {
                'text': self.clean_text(cell.css('::text').get()),
                'all_text': [self.clean_text(t) for t in cell.css('::text').getall() if self.clean_text(t)],
                'links': cell.css('a::attr(href)').getall(),
                'link_texts': [self.clean_text(t) for t in cell.css('a::text').getall() if self.clean_text(t)]
            }
            cell_data.append(cell_info)

        self.logger.debug(f"Row {row_number} has {len(cell_data)} cells: {[c['text'] for c in cell_data]}")

        # Extract based on typical power rankings table structure
        # Common columns: Rank, Rating, Horse, Age/Sex, Sire, Trainer, Last Start, Next Start, Earnings, Record

        if len(cell_data) >= 1:
            # Column 1: Ranking number
            rank_text = cell_data[0]['text']
            if rank_text and rank_text.isdigit():
                item['hrn_ranking'] = int(rank_text)
            else:
                item['hrn_ranking'] = row_number

        if len(cell_data) >= 2:
            # Column 2: Usually rating/power number
            rating_text = cell_data[1]['text']
            if rating_text and (rating_text.isdigit() or '*' in rating_text):
                item['hrn_power_rating'] = rating_text
                self.logger.debug(f"Found power rating: {rating_text}")

        # Find horse name and URL, and extract sire from same cell
        horse_column = None
        for i, cell in enumerate(cell_data):
            if cell['links'] and cell['link_texts']:
                for j, link in enumerate(cell['links']):
                    if 'horse' in link.lower() or 'profile' in link.lower():
                        item['horse_name'] = cell['link_texts'][j] if j < len(cell['link_texts']) else cell['text']
                        item['horse_url'] = link
                        horse_column = i

                        # Extract sire from the same cell (different lines)
                        self.extract_sire_from_horse_cell(item, cell)

                        self.logger.debug(f"Found horse: {item['horse_name']} at column {i}")
                        break
                if item.get('horse_name'):
                    break

        # Extract trainer and jockey from column 5 (typically connections column)
        if len(cell_data) >= 6:  # Make sure we have at least 6 columns (0-5)
            connections_cell = cell_data[5]  # Column 5 (0-indexed)
            self.extract_trainer_jockey_from_cell(item, connections_cell, 5)

        # Extract age/sex information (patterns like "4C", "5H", "3F")
        for cell in cell_data:
            text = cell['text']
            if text and re.match(r'^\d+[A-Za-z]$', text):
                item['age'] = text[:-1]
                item['sex'] = text[-1].upper()
                self.logger.debug(f"Found age/sex: {text}")
                break

        # Extract last start information (look for dates or track names)
        for i, cell in enumerate(cell_data):
            text = cell['text']
            if text:
                # Look for date patterns (MM/DD, DD/MM, etc.)
                if re.search(r'\d{1,2}[/-]\d{1,2}', text) or any(month in text.lower() for month in ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec']):
                    item['last_race_date'] = text
                    self.logger.debug(f"Found last race date: {text} at column {i}")
                # Look for track abbreviations (3-4 letter codes)
                elif len(text) >= 3 and len(text) <= 6 and text.isupper():
                    item['last_race_track'] = text
                    self.logger.debug(f"Found last race track: {text} at column {i}")

        # Extract next start information
        for i, cell in enumerate(cell_data):
            text = cell['text']
            if text and 'next' in str(cell_data).lower():  # Context suggests next start
                if re.search(r'\d{1,2}[/-]\d{1,2}', text):
                    item['next_race_date'] = text
                    self.logger.debug(f"Found next race date: {text} at column {i}")

        # Extract earnings (look for $ signs or large numbers with commas)
        for cell in cell_data:
            text = cell['text']
            if text and ('$' in text or (text.replace(',', '').replace('.', '').isdigit() and len(text) > 5)):
                item['earnings'] = text
                self.logger.debug(f"Found earnings: {text}")
                break

        # Extract record (win-place-show format like "12-4-2")
        for cell in cell_data:
            text = cell['text']
            if text and re.match(r'^\d+-\d+-\d+$', text):
                parts = text.split('-')
                item['wins'] = parts[0]
                item['places'] = parts[1]
                item['shows'] = parts[2]
                item['starts'] = str(int(parts[0]) + int(parts[1]) + int(parts[2]))  # Calculate total starts
                self.logger.debug(f"Found record: {text}")
                break

        # (Trainer extraction moved above to avoid confusion with sire)

        # Log the extracted data for verification
        sire_info = item.get('sire', 'N/A')
        sire_link_info = ""
        if item.get('sire_url'):
            sire_link_info = " [Stallion Page]"
        elif item.get('sire_horse_url'):
            sire_link_info = " [Horse Profile]"

        # Enhanced logging with trainer/jockey info
        trainer_info = item.get('trainer', 'N/A')
        jockey_info = item.get('jockey', 'N/A')

        self.logger.info(f"Extracted ranking #{item.get('hrn_ranking')}: {item.get('horse_name', 'Unknown')} (Rating: {item.get('hrn_power_rating', 'N/A')}, Sire: {sire_info}{sire_link_info}, Trainer: {trainer_info}, Jockey: {jockey_info})")

        return item

    def extract_sire_from_horse_cell(self, item, cell):
        """Extract sire information from the same cell as horse name (different lines)"""
        # Get all text content from the cell, preserving line breaks
        all_texts = cell['all_text']
        horse_name = item.get('horse_name')

        self.logger.debug(f"Extracting sire from horse cell. All texts: {all_texts}")

        # Look through all text elements in the cell
        for i, text in enumerate(all_texts):
            # Skip the horse name itself
            if text == horse_name:
                continue

            # Look for text that appears to be a sire name
            if text and len(text) > 2:
                # Check if this looks like a sire name (not metadata)
                if (not re.match(r'^\d+[*]?$', text) and  # Not power rating
                    not re.search(r'\d{1,2}[/-]\d{1,2}', text) and  # Not date
                    not re.match(r'^[A-Z]{2,4}$', text) and  # Not track abbreviation
                    not '$' in text and  # Not earnings
                    not re.match(r'^\d+-\d+-\d+$', text) and  # Not record
                    not re.match(r'^\d+[A-Za-z]$', text)):  # Not age/sex like "4C"

                    # This looks like a sire name
                    item['sire'] = text
                    self.logger.debug(f"Found sire in horse cell: {text}")

                    # Look for corresponding sire links
                    if cell['links']:
                        for j, link in enumerate(cell['links']):
                            # Check if this link corresponds to the sire
                            link_text = cell['link_texts'][j] if j < len(cell['link_texts']) else None
                            if link_text == text:
                                if 'sire' in link.lower() or 'stallion' in link.lower():
                                    item['sire_url'] = link
                                    self.logger.debug(f"Found sire stallion link: {link}")
                                elif 'horse' in link.lower() or 'profile' in link.lower():
                                    item['sire_horse_url'] = link
                                    self.logger.debug(f"Found sire horse profile link: {link}")
                                break
                    break

    def extract_trainer_jockey_from_cell(self, item, cell, column_index):
        """Extract trainer and jockey information from column 5 (connections column)"""
        all_texts = cell['all_text']
        self.logger.debug(f"Extracting trainer/jockey from column {column_index}. All texts: {all_texts}")

        # Look for trainer and jockey in the cell text
        for i, text in enumerate(all_texts):
            if text and len(text) > 2:
                # Clean up the text
                clean_text = text.strip()

                # Skip obvious non-name text
                if (clean_text.isdigit() or
                    re.match(r'^\d+[*]?$', clean_text) or  # Power rating
                    re.search(r'\d{1,2}[/-]\d{1,2}', clean_text) or  # Date
                    '$' in clean_text or  # Earnings
                    re.match(r'^\d+-\d+-\d+$', clean_text)):  # Record
                    continue

                # The first name-like text is usually the trainer
                if not item.get('trainer') and len(clean_text.split()) >= 2:
                    item['trainer'] = clean_text
                    self.logger.debug(f"Found trainer in column {column_index}: {clean_text}")
                # The second name-like text is usually the jockey
                elif not item.get('jockey') and len(clean_text.split()) >= 2 and clean_text != item.get('trainer'):
                    item['jockey'] = clean_text
                    self.logger.debug(f"Found jockey in column {column_index}: {clean_text}")

        # Also check for linked names (trainer/jockey links)
        if cell['links'] and cell['link_texts']:
            for j, link in enumerate(cell['links']):
                link_lower = link.lower()
                link_text = cell['link_texts'][j] if j < len(cell['link_texts']) else None

                if link_text and len(link_text) > 2:
                    if 'trainer' in link_lower:
                        item['trainer'] = link_text
                        self.logger.debug(f"Found trainer link in column {column_index}: {link_text}")
                    elif 'jockey' in link_lower:
                        item['jockey'] = link_text
                        self.logger.debug(f"Found jockey link in column {column_index}: {link_text}")
                    elif not item.get('trainer'):
                        # First link might be trainer
                        item['trainer'] = link_text
                        self.logger.debug(f"Found potential trainer link in column {column_index}: {link_text}")
                    elif not item.get('jockey') and link_text != item.get('trainer'):
                        # Second link might be jockey
                        item['jockey'] = link_text
                        self.logger.debug(f"Found potential jockey link in column {column_index}: {link_text}")

    def extract_horse_name_from_element(self, element):
        """Extract horse name from a DOM element"""
        # Try various selectors for horse names
        name = element.css('::text').get()
        if not name:
            name = element.css('a::text').get()
        if not name:
            name = element.css('[class*="name"]::text').get()

        return self.clean_text(name) if name else None

    def populate_ranking_item_from_element(self, item, element, response):
        """Populate ranking item from a DOM element"""
        # Extract links
        links = element.css('a')
        for link in links:
            href = link.css('::attr(href)').get()
            text = self.clean_text(link.css('::text').get())

            if href and text:
                if 'horse' in href or 'profile' in href:
                    item['horse_url'] = href
                elif 'sire' in href or 'stallion' in href:
                    item['sire'] = text
                    item['sire_url'] = href

    # Removed sire and horse detail page processing methods to reduce data volume
    # Focus is now on extracting complete information from rankings table only

    def handle_pagination(self, response):
        """Handle pagination to scrape all pages of results"""
        # HRN Power Rankings specific pagination detection
        next_links = []

        # Log current state for debugging
        current_page = self.extract_current_page(response)
        self.logger.info(f"Current page: {current_page}, URL: {response.url}")

        # Debug: Show all links on the page
        all_links = response.css('a')
        self.logger.debug(f"Total links on page: {len(all_links)}")

        # Debug: Show all text that might indicate pagination
        pagination_text = response.css('body').re(r'(?i)(next|previous|page|\d+)')
        if pagination_text:
            self.logger.debug(f"Found pagination-related text: {pagination_text[:10]}...")  # First 10 items

        # Pattern 1: Look for "Next" links (case insensitive)
        next_selectors = [
            'a:contains("Next")', 'a:contains("next")', 'a:contains("NEXT")',
            'a:contains("Next Page")', 'a:contains("next page")',
        ]

        for selector in next_selectors:
            links = response.css(f'{selector}::attr(href)').getall()
            next_links.extend(links)
            if links:
                self.logger.debug(f"Found next links with selector '{selector}': {links}")

        # Pattern 2: Look for numeric page links (find next number)
        if current_page:
            next_page = current_page + 1
            numeric_selectors = [
                f'a:contains("{next_page}")',
                f'a[href*="{next_page}"]',
                f'a[href*="page={next_page}"]',
                f'a[href*="page/{next_page}"]',
            ]

            for selector in numeric_selectors:
                links = response.css(f'{selector}::attr(href)').getall()
                next_links.extend(links)
                if links:
                    self.logger.debug(f"Found page {next_page} links: {links}")

        # Pattern 3: Look for arrow symbols and navigation
        arrow_selectors = [
            'a:contains("›")', 'a:contains("→")', 'a:contains(">")',
            'a:contains("▶")', 'a:contains("⟩")', 'a:contains("»")',
        ]

        for selector in arrow_selectors:
            links = response.css(f'{selector}::attr(href)').getall()
            next_links.extend(links)
            if links:
                self.logger.debug(f"Found arrow links with '{selector}': {links}")

        # Pattern 4: Look for pagination classes
        class_selectors = [
            'a.next', 'a.page-next', 'a.pagination-next',
            'a[class*="next"]', 'a[class*="pagination"]',
            '.pagination a', '.pager a', '.page-nav a',
        ]

        for selector in class_selectors:
            links = response.css(f'{selector}::attr(href)').getall()
            next_links.extend(links)
            if links:
                self.logger.debug(f"Found class-based links with '{selector}': {links}")

        # Pattern 5: Look for all page links and find the next sequential one
        all_page_links = response.css('a[href*="page"]::attr(href)').getall()
        if all_page_links and current_page:
            for link in all_page_links:
                page_num = self.extract_page_number_from_url(link)
                if page_num and page_num == current_page + 1:
                    next_links.append(link)
                    self.logger.debug(f"Found sequential page link: {link} (page {page_num})")

        # Pattern 6: HRN-specific pagination (check for their specific structure)
        hrn_pagination = response.css('div[class*="pagination"] a, nav a, .pager a').getall()
        if hrn_pagination:
            self.logger.debug(f"Found HRN pagination elements: {len(hrn_pagination)} links")
            hrn_links = response.css('div[class*="pagination"] a::attr(href), nav a::attr(href), .pager a::attr(href)').getall()
            next_links.extend(hrn_links)

        # Log all found pagination links
        if next_links:
            self.logger.info(f"Found {len(next_links)} potential pagination links: {next_links[:5]}...")  # Show first 5

        # Clean and validate links
        unique_next_links = list(dict.fromkeys(next_links))  # Remove duplicates while preserving order
        valid_next_links = []

        for link in unique_next_links:
            if link and link != response.url and link != '#':
                # Make sure it's a valid URL
                full_url = response.urljoin(link)
                if full_url not in [response.url]:  # Avoid current page
                    valid_next_links.append(full_url)

        self.logger.info(f"Valid next links after filtering: {valid_next_links}")

        # If we have 250 results and expect more pages, prioritize the most likely next page
        if valid_next_links:
            # Sort by likelihood (prefer numeric increments, then "next" text, then others)
            def pagination_priority(url):
                if current_page:
                    expected_page = current_page + 1
                    if f"page={expected_page}" in url or f"page/{expected_page}" in url:
                        return 0  # Highest priority
                    elif str(expected_page) in url:
                        return 1

                if 'next' in url.lower():
                    return 2
                return 3

            valid_next_links.sort(key=pagination_priority)
            next_url = valid_next_links[0]

            self.logger.info(f"Following next page: {next_url} (chosen from {len(valid_next_links)} options)")

            yield scrapy.Request(
                next_url,
                meta={
                    'playwright': True,
                    'playwright_wait_time': 5000,
                    'playwright_wait_for': 'table',
                },
                callback=self.parse,
                dont_filter=True
            )
        else:
            self.logger.info("No pagination links found - either single page or pagination complete")

            # Last resort: try multiple pagination URL patterns for HRN
            if current_page:
                next_page = current_page + 1
                base_url = response.url.split('?')[0].split('#')[0]  # Clean URL

                # Try different pagination URL patterns
                potential_urls = [
                    f"{base_url}?page={next_page}",
                    f"{base_url}?p={next_page}",
                    f"{base_url}&page={next_page}",
                    f"{base_url}/page/{next_page}",
                    f"{base_url}/page{next_page}",
                    f"{base_url}/{next_page}",
                    f"{response.url}&page={next_page}" if '?' in response.url else f"{response.url}?page={next_page}",
                ]

                self.logger.info(f"Trying constructed pagination URLs: {potential_urls}")

                for url in potential_urls:
                    yield scrapy.Request(
                        url,
                        meta={
                            'playwright': True,
                            'playwright_wait_time': 5000,
                            'playwright_wait_for': 'table',
                            'pagination_attempt': True,
                        },
                        callback=self.parse_potential_next_page,
                        errback=self.handle_pagination_error,
                        dont_filter=True
                    )
                    break  # Try only the first one to avoid duplicates

    def parse_potential_next_page(self, response):
        """Parse a potential next page to verify it has new content"""
        # Count rankings on this page
        tables = response.css('table')
        ranking_count = 0

        for table in tables:
            headers = table.css('th::text').getall()
            header_text = ' '.join(headers).lower()
            if any(keyword in header_text for keyword in ['rank', 'horse', 'power', 'rating']):
                rows = table.css('tbody tr')
                if not rows:
                    rows = table.css('tr')[1:]
                ranking_count += len(rows)

        if ranking_count > 0:
            self.logger.info(f"Successfully found next page with {ranking_count} rankings: {response.url}")
            # Process this page normally
            yield from self.parse(response)
        else:
            self.logger.info(f"No rankings found on potential next page: {response.url}")
            # This isn't a valid next page

    def handle_pagination_error(self, failure):
        """Handle pagination errors gracefully"""
        self.logger.info(f"Pagination attempt failed: {failure.request.url} - probably reached end of results")

    def extract_current_page(self, response):
        """Extract current page number from URL or page content"""
        # Try URL patterns
        url = response.url

        # Pattern: ?page=N or &page=N
        page_match = re.search(r'[?&]page=(\d+)', url)
        if page_match:
            return int(page_match.group(1))

        # Pattern: /page/N or /page-N
        page_match = re.search(r'/page[-/](\d+)', url)
        if page_match:
            return int(page_match.group(1))

        # Look for current page indicators in the content
        current_indicators = response.css('.current, .active, [class*="current"], [class*="active"]::text').getall()
        for indicator in current_indicators:
            if indicator.isdigit():
                return int(indicator)

        # Default to page 1 if no indicators found
        return 1

    def extract_page_number_from_url(self, url):
        """Extract page number from a URL"""
        page_match = re.search(r'[?&]page=(\d+)', url)
        if page_match:
            return int(page_match.group(1))

        page_match = re.search(r'/page[-/](\d+)', url)
        if page_match:
            return int(page_match.group(1))

        # Look for any number in the URL that might be a page
        numbers = re.findall(r'\d+', url)
        if numbers:
            return int(numbers[-1])  # Take the last number as likely page number

        return None

    def clean_text(self, text):
        """Clean and normalize extracted text"""
        if text:
            return text.strip().replace('\n', ' ').replace('\r', '').replace('\t', ' ')
        return None