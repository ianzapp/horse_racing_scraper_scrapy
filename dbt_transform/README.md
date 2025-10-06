# Horse Racing dbt Transform

This dbt project transforms raw JSON horse racing data into a normalized dimensional model suitable for analytics.

## Quick Start

1. **Install dbt**:
```bash
pip install -r requirements_dbt.txt
```

2. **Install dbt packages**:
```bash
cd dbt_transform
dbt deps
```

3. **Test connection**:
```bash
dbt debug --profiles-dir .
```

4. **Run initial build**:
```bash
# Build all models
dbt run --profiles-dir .

# Run tests
dbt test --profiles-dir .
```

## Project Structure

```
dbt_transform/
├── models/
│   ├── staging/           # Clean and type raw JSON data
│   │   ├── stg_race_entries.sql
│   │   ├── stg_race_cards.sql
│   │   ├── stg_race_results.sql
│   │   └── stg_track_info.sql
│   └── marts/             # Dimensional model
│       ├── dim_tracks.sql     # Track dimension
│       ├── dim_horses.sql     # Horse dimension
│       ├── dim_trainers.sql   # Trainer dimension
│       ├── dim_jockeys.sql    # Jockey dimension
│       ├── fct_races.sql      # Race fact table
│       ├── fct_race_entries.sql   # Race entries fact
│       └── fct_race_results.sql   # Race results fact
├── tests/                 # Custom data quality tests
├── macros/               # Custom macros
└── analyses/             # Ad-hoc analysis queries
```

## Data Flow

1. **Raw Data**: JSON stored in `raw_scraped_data` table
2. **Staging**: Clean, type, and validate data
3. **Dimensions**: Create normalized reference tables
4. **Facts**: Create analytical fact tables with foreign keys

## Key Features

### Incremental Processing
- Staging models process only new records since last run
- Efficient for large datasets
- Use `--full-refresh` to rebuild from scratch

### Data Quality
- Comprehensive tests on all models
- Range validation for numeric fields
- Referential integrity checks
- Custom business logic tests

### Flexible Schema
- Handles missing data gracefully
- Extensible for new data types
- Supports both entries and results

## Common Commands

```bash
# Full refresh (rebuild everything)
dbt run --full-refresh --profiles-dir .

# Run specific model
dbt run --select stg_race_entries --profiles-dir .

# Run downstream models
dbt run --select stg_race_entries+ --profiles-dir .

# Run tests only
dbt test --profiles-dir .

# Generate documentation
dbt docs generate --profiles-dir .
dbt docs serve --profiles-dir .

# Compile without running
dbt compile --profiles-dir .
```

## Configuration

### Profiles
The `profiles.yml` contains database connection settings:
- `dev`: Development environment (public schema)
- `prod`: Production environment (dbt_prod schema)

### Materializations
- **Staging models**: Views (for development speed)
- **Mart models**: Tables (for query performance)
- **Incremental**: For large staging tables

## Data Quality Monitoring

### Built-in Tests
- Primary key uniqueness
- Foreign key relationships
- Not null constraints
- Accepted value ranges
- Business rule validation

### Custom Tests
- Race entries should have results (after race completion)
- Data freshness checks
- Cross-table consistency

## Analytics Use Cases

The dimensional model supports:

1. **Performance Analysis**: Horse/jockey/trainer win rates
2. **Track Analysis**: Track bias, surface preferences
3. **Odds Analysis**: Payout patterns, value betting
4. **Speed Analysis**: Speed figure trends
5. **Market Analysis**: Field size, purse trends

## Example Queries

```sql
-- Top performing trainers by win percentage
SELECT
    t.trainer_name,
    COUNT(*) as total_entries,
    SUM(CASE WHEN rr.finish_position = 1 THEN 1 ELSE 0 END) as wins,
    AVG(CASE WHEN rr.finish_position = 1 THEN 1.0 ELSE 0.0 END) as win_rate
FROM fct_race_entries re
JOIN dim_trainers t ON re.trainer_key = t.trainer_key
LEFT JOIN fct_race_results rr ON re.entry_key = rr.result_key
WHERE re.race_date >= '2024-01-01'
GROUP BY t.trainer_name
HAVING COUNT(*) >= 50
ORDER BY win_rate DESC;

-- Track surface analysis
SELECT
    r.surface_type,
    COUNT(*) as total_races,
    AVG(r.purse_amount) as avg_purse,
    AVG(re.post_position) as avg_field_size
FROM fct_races r
JOIN fct_race_entries re ON r.race_key = re.race_key
GROUP BY r.surface_type;
```

## Troubleshooting

### Common Issues

1. **Connection errors**: Check `profiles.yml` credentials
2. **Missing dependencies**: Run `dbt deps`
3. **Test failures**: Check data quality, may need range adjustments
4. **Incremental issues**: Use `--full-refresh` to rebuild

### Debugging

```bash
# Check compiled SQL
dbt compile --select model_name --profiles-dir .

# Run in debug mode
dbt --debug run --select model_name --profiles-dir .

# Show only errors
dbt test --store-failures --profiles-dir .
```