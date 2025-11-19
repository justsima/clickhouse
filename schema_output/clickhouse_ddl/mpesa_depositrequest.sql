CREATE TABLE IF NOT EXISTS analytics.`mpesa_depositrequest`
(
    `id` Int64,
    `status` UInt16,
    `amount` Decimal64(2),
    `useridentifier` String,
    `transaction_reference` String,
    `conversation_id` Int32,
    `mpesa_transaction_reference` String DEFAULT '',
    `mpesa_conversation_id` Int32 DEFAULT 0,
    `mpesa_status_code` LowCardinality(String),
    `comment` String,
    `commited_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `bank_transaction_id` Int32,
    `user_id` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
