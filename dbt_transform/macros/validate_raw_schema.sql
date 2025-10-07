-- Macro to validate that raw tables have expected structure
{% macro validate_raw_schema() %}
    {% set tables_to_check = [
        ('raw_scraped_data', ['id', 'spider_name', 'source_url', 'raw_data', 'crawl_run_id', 'data_hash', 'item_type', 'created_at']),
        ('crawl_runs', ['id', 'spider_name', 'source_domain', 'configuration', 'status', 'total_items', 'failed_items', 'started_at', 'finished_at', 'updated_at'])
    ] %}

    {% for table_name, expected_columns in tables_to_check %}
        {% set actual_columns = adapter.get_columns_in_relation(ref(table_name)) %}
        {% set actual_column_names = actual_columns | map(attribute='name') | list %}

        {% for expected_col in expected_columns %}
            {% if expected_col not in actual_column_names %}
                {{ log("WARNING: Column '" ~ expected_col ~ "' missing from table '" ~ table_name ~ "'", info=True) }}
            {% endif %}
        {% endfor %}
    {% endfor %}
{% endmacro %}