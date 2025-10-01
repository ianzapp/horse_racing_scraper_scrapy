-- Main raw data table
CREATE TABLE raw_scraped_data (
    id BIGSERIAL PRIMARY KEY,
    spider_name VARCHAR(100) NOT NULL,
    source_url TEXT,
    raw_data JSONB NOT NULL,
    scraped_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    crawl_run_id UUID NOT NULL,
    data_hash VARCHAR(64),  -- For deduplication
    item_type VARCHAR(50),  -- 'product', 'listing', 'article', etc.
    processing_status VARCHAR(20) DEFAULT 'pending',  -- 'pending', 'processing', 'completed', 'failed'
    processed_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Crawl runs metadata
CREATE TABLE crawl_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    spider_name VARCHAR(100) NOT NULL,
    source_domain VARCHAR(200),
    started_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    finished_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) DEFAULT 'running',  -- 'running', 'completed', 'failed', 'cancelled'
    total_items INTEGER DEFAULT 0,
    processed_items INTEGER DEFAULT 0,
    failed_items INTEGER DEFAULT 0,
    configuration JSONB,  -- Store spider settings used
    error_summary TEXT
);

-- Processing errors (for detailed error tracking)
CREATE TABLE processing_errors (
    id BIGSERIAL PRIMARY KEY,
    raw_data_id BIGINT REFERENCES raw_scraped_data(id),
    error_type VARCHAR(50),
    error_message TEXT,
    stack_trace TEXT,
    occurred_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    retry_number INTEGER
);

-- Optional: Normalized extraction results tracking
CREATE TABLE extraction_results (
    id BIGSERIAL PRIMARY KEY,
    raw_data_id BIGINT REFERENCES raw_scraped_data(id),
    extracted_fields JSONB,  -- What fields were successfully extracted
    extraction_version VARCHAR(20),  -- Track different extraction logic versions
    extracted_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    extractor_name VARCHAR(100)  -- Which extraction process was used
);

-- Essential indexes
CREATE INDEX idx_raw_scraped_spider_status ON raw_scraped_data(spider_name, processing_status);
CREATE INDEX idx_raw_scraped_crawl_run ON raw_scraped_data(crawl_run_id);
CREATE INDEX idx_raw_scraped_scraped_at ON raw_scraped_data(scraped_at);
CREATE INDEX idx_raw_scraped_hash ON raw_scraped_data(data_hash);
CREATE INDEX idx_raw_scraped_url ON raw_scraped_data(source_url);

-- JSONB indexes for common queries
--CREATE GIN INDEX idx_raw_data_gin ON raw_scraped_data USING GIN (raw_data);
--CREATE INDEX idx_raw_data_title ON raw_scraped_data USING GIN ((raw_data->>'title'));
--CREATE INDEX idx_raw_data_price ON raw_scraped_data USING GIN ((raw_data->>'price'));

-- Crawl runs indexes
CREATE INDEX idx_crawl_runs_spider_status ON crawl_runs(spider_name, status);
CREATE INDEX idx_crawl_runs_started ON crawl_runs(started_at);

-- Processing tracking
CREATE INDEX idx_processing_errors_raw_id ON processing_errors(raw_data_id);
CREATE INDEX idx_extraction_results_raw_id ON extraction_results(raw_data_id);

-- Get unprocessed items for transformation
SELECT id, spider_name, raw_data, source_url, item_type
FROM raw_scraped_data 
WHERE processing_status = 'pending'
  AND spider_name = 'products'
ORDER BY scraped_at
LIMIT 100;

-- Monitor crawl progress
SELECT 
    spider_name,
    status,
    total_items,
    processed_items,
    failed_items,
    (processed_items::float / NULLIF(total_items, 0) * 100)::int as progress_pct,
    started_at,
    finished_at
FROM crawl_runs 
WHERE started_at >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY started_at DESC;

-- Find processing errors
SELECT 
    r.spider_name,
    r.source_url,
    r.processing_status,
    r.error_message,
    r.retry_count
FROM raw_scraped_data r
WHERE r.processing_status = 'failed'
  AND r.scraped_at >= CURRENT_DATE - INTERVAL '1 day';

-- Data quality checks
SELECT 
    spider_name,
    item_type,
    COUNT(*) as total_items,
    COUNT(CASE WHEN raw_data ? 'title' THEN 1 END) as has_title,
    COUNT(CASE WHEN raw_data ? 'price' THEN 1 END) as has_price,
    AVG(jsonb_array_length(raw_data->'images')) as avg_images
FROM raw_scraped_data
WHERE scraped_at >= CURRENT_DATE
GROUP BY spider_name, item_type;