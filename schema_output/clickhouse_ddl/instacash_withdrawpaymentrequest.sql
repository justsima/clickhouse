CREATE TABLE IF NOT EXISTS analytics.`instacash_withdrawpaymentrequest`
(
    `id` Int64,
    `transaction_reference` String,
    `instacash_transaction_reference` String,
    `instacash_unique_hash` String,
    `user_identifier` Int32,
    `biller_number` Int32,
    `timestamp` Int32 DEFAULT 0,
    `comment` String,
    `amount` Decimal64(2),
    `committed_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `recipient_msisdn` String,
    `description` String,
    `status` UInt16,
    `bank_transaction_id` Int32,
    `user_id` Int32,
    `biller_account_balance` Int32,
    `conversation_id` Int32,
    `transaction_fee` Float64,
    `transaction_date` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `status_code` Int32 DEFAULT 0,
    `message` String,
    `response_code` String,
    `response_payload` String DEFAULT '',
    `webhook_payload` String DEFAULT '',
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
