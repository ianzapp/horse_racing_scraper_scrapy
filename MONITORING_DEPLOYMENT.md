# Monitoring Stack Deployment Guide

This guide provides step-by-step instructions for deploying the complete monitoring stack for the horse racing data pipeline.

## 📊 Architecture Overview

The monitoring stack includes:
- **Prometheus**: Metrics collection and alerting
- **Grafana**: Visualization and dashboards
- **PostgreSQL Exporter**: Database metrics
- **Redis Exporter**: Cache metrics
- **Node Exporter**: System metrics
- **Scrapy Metrics**: Custom application metrics

## 🚀 Quick Deployment

### Option 1: Production Docker Compose (Recommended)

```bash
# 1. Ensure you have the complete monitoring structure
cd horse_racing_scraper_scrapy

# 2. Verify monitoring files exist
ls -la monitoring/
# Should show: grafana/, prometheus.yml, alerting_rules.yml

# 3. Deploy the full production stack
docker-compose -f docker-compose.prod.yml up -d

# 4. Verify services are running
docker-compose -f docker-compose.prod.yml ps
```

### Option 2: Development Setup

```bash
# 1. Start minimal monitoring stack
docker run -d --name prometheus \\
  -p 9090:9090 \\
  -v $(pwd)/monitoring/prometheus.yml:/etc/prometheus/prometheus.yml \\
  -v $(pwd)/monitoring/alerting_rules.yml:/etc/prometheus/alerting_rules.yml \\
  prom/prometheus

docker run -d --name grafana \\
  -p 3000:3000 \\
  -v $(pwd)/monitoring/grafana:/etc/grafana/provisioning \\
  grafana/grafana

# 2. Run your spiders with Prometheus metrics enabled
scrapy crawl hrn_race_entries_spider
```

## 📋 Required Infrastructure

### Docker Compose Services

The complete monitoring stack requires these services in `docker-compose.prod.yml`:

```yaml
services:
  # Application services
  scrapy-app:
    # Your scrapy application
    ports:
      - "8000:8000"  # Prometheus metrics endpoint

  postgres:
    # Your database

  redis:
    # Your cache

  # Monitoring services
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./monitoring/alerting_rules.yml:/etc/prometheus/alerting_rules.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
      - '--web.enable-lifecycle'

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD:-admin}
    volumes:
      - grafana_data:/var/lib/grafana
      - ./monitoring/grafana/dashboards:/etc/grafana/provisioning/dashboards
      - ./monitoring/grafana/datasources:/etc/grafana/provisioning/datasources

  postgres-exporter:
    image: prometheuscommunity/postgres-exporter:latest
    ports:
      - "9187:9187"
    environment:
      DATA_SOURCE_NAME: "postgresql://${DB_USER}:${DB_PASSWORD}@postgres:5432/${DB_NAME}?sslmode=disable"
    depends_on:
      - postgres

  redis-exporter:
    image: oliver006/redis_exporter:latest
    ports:
      - "9121:9121"
    environment:
      REDIS_ADDR: "redis://redis:6379"
    depends_on:
      - redis

  node-exporter:
    image: prom/node-exporter:latest
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'

volumes:
  prometheus_data:
  grafana_data:
```

## 🔧 Configuration Files

### 1. Prometheus Configuration (`monitoring/prometheus.yml`)

The Prometheus configuration includes:
- **Scrapy metrics**: Exposed on port 8000 from your application
- **PostgreSQL metrics**: Via postgres-exporter on port 9187
- **Redis metrics**: Via redis-exporter on port 9121
- **System metrics**: Via node-exporter on port 9100
- **Alerting rules**: Defined in `alerting_rules.yml`

### 2. Grafana Dashboards

Four comprehensive dashboards are provided:

#### Scrapy Metrics Dashboard (`scrapy-metrics.json`)
- Items scraped rate and totals
- Response times and error rates
- Spider status tracking

#### Database Dashboard (`database-metrics.json`)
- Total records and daily counts
- Active connections and running spiders
- Recent spider activity and table statistics

#### System Metrics Dashboard (`system-metrics.json`)
- CPU, memory, and disk usage gauges
- Network and disk I/O trends
- Service availability monitoring

#### Business Metrics Dashboard (`business-metrics.json`)
- Track coverage and race entries
- Data freshness indicators
- Data quality completeness metrics

### 3. Alerting Rules (`monitoring/alerting_rules.yml`)

Comprehensive alerting covers:
- **Application alerts**: Spider failures, high error rates, no data collection
- **Infrastructure alerts**: High CPU/memory, disk space, service failures
- **Business alerts**: No data today, data quality issues, missing tracks

## 📈 Accessing Dashboards

Once deployed, access the monitoring interfaces:

| Service | URL | Default Credentials |
|---------|-----|-------------------|
| Grafana | http://localhost:3000 | admin/admin |
| Prometheus | http://localhost:9090 | None |
| Scrapy Metrics | http://localhost:8000/metrics | None |

