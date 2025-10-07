#!/usr/bin/env python3
"""Production scheduler for horse racing data pipeline.

This scheduler manages the execution of scrapers and data transformations
in a production environment with proper error handling and monitoring.
"""

import os
import time
import logging
import subprocess
import schedule
from datetime import datetime, timedelta
from typing import Optional
import redis
import psycopg2
from celery import Celery

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/app/logs/scheduler.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Initialize Redis and Celery
redis_client = redis.from_url(os.getenv('REDIS_URL', 'redis://localhost:6379/0'))
celery_app = Celery('scheduler', broker=os.getenv('REDIS_URL', 'redis://localhost:6379/0'))

class ProductionScheduler:
    """Production scheduler for horse racing data pipeline."""

    def __init__(self):
        self.db_url = os.getenv('DATABASE_URL')
        self.redis_url = os.getenv('REDIS_URL')

    def check_database_connection(self) -> bool:
        """Check if database is accessible."""
        try:
            conn = psycopg2.connect(self.db_url)
            conn.close()
            return True
        except Exception as e:
            logger.error(f"Database connection failed: {e}")
            return False

    def run_spider(self, spider_name: str, **kwargs) -> bool:
        """Run a Scrapy spider with error handling."""
        try:
            logger.info(f"Starting spider: {spider_name}")

            # Build command
            cmd = ['scrapy', 'crawl', spider_name]
            for key, value in kwargs.items():
                cmd.extend(['-a', f'{key}={value}'])

            # Run spider
            result = subprocess.run(
                cmd,
                cwd='/app',
                capture_output=True,
                text=True,
                timeout=3600  # 1 hour timeout
            )

            if result.returncode == 0:
                logger.info(f"Spider {spider_name} completed successfully")
                return True
            else:
                logger.error(f"Spider {spider_name} failed: {result.stderr}")
                return False

        except subprocess.TimeoutExpired:
            logger.error(f"Spider {spider_name} timed out")
            return False
        except Exception as e:
            logger.error(f"Error running spider {spider_name}: {e}")
            return False

    def run_dbt_models(self, models: Optional[str] = None) -> bool:
        """Run dbt transformations."""
        try:
            logger.info("Starting dbt transformations")

            # Build dbt command
            cmd = ['dbt', 'run', '--profiles-dir', '.']
            if models:
                cmd.extend(['--select', models])

            result = subprocess.run(
                cmd,
                cwd='/app/dbt_transform',
                capture_output=True,
                text=True,
                timeout=1800  # 30 minutes timeout
            )

            if result.returncode == 0:
                logger.info("dbt transformations completed successfully")
                return True
            else:
                logger.error(f"dbt transformations failed: {result.stderr}")
                return False

        except Exception as e:
            logger.error(f"Error running dbt: {e}")
            return False

    def generate_dbt_docs(self) -> bool:
        """Generate and serve dbt documentation."""
        try:
            logger.info("Generating dbt documentation")

            result = subprocess.run(
                ['dbt', 'docs', 'generate', '--profiles-dir', '.'],
                cwd='/app/dbt_transform',
                capture_output=True,
                text=True,
                timeout=300  # 5 minutes timeout
            )

            if result.returncode == 0:
                logger.info("dbt documentation generated successfully")
                return True
            else:
                logger.error(f"dbt docs generation failed: {result.stderr}")
                return False

        except Exception as e:
            logger.error(f"Error generating dbt docs: {e}")
            return False

    def daily_pipeline(self):
        """Complete daily data pipeline."""
        logger.info("=== Starting Daily Pipeline ===")

        if not self.check_database_connection():
            logger.error("Database not available, skipping pipeline")
            return

        # Step 1: Scrape race entries for today
        success = self.run_spider('hrn_daily_racing_entries', today_only='true')
        if not success:
            logger.error("Race entries scraping failed, continuing with other tasks...")

        # Step 2: Scrape power rankings
        success = self.run_spider('power_rankings')
        if not success:
            logger.error("Power rankings scraping failed, continuing...")

        # Step 3: Scrape news
        success = self.run_spider('hrn_news')
        if not success:
            logger.error("News scraping failed, continuing...")

        # Step 4: Run data transformations
        time.sleep(60)  # Wait for data to be inserted
        success = self.run_dbt_models()
        if not success:
            logger.error("dbt transformations failed")

        # Step 5: Update documentation
        self.generate_dbt_docs()

        logger.info("=== Daily Pipeline Complete ===")

    def historical_backfill(self, days_back: int = 7):
        """Backfill historical data."""
        logger.info(f"=== Starting Historical Backfill ({days_back} days) ===")

        if not self.check_database_connection():
            logger.error("Database not available, skipping backfill")
            return

        # Scrape historical race entries
        success = self.run_spider('hrn_daily_racing_entries', days_back=str(days_back))
        if success:
            # Run transformations for historical data
            time.sleep(120)  # Wait for data insertion
            self.run_dbt_models()

        logger.info("=== Historical Backfill Complete ===")

    def evening_results_pipeline(self):
        """Evening pipeline to collect race results and payouts."""
        logger.info("=== Starting Evening Results Pipeline ===")

        if not self.check_database_connection():
            logger.error("Database not available, skipping evening pipeline")
            return

        # Scrape results for today
        success = self.run_spider('bh_race_results_spider')
        if success:
            # Transform results data
            time.sleep(60)
            self.run_dbt_models('marts.fct_race_results marts.fct_race_payouts')

        logger.info("=== Evening Results Pipeline Complete ===")

def main():
    """Main scheduler loop."""
    scheduler = ProductionScheduler()

    # Schedule daily tasks
    schedule.every().day.at("06:00").do(scheduler.daily_pipeline)
    schedule.every().day.at("20:00").do(scheduler.evening_results_pipeline)

    # Schedule weekly backfill
    schedule.every().sunday.at("02:00").do(scheduler.historical_backfill, days_back=7)

    # Schedule hourly health checks
    schedule.every().hour.do(scheduler.check_database_connection)

    logger.info("Production scheduler started")
    logger.info("Schedule:")
    logger.info("- Daily pipeline: 06:00")
    logger.info("- Evening results: 20:00")
    logger.info("- Weekly backfill: Sunday 02:00")
    logger.info("- Health checks: Every hour")

    while True:
        try:
            schedule.run_pending()
            time.sleep(60)  # Check every minute
        except KeyboardInterrupt:
            logger.info("Scheduler stopped by user")
            break
        except Exception as e:
            logger.error(f"Scheduler error: {e}")
            time.sleep(300)  # Wait 5 minutes before retrying

if __name__ == "__main__":
    main()