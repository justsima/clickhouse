CREATE TABLE IF NOT EXISTS analytics.`flatreferal_referralinvoice`
(
    `id` Int32,
    `amount` Decimal64(2),
    `paid_amount` Decimal64(2),
    `status` LowCardinality(String),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `member_id` Int32,
    `due_date` Date DEFAULT toDate(0),
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