### Grafana Dashboard URLs
- Scrapy Metrics: http://localhost:3000/d/scrapy-metrics
- Database Monitoring: http://localhost:3000/d/database-metrics
- System Metrics: http://localhost:3000/d/system-metrics
- Business Metrics: http://localhost:3000/d/business-metrics

## 🔧 Scrapy Configuration

### Enable Prometheus Middleware

The Prometheus middleware is automatically enabled in `settings.py`:

```python
# Downloader middlewares
DOWNLOADER_MIDDLEWARES = {
    "horse_racing_scraper_scrapy.prometheus_middleware.PrometheusMiddleware": 100,
}

# Prometheus settings
PROMETHEUS_ENABLED = True
PROMETHEUS_PORT = 8000
```

### Custom Metrics Available

The middleware exposes these metrics:
- `scrapy_requests_total`: Total requests by spider/method/domain
- `scrapy_responses_total`: Total responses by spider/status/domain
- `scrapy_response_time_seconds`: Response time histograms
- `scrapy_items_scraped_total`: Items scraped by spider/type
- `scrapy_spider_errors_total`: Errors by spider/type
- `scrapy_spider_status`: Current spider status
- `scrapy_data_quality_score`: Data quality metrics

## 🚨 Alert Configuration

### Slack Integration (Optional)

To receive alerts in Slack:

1. Create a Slack webhook URL
2. Add alertmanager service to docker-compose:

```yaml
alertmanager:
  image: prom/alertmanager:latest
  ports:
    - "9093:9093"
  volumes:
    - ./monitoring/alertmanager.yml:/etc/alertmanager/alertmanager.yml
```

3. Create `monitoring/alertmanager.yml`:

```yaml
global:
  slack_api_url: 'YOUR_SLACK_WEBHOOK_URL'

route:
  group_by: ['alertname']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 12h
  receiver: 'slack-notifications'

receivers:
  - name: 'slack-notifications'
    slack_configs:
      - channel: '#horse-racing-alerts'
        title: 'Horse Racing Pipeline Alert'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
```

## 🔍 Troubleshooting

### Common Issues

1. **Grafana dashboards not loading**
   ```bash
   # Check provisioning logs
   docker-compose logs grafana

   # Verify dashboard files exist
   ls -la monitoring/grafana/dashboards/
   ```

2. **Prometheus targets down**
   ```bash
   # Check target status
   curl http://localhost:9090/api/v1/targets

   # Verify service connectivity
   docker-compose ps
   ```

3. **No Scrapy metrics appearing**
   ```bash
   # Verify metrics endpoint
   curl http://localhost:8000/metrics

   # Check scrapy logs
   scrapy crawl hrn_race_entries_spider -L INFO
   ```

4. **Database exporter connection issues**
   ```bash
   # Test database connection
   docker-compose exec postgres-exporter /bin/sh
   # Inside container: pg_isready -h postgres -p 5432
   ```

### Log Analysis

```bash
# View all service logs
docker-compose -f docker-compose.prod.yml logs

# Monitor specific service
docker-compose logs -f prometheus
docker-compose logs -f grafana

# Check for configuration errors
docker-compose logs prometheus | grep -i error
```

### Performance Tuning

1. **Prometheus Storage**
   ```yaml
   # Adjust retention in prometheus command
   command:
     - '--storage.tsdb.retention.time=30d'
     - '--storage.tsdb.retention.size=10GB'
   ```

2. **Scrapy Metrics Frequency**
   ```python
   # In settings.py, adjust collection interval
   PROMETHEUS_SCRAPE_INTERVAL = 30  # seconds
   ```

## 📊 Monitoring Best Practices

### Dashboard Organization

1. **Operations Team**: System and Scrapy metrics dashboards
2. **Business Team**: Business metrics dashboard
3. **Development Team**: Database and error tracking dashboards

### Alert Severity Levels

- **Critical**: Service down, no data collection, system resources exhausted
- **Warning**: High error rates, slow responses, data quality issues
- **Info**: Normal operational events, completed scrapes

### Data Retention

- **Prometheus**: 30 days of detailed metrics
- **Grafana**: Persistent dashboard configurations
- **PostgreSQL**: Long-term data storage for business analytics

## 🔄 Maintenance

### Regular Tasks

```bash
# Weekly: Check alert rules are firing correctly
curl http://localhost:9090/api/v1/rules

# Monthly: Review and tune alert thresholds
# Quarterly: Update dashboard queries for new data sources
# Annually: Review retention policies and storage usage
```

### Updates

```bash
# Update monitoring stack
docker-compose -f docker-compose.prod.yml pull
docker-compose -f docker-compose.prod.yml up -d

# Backup Grafana dashboards
docker exec grafana grafana-cli admin export-dashboard > backup.json
```

## 📚 Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Scrapy Monitoring Guide](https://docs.scrapy.org/en/latest/topics/stats.html)
- [PostgreSQL Monitoring](https://github.com/prometheus-community/postgres_exporter)

---

**Next Steps**: Once monitoring is deployed, consider implementing [advanced analytics](PRODUCTION_DEPLOYMENT.md#monitoring-access) and [automated reporting](README.md#-data-transformation-with-dbt) features.