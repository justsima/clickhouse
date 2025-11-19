CREATE TABLE IF NOT EXISTS analytics.`emola_withdrawpaymentrequest`
(
    `id` Int64,
    `gw_transaction_id` Int32 DEFAULT 0,
    `transaction_id` Int32 DEFAULT 0,
    `description` String DEFAULT '',
    `sms_content` String DEFAULT '',
    `error_code` String DEFAULT '',
    `request_id` Int32 DEFAULT 0,
    `message` String DEFAULT '',
    `error` String DEFAULT '',
    `useridentifier` String DEFAULT '',
    `comment` String DEFAULT '',
    `transaction_reference` String,
    `amount` Decimal64(2),
    `committed_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
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
