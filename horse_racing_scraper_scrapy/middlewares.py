"""Spider middleware for Scrapy project.

This module contains custom middleware classes for handling requests and responses,
including Playwright integration for JavaScript rendering.
"""

import asyncio
import random
from scrapy import signals
from scrapy.http import HtmlResponse
from scrapy.exceptions import NotConfigured
from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeoutError


class PlaywrightMiddleware:
    """Scrapy downloader middleware that uses Playwright for JavaScript rendering"""

    # List of realistic user agents for rotation
    USER_AGENTS = [
        ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
         '(KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'),
        ('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
         '(KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'),
        ('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
         '(KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'),
        ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
         '(KHTML, like Gecko) Chrome/92.0.4515.159 Safari/537.36'),
        ('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
         '(KHTML, like Gecko) Chrome/92.0.4515.159 Safari/537.36'),
        ('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
         '(KHTML, like Gecko) Chrome/92.0.4515.159 Safari/537.36'),
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:90.0) Gecko/20100101 Firefox/90.0',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:90.0) Gecko/20100101 Firefox/90.0',
        'Mozilla/5.0 (X11; Linux x86_64; rv:90.0) Gecko/20100101 Firefox/90.0',
    ]

    def __init__(self, headless=True, browser_type='chromium', timeout=30000):
        self.headless = headless
        self.browser_type = browser_type
        self.timeout = timeout
        self.playwright = None
        self.browser = None
        self.browser_context = None

    @classmethod
    def from_crawler(cls, crawler):
        # Get settings from Scrapy settings
        headless = crawler.settings.getbool('PLAYWRIGHT_HEADLESS', True)
        browser_type = crawler.settings.get('PLAYWRIGHT_BROWSER_TYPE', 'chromium')
        timeout = crawler.settings.getint('PLAYWRIGHT_TIMEOUT', 30000)

        if not crawler.settings.getbool('PLAYWRIGHT_ENABLED', False):
            raise NotConfigured('Playwright middleware not enabled')

        middleware = cls(
            headless=headless,
            browser_type=browser_type,
            timeout=timeout
        )

        crawler.signals.connect(middleware.spider_opened, signal=signals.spider_opened)
        crawler.signals.connect(middleware.spider_closed, signal=signals.spider_closed)

        return middleware

    async def spider_opened(self, spider):
        spider.logger.info("Starting Playwright browser...")
        self.playwright = await async_playwright().start()

        if self.browser_type == 'firefox':
            self.browser = await self.playwright.firefox.launch(headless=self.headless)
        elif self.browser_type == 'webkit':
            self.browser = await self.playwright.webkit.launch(headless=self.headless)
        else:  # chromium (default)
            self.browser = await self.playwright.chromium.launch(headless=self.headless)

        user_agent = ('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
                     'AppleWebKit/537.36 (KHTML, like Gecko) '
                     'Chrome/120.0.0.0 Safari/537.36')
        self.browser_context = await self.browser.new_context(
            viewport={'width': 1920, 'height': 1080},
            user_agent=user_agent
        )

        spider.logger.info(f"Playwright {self.browser_type} browser started")

    async def spider_closed(self, spider):
        if self.browser_context:
            await self.browser_context.close()
        if self.browser:
            await self.browser.close()
        if self.playwright:
            await self.playwright.stop()
        spider.logger.info("Playwright browser closed")

    def process_request(self, request, spider):
        # Check if request should use Playwright
        if request.meta.get('playwright', False):
            # Return a deferred that will be handled by process_response
            spider.logger.info(f"Processing {request.url} with Playwright")
            return asyncio.create_task(self._process_request_async(request, spider))
        return None

    async def _process_request_async(self, request, spider):
        try:
            page = await self.browser_context.new_page()

            # Rotate user agent for each request
            random_user_agent = random.choice(self.USER_AGENTS)
            await page.set_extra_http_headers({'User-Agent': random_user_agent})
            spider.logger.debug(f"Using user agent: {random_user_agent}")

            # Set up additional request headers
            headers = {}
            if request.headers:
                for key, value in request.headers.items():
                    headers[key.decode()] = value[0].decode()

            if headers:
                await page.set_extra_http_headers(headers)

            # Navigate to the page
            spider.logger.info(f"Loading page: {request.url}")
            await page.goto(request.url, timeout=self.timeout, wait_until='domcontentloaded')

            # Wait for specific elements if specified
            wait_for = request.meta.get('playwright_wait_for')
            if wait_for:
                try:
                    await page.wait_for_selector(wait_for, timeout=10000)
                except PlaywrightTimeoutError:
                    spider.logger.warning(f"Timeout waiting for selector: {wait_for}")

            # Wait for additional time if specified
            wait_time = request.meta.get('playwright_wait_time', 2000)
            await page.wait_for_timeout(wait_time)

            # Get page content
            html = await page.content()
            await page.close()

            # Create Scrapy response
            return HtmlResponse(
                url=request.url,
                body=html,
                encoding='utf-8',
                request=request
            )

        except Exception as e:
            spider.logger.error(f"Playwright error for {request.url}: {e}")
            if 'page' in locals():
                await page.close()
            raise


class HorseRacingScraperScrapySpiderMiddleware:
    # Not all methods need to be defined. If a method is not defined,
    # scrapy acts as if the spider middleware does not modify the
    # passed objects.

    @classmethod
    def from_crawler(cls, crawler):
        # This method is used by Scrapy to create your spiders.
        s = cls()
        crawler.signals.connect(s.spider_opened, signal=signals.spider_opened)
        return s

    def process_spider_input(self, response, spider):
        # Called for each response that goes through the spider
        # middleware and into the spider.

        # Should return None or raise an exception.
        return None

    def process_spider_output(self, response, result, spider):
        # Called with the results returned from the Spider, after
        # it has processed the response.

        # Must return an iterable of Request, or item objects.
        for i in result:
            yield i

    def process_spider_exception(self, response, exception, spider):
        # Called when a spider or process_spider_input() method
        # (from other spider middleware) raises an exception.

        # Should return either None or an iterable of Request or item objects.
        pass

    async def process_start(self, start):
        # Called with an async iterator over the spider start() method or the
        # maching method of an earlier spider middleware.
        async for item_or_request in start:
            yield item_or_request

    def spider_opened(self, spider):
        spider.logger.info("Spider opened: %s" % spider.name)


class HorseRacingScraperScrapyDownloaderMiddleware:
    # Not all methods need to be defined. If a method is not defined,
    # scrapy acts as if the downloader middleware does not modify the
    # passed objects.

    @classmethod
    def from_crawler(cls, crawler):
        # This method is used by Scrapy to create your spiders.
        s = cls()
        crawler.signals.connect(s.spider_opened, signal=signals.spider_opened)
        return s

    def process_request(self, request, spider):
        # Called for each request that goes through the downloader
        # middleware.

        # Must either:
        # - return None: continue processing this request
        # - or return a Response object
        # - or return a Request object
        # - or raise IgnoreRequest: process_exception() methods of
        #   installed downloader middleware will be called
        return None

    def process_response(self, request, response, spider):
        # Called with the response returned from the downloader.

        # Must either;
        # - return a Response object
        # - return a Request object
        # - or raise IgnoreRequest
        return response

    def process_exception(self, request, exception, spider):
        # Called when a download handler or a process_request()
        # (from other downloader middleware) raises an exception.

        # Must either:
        # - return None: continue processing this exception
        # - return a Response object: stops process_exception() chain
        # - return a Request object: stops process_exception() chain
        pass

    def spider_opened(self, spider):
        spider.logger.info("Spider opened: %s" % spider.name)
