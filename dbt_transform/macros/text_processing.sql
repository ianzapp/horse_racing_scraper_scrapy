{% macro clean_text_for_sentiment(text_column) %}
    -- Macro to clean text for sentiment analysis
    -- Removes HTML tags, normalizes whitespace, handles nulls
    CASE
        WHEN {{ text_column }} IS NULL OR TRIM({{ text_column }}) = '' THEN NULL
        ELSE REGEXP_REPLACE(
            REGEXP_REPLACE(
                REGEXP_REPLACE(
                    TRIM({{ text_column }}),
                    '<[^>]*>', '', 'g'  -- Remove HTML tags
                ),
                '\s+', ' ', 'g'  -- Normalize whitespace
            ),
            '[^\w\s\.\!\?\,\;\:\-\(\)]', '', 'g'  -- Keep only basic punctuation
        )
    END
{% endmacro %}

{% macro extract_text_metrics(text_column) %}
    -- Macro to extract text metrics for quality assessment
    CASE
        WHEN {{ text_column }} IS NULL OR TRIM({{ text_column }}) = '' THEN
            ROW(0, 0, 0.0)::RECORD(word_count INTEGER, char_count INTEGER, avg_word_length DECIMAL)
        ELSE
            ROW(
                ARRAY_LENGTH(STRING_TO_ARRAY(TRIM({{ text_column }}), ' '), 1) as word_count,
                LENGTH(TRIM({{ text_column }})) as char_count,
                CASE
                    WHEN ARRAY_LENGTH(STRING_TO_ARRAY(TRIM({{ text_column }}), ' '), 1) > 0
                    THEN LENGTH(TRIM({{ text_column }}))::DECIMAL / ARRAY_LENGTH(STRING_TO_ARRAY(TRIM({{ text_column }}), ' '), 1)
                    ELSE 0.0
                END as avg_word_length
            )::RECORD(word_count INTEGER, char_count INTEGER, avg_word_length DECIMAL)
    END
{% endmacro %}

{% macro is_quality_text(text_column, min_words=10, max_words=10000) %}
    -- Macro to determine if text is suitable for sentiment analysis
    CASE
        WHEN {{ text_column }} IS NULL OR TRIM({{ text_column }}) = '' THEN FALSE
        WHEN ARRAY_LENGTH(STRING_TO_ARRAY(TRIM({{ text_column }}), ' '), 1) < {{ min_words }} THEN FALSE
        WHEN ARRAY_LENGTH(STRING_TO_ARRAY(TRIM({{ text_column }}), ' '), 1) > {{ max_words }} THEN FALSE
        WHEN LENGTH(TRIM({{ text_column }})) < 50 THEN FALSE  -- Too short
        ELSE TRUE
    END
{% endmacro %}