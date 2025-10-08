"""
Prometheus metrics middleware for Scrapy.

This middleware collects and exposes metrics about spider performance,
including request counts, response times, error rates, and data quality metrics.
"""

import time
from typing import Optional, Union
from urllib.parse import urlparse

from prometheus_client import Counter, Histogram, Gauge, start_http_server
from scrapy import signals
from scrapy.http import Request, Response
from scrapy.spiders import Spider
from scrapy.exceptions import NotConfigured


class PrometheusMiddleware:
    """Middleware to collect and expose Prometheus metrics for Scrapy spiders."""

    def __init__(self, stats, prometheus_port: int = 8000):
        """Initialize the Prometheus middleware.

        Args:
            stats: Scrapy stats collector
            prometheus_port: Port to expose metrics on
        """
        self.stats = stats
        self.prometheus_port = prometheus_port

        # Request metrics
        self.requests_total = Counter(
            'scrapy_requests_total',
            'Total number of requests made',
            ['spider', 'method', 'domain']
        )

        self.responses_total = Counter(
            'scrapy_responses_total',
            'Total number of responses received',
            ['spider', 'status_code', 'domain']
        )

        # Response time metrics
        self.response_time = Histogram(
            'scrapy_response_time_seconds',
            'Response time in seconds',
            ['spider', 'domain'],
            buckets=[0.1, 0.5, 1.0, 2.0, 5.0, 10.0, 30.0, 60.0]
        )

        # Items metrics
        self.items_scraped = Counter(
            'scrapy_items_scraped_total',
            'Total number of items scraped',
            ['spider', 'item_type']
        )

        self.items_dropped = Counter(
            'scrapy_items_dropped_total',
            'Total number of items dropped',
            ['spider', 'reason']
        )

        # Error metrics
        self.spider_errors = Counter(
            'scrapy_spider_errors_total',
            'Total number of spider errors',
            ['spider', 'error_type']
        )

        # Spider status metrics
        self.spider_status = Gauge(
            'scrapy_spider_status',
            'Current spider status (0=stopped, 1=running, 2=finished)',
            ['spider', 'status']
        )

        # Data quality metrics
        self.data_quality_score = Gauge(
            'scrapy_data_quality_score',
            'Data quality score (0-1)',
            ['spider']
        )

        self.unique_tracks_today = Gauge(
            'scrapy_unique_tracks_today',
            'Number of unique tracks scraped today',
            ['spider']
        )

        self.last_successful_scrape = Gauge(
            'scrapy_last_successful_scrape',
            'Timestamp of last successful scrape',
            ['spider']
        )

        # Request tracking for response time calculation
        self._request_start_times = {}

    @classmethod
    def from_crawler(cls, crawler):
        """Create middleware instance from crawler."""
        prometheus_port = crawler.settings.getint('PROMETHEUS_PORT', 8000)
        prometheus_enabled = crawler.settings.getbool('PROMETHEUS_ENABLED', True)

        if not prometheus_enabled:
            raise NotConfigured('Prometheus middleware disabled')

        middleware = cls(crawler.stats, prometheus_port)

        # Connect spider signals
        crawler.signals.connect(middleware.spider_opened, signal=signals.spider_opened)
        crawler.signals.connect(middleware.spider_closed, signal=signals.spider_closed)
        crawler.signals.connect(middleware.item_scraped, signal=signals.item_scraped)
        crawler.signals.connect(middleware.item_dropped, signal=signals.item_dropped)
        crawler.signals.connect(middleware.spider_error, signal=signals.spider_error)

        return middleware

    def spider_opened(self, spider: Spider):
        """Handle spider opened signal."""
        self.spider_status.labels(spider=spider.name, status='running').set(1)
        self.spider_status.labels(spider=spider.name, status='stopped').set(0)
        self.spider_status.labels(spider=spider.name, status='finished').set(0)

        # Start Prometheus HTTP server
        try:
            start_http_server(self.prometheus_port)
            spider.logger.info(f"Prometheus metrics server started on port {self.prometheus_port}")
        except OSError as e:
            if "Address already in use" in str(e):
                spider.logger.info(f"Prometheus server already running on port {self.prometheus_port}")
            else:
                spider.logger.error(f"Failed to start Prometheus server: {e}")

    def spider_closed(self, spider: Spider, reason: str):
        """Handle spider closed signal."""
        self.spider_status.labels(spider=spider.name, status='running').set(0)
        self.spider_status.labels(spider=spider.name, status='stopped').set(0)
        self.spider_status.labels(spider=spider.name, status='finished').set(1)

        # Update last successful scrape timestamp if spider finished successfully
        if reason == 'finished':
            self.last_successful_scrape.labels(spider=spider.name).set(time.time())
            self._update_data_quality_metrics(spider)

    def process_request(self, request: Request, spider: Spider):
        """Process outgoing request."""
        domain = urlparse(request.url).netloc
        self.requests_total.labels(
            spider=spider.name,
            method=request.method,
            domain=domain
        ).inc()

        # Track request start time for response time calculation
        self._request_start_times[id(request)] = time.time()

        return None

    def process_response(self, request: Request, response: Response, spider: Spider):
        """Process incoming response."""
        domain = urlparse(response.url).netloc
        self.responses_total.labels(
            spider=spider.name,
            status_code=response.status,
            domain=domain
        ).inc()

        # Calculate and record response time
        request_id = id(request)
        if request_id in self._request_start_times:
            response_time = time.time() - self._request_start_times[request_id]
            self.response_time.labels(
                spider=spider.name,
                domain=domain
            ).observe(response_time)
            del self._request_start_times[request_id]

        return response

    def process_exception(self, request: Request, exception: Exception, spider: Spider):
        """Process request exception."""
        self.spider_errors.labels(
            spider=spider.name,
            error_type=type(exception).__name__
        ).inc()

        # Clean up request tracking
        request_id = id(request)
        if request_id in self._request_start_times:
            del self._request_start_times[request_id]

        return None

    def item_scraped(self, item: dict, response: Response, spider: Spider):
        """Handle item scraped signal."""
        item_type = item.get('type', 'unknown')
        self.items_scraped.labels(
            spider=spider.name,
            item_type=item_type
        ).inc()

    def item_dropped(self, item: dict, response: Response, exception: Exception, spider: Spider):
        """Handle item dropped signal."""
        self.items_dropped.labels(
            spider=spider.name,
            reason=type(exception).__name__
        ).inc()

    def spider_error(self, failure, response: Response, spider: Spider):
        """Handle spider error signal."""
        self.spider_errors.labels(
            spider=spider.name,
            error_type=failure.type.__name__
        ).inc()

    def _update_data_quality_metrics(self, spider: Spider):
        """Update data quality metrics based on spider statistics."""
        try:
            # Get stats from spider
            item_count = self.stats.get_value(f'{spider.name}/item_scraped_count', 0)
            error_count = self.stats.get_value(f'{spider.name}/spider_exceptions', 0)

            # Calculate data quality score (simple metric: 1 - error_rate)
            if item_count > 0:
                error_rate = error_count / (item_count + error_count)
                quality_score = max(0, 1 - error_rate)
                self.data_quality_score.labels(spider=spider.name).set(quality_score)

            # Update track count for race spiders
            if 'race' in spider.name.lower():
                # This would need to be customized based on your data structure
                # For now, we'll use a placeholder
                self.unique_tracks_today.labels(spider=spider.name).set(0)

        except Exception as e:
            spider.logger.warning(f"Failed to update data quality metrics: {e}")


