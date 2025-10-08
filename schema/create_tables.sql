-- Schema definitions for horse racing scraper
-- These tables are managed by the Scrapy pipeline but documented here for reference

-- Main data storage table
CREATE TABLE IF NOT EXISTS raw_scraped_data (
    id SERIAL PRIMARY KEY,
    spider_name VARCHAR(255) NOT NULL,
    source_url TEXT NOT NULL,
    raw_data JSONB NOT NULL,
    crawl_run_id UUID NOT NULL,
    data_hash VARCHAR(64) NOT NULL UNIQUE,
    item_type VARCHAR(50) NOT NULL CHECK (item_type IN ('race_entry', 'track_info', 'race_card', 'race_result', 'race_payout', 'news', 'hrn_speed_result')),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_raw_scraped_data_spider_name ON raw_scraped_data(spider_name);
CREATE INDEX IF NOT EXISTS idx_raw_scraped_data_item_type ON raw_scraped_data(item_type);
CREATE INDEX IF NOT EXISTS idx_raw_scraped_data_created_at ON raw_scraped_data(created_at);
CREATE INDEX IF NOT EXISTS idx_raw_scraped_data_crawl_run_id ON raw_scraped_data(crawl_run_id);

-- Crawl run tracking table
CREATE TABLE IF NOT EXISTS crawl_runs (
    id UUID PRIMARY KEY,
    spider_name VARCHAR(255),
    source_domain VARCHAR(255),
    configuration JSONB,
    status VARCHAR(50) DEFAULT 'running' CHECK (status IN ('running', 'completed', 'failed')),
    total_items INTEGER DEFAULT 0,
    started_at TIMESTAMP DEFAULT NOW(),
    finished_at TIMESTAMP,
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for crawl runs
CREATE INDEX IF NOT EXISTS idx_crawl_runs_spider_name ON crawl_runs(spider_name);
CREATE INDEX IF NOT EXISTS idx_crawl_runs_status ON crawl_runs(status);
CREATE INDEX IF NOT EXISTS idx_crawl_runs_started_at ON crawl_runs(started_at);