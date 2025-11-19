CREATE TABLE IF NOT EXISTS analytics.`flatodd_smsdriver`
(
    `id` Int32,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `name` String,
    `handler_class` String,
    `supported_variable` Decimal(10,2),
    `bulk_chunk_size` Decimal(10,2),
    `is_active` Bool,
    `delay_per_chunk` Decimal(10,2),
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
