CREATE TABLE IF NOT EXISTS analytics.`hulusport_hulusportuserlegacy`
(
    `id` Int32,
    `member_id` Int32,
    `username` String,
    `email` String,
    `first_name` String,
    `last_name` String,
    `company` String,
    `region` LowCardinality(String),
    `city` LowCardinality(String),
    `sub_city` LowCardinality(String),
    `woreda` LowCardinality(String),
    `specific_address` String,
    `balance` Decimal64(2),
    `amount_payable` Decimal64(2),
    `updated_at` DateTime64(6, 'UTC'),
    `created_at` DateTime64(6, 'UTC'),
    `phone` String,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
