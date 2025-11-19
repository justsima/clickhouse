CREATE TABLE IF NOT EXISTS analytics.`arifpay_depositpaymentmethod`
(
    `id` Int64,
    `name` String,
    `code` String,
    `supports_direct` Bool,
    `status` Int32,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `transaction_fee` Float64,
    `url` String DEFAULT '',
    `order` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
