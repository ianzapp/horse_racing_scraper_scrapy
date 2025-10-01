# Define your item pipelines here
#
# Don't forget to add your pipeline to the ITEM_PIPELINES setting
# See: https://docs.scrapy.org/en/latest/topics/item-pipeline.html


import json
import hashlib
import uuid
from datetime import datetime, timezone
import psycopg2
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

# useful for handling different item types with a single interface
from itemadapter import ItemAdapter


class HorseRacingScraperScrapyPipeline:
    def process_item(self, item, spider):
        return item



class EnhancedRawJSONPipeline:
    def __init__(self):
        #self.engine = create_engine('postgresql://user:pass@localhost/db')
        self.engine = create_engine('postgresql://postgres:0UcZXEAJMouLadi0@db.itzwxbopifncdbrhzlma.supabase.co:5432/postgres')
        self.crawl_run_id = None
        
    def open_spider(self, spider):
        self.crawl_run_id = str(uuid.uuid4())
        spider.crawl_run_id = self.crawl_run_id
        
        # Create crawl run record
        query = text("""
            INSERT INTO crawl_runs (id, spider_name, source_domain, configuration)
            VALUES (:id, :spider, :domain, :config)
        """)
        
        def serialize_value(value):
            try:
                json.dumps(value)
                return value
            except (TypeError, ValueError):
                return str(value)

        config = {
            'settings': {k: serialize_value(v) for k, v in spider.settings.items()},
            'start_urls': getattr(spider, 'start_urls', []),
            'custom_settings': getattr(spider, 'custom_settings', {})
        }
        
        with self.engine.connect() as conn:
            conn.execute(query, {
                'id': self.crawl_run_id,
                'spider': spider.name,
                'domain': getattr(spider, 'allowed_domains', [None])[0],
                'config': json.dumps(config)
            })
            conn.commit()
            
    def process_item(self, item, spider):
        try:
            item_dict = dict(item)
            
            # Generate content hash for deduplication
            content_str = json.dumps(item_dict, sort_keys=True)
            data_hash = hashlib.sha256(content_str.encode()).hexdigest()
            
            # Check for duplicates
            if self.is_duplicate(data_hash):
                spider.logger.info(f"Duplicate item found: {item_dict.get('url', 'no url')}")
                return item
            
            # Determine item type
            item_type = self.determine_item_type(item_dict)
            
            query = text("""
                INSERT INTO raw_scraped_data
                (spider_name, source_url, raw_data, crawl_run_id, data_hash, item_type)
                VALUES (:spider, :url, CAST(:data AS jsonb), :run_id, :hash, :type)
            """)
            
            with self.engine.connect() as conn:
                conn.execute(query, {
                    'spider': spider.name,
                    'url': item_dict.get('url', ''),
                    'data': json.dumps(item_dict),
                    'run_id': self.crawl_run_id,
                    'hash': data_hash,
                    'type': item_type
                })
                conn.commit()
                
            # Update crawl run stats
            self.update_crawl_stats('total_items')
            
        except Exception as e:
            spider.logger.error(f"Failed to store item: {e}")
            self.update_crawl_stats('failed_items')
            
        return item
        
    def close_spider(self, spider):
        # Finalize crawl run
        query = text("""
            UPDATE crawl_runs 
            SET status = 'completed', finished_at = CURRENT_TIMESTAMP
            WHERE id = :id
        """)
        
        with self.engine.connect() as conn:
            conn.execute(query, {'id': self.crawl_run_id})
            conn.commit()
            
    def is_duplicate(self, data_hash):
        query = text("SELECT 1 FROM raw_scraped_data WHERE data_hash = :hash LIMIT 1")
        with self.engine.connect() as conn:
            result = conn.execute(query, {'hash': data_hash}).fetchone()
            return result is not None
            
    def determine_item_type(self, item_dict):
        # Simple logic to categorize items
        if 'rating' in item_dict:
            return 'rating'
        elif 'content' in item_dict:
            return 'article'
        elif 'company_name' in item_dict:
            return 'company'
        else:
            return 'general'
            
    def update_crawl_stats(self, field):
        query = text(f"""
            UPDATE crawl_runs 
            SET {field} = {field} + 1, updated_at = CURRENT_TIMESTAMP
            WHERE id = :id
        """)
        
        with self.engine.connect() as conn:
            conn.execute(query, {'id': self.crawl_run_id})
            conn.commit()