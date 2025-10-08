from urllib.parse import urljoin

import scrapy


class HrnNewsSpider(scrapy.Spider):
    name = "hrn_news_spider"
    allowed_domains = ["horseracingnation.com"]
    start_urls = ["https://www.horseracingnation.com/news"]

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
            self.logger.info(f"Requesting URL: {url}")
            yield scrapy.Request(
                url,
                meta={
                    'playwright': True,
                    'playwright_wait_time': 3000
                },
                callback=self.parse
            )

    def parse(self, response):
        """Parse main page and discover date ranges, then process each date individually"""
        self.logger.info(f"Processing main page: {response.url}")

        # Collect the commad line parameters
        start_page = getattr(self, 'start_page', None)
        end_page = getattr(self, 'end_page', None)
        num_pages = getattr(self, 'num_pages', None)

        if start_page is None:
            start_page = 1
        else:
            start_page = int(start_page)

        if end_page is None and num_pages is not None:
            if num_pages.lower() == "max":
                # Extract ALL track links to discover the date range
                page_numbers = response.css('ul.pagination li.page-item .page-link::text').re(r'\d+')
                if page_numbers:
                    end_page = max(int(num) for num in page_numbers) + 1
                    self.logger.info(f"Found {end_page} total links on page")
            else:
                num_pages = int(num_pages)
                end_page = start_page + num_pages
        elif end_page is not None:
            end_page = int(end_page) + 1
        else:
            end_page = start_page + 1  # Default to 1 pages if nothing is specified

        self.logger.info(f"Processing pages from {start_page} to {end_page}")

        for page in range(start_page, end_page): # type: ignore
            yield scrapy.Request(f"{response.url}?page={page}", callback=self.parse_news_feed)

    def parse_news_feed(self, response):
        """Parse individual news feed pages to extract articles"""
        self.logger.info(f"Processing news feed page: {response.url}")

        articles = response.css('article')
        self.logger.info(f"Found {len(articles)}: {response.url}")

        for article in articles:
            href = article.css('h3 a::attr(href)').get()
            if href:
                article_url = urljoin(response.url, href.strip())
                yield scrapy.Request(article_url, callback=self.parse_article)
            else:
                self.logger.warning(f"No href found for article: {article.get()}")

    def parse_article(self, response):
        """Parse individual article pages to extract content"""
        self.logger.info(f"Processing article page: {response.url}")

        title = response.css('h1::text').get()
        author = response.css('span.byline::text').get()
        pub_date = response.css('time::text').get()

        # Safely strip values if they exist
        title = title.strip() if title else 'No Title'
        author = author.strip() if author else 'Unknown Author'
        pub_date = pub_date.strip() if pub_date else ''
        content_paragraphs = response.css('div p::text').getall()
        content = ' '.join([para.strip() for para in content_paragraphs if para.strip()])

        # Only yield if we have essential data
        if title and title != 'No Title':
            yield {
                'type': 'news',
                'title': title,
                'author': author,
                'publication_date': pub_date,
                'content': content,
                'news_source': 'Horse Racing Nation',
                'url': response.url
            }
        else:
            self.logger.warning(f"Skipping article with no title: {response.url}")
