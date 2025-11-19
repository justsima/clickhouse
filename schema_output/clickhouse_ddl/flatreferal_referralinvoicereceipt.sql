CREATE TABLE IF NOT EXISTS analytics.`flatreferal_referralinvoicereceipt`
(
    `id` Int32,
    `amount` Decimal64(2),
    `note` String DEFAULT '',
    `status` LowCardinality(String),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `approved_by_id` Int32,
    `cancelled_by_id` Int32 DEFAULT 0,
    `invoice_id` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
