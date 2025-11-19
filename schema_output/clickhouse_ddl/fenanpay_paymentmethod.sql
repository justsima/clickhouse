CREATE TABLE IF NOT EXISTS analytics.`fenanpay_paymentmethod`
(
    `id` Int64,
    `name` String,
    `code` String,
    `url` String DEFAULT '',
    `transaction_fee` Float64,
    `supports_direct` Bool,
    `status` Int32,
    `order` Int32,
    `transaction_type` LowCardinality(String),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
