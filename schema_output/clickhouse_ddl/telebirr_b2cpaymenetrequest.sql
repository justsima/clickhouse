CREATE TABLE IF NOT EXISTS analytics.`telebirr_b2cpaymenetrequest`
(
    `id` Int64,
    `amount` Decimal64(2),
    `useridentifier` String,
    `transaction_id` Int32,
    `state` UInt16,
    `stage` UInt16,
    `conversation_id` Int32 DEFAULT 0,
    `original_conversation_id` Int32 DEFAULT 0,
    `response_code` String DEFAULT '',
    `response_description` String DEFAULT '',
    `external_transaction_id` Int32 DEFAULT 0,
    `commited_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `bank_transaction_id` Int32,
    `user_id` Int32,
    `result_description` String DEFAULT '',
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
