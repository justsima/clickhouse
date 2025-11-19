CREATE TABLE IF NOT EXISTS analytics.`kra_krapaymentreference`
(
    `id` Int64,
    `amount` Decimal64(2),
    `tax_start_date` DateTime64(6, 'UTC'),
    `tax_end_date` DateTime64(6, 'UTC'),
    `reference` String,
    `status` LowCardinality(String),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `payment_id` Int64 DEFAULT 0,
    `tax_remittance_job_id` Int64,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
