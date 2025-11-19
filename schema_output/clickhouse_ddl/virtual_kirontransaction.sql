CREATE TABLE IF NOT EXISTS analytics.`virtual_kirontransaction`
(
    `id` Int64,
    `amount` Decimal64(2),
    `external_transaction_id` Int32,
    `round_id` Int32,
    `transaction_id` Int32,
    `transaction_type` UInt16,
    `comment` String,
    `commited_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `bank_transaction_id` Int32,
    `prev_transaction_id` Int64 DEFAULT 0,
    `user_id` Int32,
    `currency_code` String,
    `state` UInt16,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
