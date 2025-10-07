# Production Deployment Guide

This guide covers deploying the horse racing data pipeline in a production environment.

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Scheduler     │    │   Scrapy App    │    │   PostgreSQL    │
│   (Cron Jobs)   │───▶│   (Scrapers)    │───▶│   (Data Store)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │              ┌─────────────────┐              │
         └─────────────▶│     Redis       │              │
                        │   (Queue/Cache) │              │
                        └─────────────────┘              │
                                 │                       │
                        ┌─────────────────┐              │
                        │      dbt        │◀─────────────┘
                        │ (Transformations)│
                        └─────────────────┘
                                 │
                        ┌─────────────────┐
                        │   Monitoring    │
                        │ (Grafana/Alerts)│
                        └─────────────────┘
```

## 🚀 Deployment Options

### Option 1: Docker Compose (Recommended for Small-Medium Scale)

**Prerequisites:**
- Docker & Docker Compose installed
- 4GB+ RAM, 20GB+ storage
- Domain name (optional, for SSL)

**Steps:**
```bash
# 1. Clone repository
git clone <your-repo>
cd horse_racing_scraper_scrapy

# 2. Configure environment
cp .env.production .env
# Edit .env with your actual credentials

# 3. Deploy
docker-compose -f docker-compose.prod.yml up -d

# 4. Initialize database
docker-compose exec postgres psql -U $DB_USER -d horse_racing -f /docker-entrypoint-initdb.d/create_tables.sql

# 5. Run initial dbt setup
docker-compose run dbt dbt deps
docker-compose run dbt dbt run
```

### Option 2: Kubernetes (Recommended for Large Scale)

**Prerequisites:**
- Kubernetes cluster (EKS, GKE, AKS, or self-managed)
- kubectl configured
- Helm (optional)

**Steps:**
```bash
# 1. Create namespace
kubectl create namespace horse-racing

# 2. Deploy database
helm install postgres bitnami/postgresql \
  --namespace horse-racing \
  --set auth.database=horse_racing

# 3. Deploy application
kubectl apply -f k8s/ -n horse-racing

# 4. Set up ingress/load balancer
kubectl apply -f k8s/ingress.yaml
```

### Option 3: Cloud Native (AWS Example)

**Services Used:**
- **ECS Fargate**: Container orchestration
- **RDS PostgreSQL**: Managed database
- **ElastiCache Redis**: Managed cache
- **EventBridge**: Scheduling
- **CloudWatch**: Monitoring

**Steps:**
```bash
# 1. Deploy infrastructure
terraform init
terraform apply

# 2. Deploy containers
aws ecs update-service --service scrapy-service --force-new-deployment

# 3. Set up scheduling
aws events put-rule --name daily-scraping --schedule-expression "cron(0 6 * * ? *)"
```

## ⚙️ Configuration

### Environment Variables

```bash
# Database
DATABASE_URL=postgresql://user:pass@host:5432/dbname
DB_USER=horse_racing_user
DB_PASSWORD=secure_password

# Redis
REDIS_URL=redis://redis:6379/0

# Monitoring
GRAFANA_PASSWORD=admin_password

# Scrapy Settings
ROBOTSTXT_OBEY=true
DOWNLOAD_DELAY=2
CONCURRENT_REQUESTS_PER_DOMAIN=1
```

### Scheduling Configuration

**Daily Pipeline (06:00 AM):**
- Scrape today's race entries
- Scrape power rankings
- Scrape news articles
- Run dbt transformations
- Update documentation

**Evening Pipeline (08:00 PM):**
- Scrape race results
- Scrape payouts
- Transform results data

**Weekly Backfill (Sunday 02:00 AM):**
- Historical data collection
- Data quality checks
- Full model refresh

## 📊 Monitoring & Alerting

### Metrics to Monitor

**Application Metrics:**
- Spider success/failure rates
- Processing time per spider
- Data quality metrics
- Database connection health

**Infrastructure Metrics:**
- CPU/Memory usage
- Disk space
- Network I/O
- Container health

### Alerting Rules

```yaml
# Grafana Alerts
- Spider Failure Rate > 10%
- Database Connection Lost
- Disk Usage > 80%
- Memory Usage > 90%
- No Data Received > 2 hours
```

## 🔐 Security Best Practices

### Database Security
```sql
-- Create read-only user for reporting
CREATE USER reporting_user WITH PASSWORD 'readonly_password';
GRANT SELECT ON ALL TABLES IN SCHEMA public TO reporting_user;

-- Restrict network access
# Allow only application IPs in pg_hba.conf
```

### Container Security
```dockerfile
# Use non-root user
RUN adduser --disabled-password --gecos '' appuser
USER appuser

# Read-only filesystem
docker run --read-only --tmpfs /tmp myapp
```

### Network Security
```yaml
# Docker networks
networks:
  backend:
    driver: bridge
    internal: true  # No external access
  frontend:
    driver: bridge
```

## 🚨 Disaster Recovery

### Backup Strategy

**Database Backups:**
```bash
# Daily automated backups
pg_dump $DATABASE_URL | gzip > backup_$(date +%Y%m%d).sql.gz

# Upload to cloud storage
aws s3 cp backup_$(date +%Y%m%d).sql.gz s3://your-backup-bucket/
```

**Configuration Backups:**
- Environment files
- dbt project files
- Docker configurations

### Recovery Procedures

**Database Recovery:**
```bash
# Restore from backup
gunzip -c backup_20241201.sql.gz | psql $DATABASE_URL

# Restart services
docker-compose restart
```

## 📈 Scaling Considerations

### Horizontal Scaling
- Multiple Scrapy workers
- Load balancing
- Database read replicas
- Redis clustering

### Vertical Scaling
- Increase container resources
- Optimize database queries
- Cache frequently accessed data

### Performance Optimization
```python
# Scrapy settings for production
CONCURRENT_REQUESTS = 16
CONCURRENT_REQUESTS_PER_DOMAIN = 8
DOWNLOAD_DELAY = 1
RANDOMIZE_DOWNLOAD_DELAY = True
AUTOTHROTTLE_ENABLED = True
```

## 🔧 Maintenance

### Regular Tasks
- Monitor logs daily
- Review data quality weekly
- Update dependencies monthly
- Security patches as needed

### Health Checks
```bash
# Database health
docker-compose exec postgres pg_isready

# Application health
curl http://localhost:8000/health

# Redis health
docker-compose exec redis redis-cli ping
```

## 📝 Troubleshooting

### Common Issues

**Spider Failures:**
- Check robots.txt compliance
- Verify website structure hasn't changed
- Monitor rate limiting

**Database Issues:**
- Check connection limits
- Monitor query performance
- Verify storage space

**Memory Issues:**
- Increase container memory
- Optimize data processing
- Implement data archiving

### Log Analysis
```bash
# View recent logs
docker-compose logs --tail=100 scrapy-app

# Search for errors
docker-compose logs | grep ERROR

# Monitor in real-time
docker-compose logs -f
```

## 📞 Support

For production issues:
1. Check monitoring dashboards
2. Review application logs
3. Verify infrastructure health
4. Check data quality metrics
5. Contact support if needed

---

**Remember**: Always test in staging before deploying to production!