CREATE TABLE IF NOT EXISTS analytics.`arifpay_withdrawpaymentrequest`
(
    `id` Int64,
    `amount` Decimal64(2),
    `expiry_date` DateTime64(6, 'UTC'),
    `original_amount` Decimal64(2),
    `useridentifier` String,
    `transaction_reference` String,
    `comment` String DEFAULT '',
    `nonce` String,
    `arifpay_b2c` Bool,
    `arifpay_error` Bool,
    `cancel_url` String DEFAULT '',
    `payment_url` String DEFAULT '',
    `arifpay_id` Int32 DEFAULT 0,
    `arifpay_transaction_id` Int32 DEFAULT 0,
    `session_id` Int32 DEFAULT 0,
    `phone_number` Int32 DEFAULT 0,
    `arifpay_uuid` String DEFAULT '',
    `arifpay_message` String DEFAULT '',
    `arifpay_payment_type` LowCardinality(String) DEFAULT '',
    `arifpay_transaction_status` LowCardinality(String) DEFAULT '',
    `arifpay_transaction_reference` String DEFAULT '',
    `status` Int32,
    `committed_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `bank_transaction_id` Int32,
    `payment_method_id` Int64,
    `user_id` Int32,
    `arifpay_configuration_id` Int32 DEFAULT 0,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