class PrometheusStatsMiddleware:
    """Additional middleware to collect general statistics for Prometheus."""

    def __init__(self):
        """Initialize the stats middleware."""
        self.crawl_duration = Histogram(
            'scrapy_crawl_duration_seconds',
            'Total crawl duration in seconds',
            ['spider']
        )

        self.concurrent_requests = Gauge(
            'scrapy_concurrent_requests',
            'Current number of concurrent requests',
            ['spider']
        )

    @classmethod
    def from_crawler(cls, crawler):
        """Create middleware instance from crawler."""
        prometheus_enabled = crawler.settings.getbool('PROMETHEUS_ENABLED', True)

        if not prometheus_enabled:
            raise NotConfigured('Prometheus stats middleware disabled')

        middleware = cls()
        crawler.signals.connect(middleware.spider_opened, signal=signals.spider_opened)
        crawler.signals.connect(middleware.spider_closed, signal=signals.spider_closed)

        return middleware

    def spider_opened(self, spider: Spider):
        """Handle spider opened signal."""
        self._start_time = time.time()

    def spider_closed(self, spider: Spider, reason: str):
        """Handle spider closed signal."""
        if hasattr(self, '_start_time'):
            duration = time.time() - self._start_time
            self.crawl_duration.labels(spider=spider.name).observe(duration)