CREATE TABLE IF NOT EXISTS analytics.`yo_uganda_withdrawpaymentrequest`
(
    `id` Int64,
    `yo_transaction_reference` String DEFAULT '',
    `transaction_status` LowCardinality(String) DEFAULT '',
    `youganda_status` LowCardinality(String) DEFAULT '',
    `useridentifier` String DEFAULT '',
    `narrative` String DEFAULT '',
    `comment` String DEFAULT '',
    `transaction_reference` String,
    `status_code` Int32 DEFAULT 0,
    `status_message` String DEFAULT '',
    `amount` Decimal64(2),
    `committed_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `mno_transaction_reference` String DEFAULT '',
    `provider_reference_text` String DEFAULT '',
    `status` UInt16,
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
