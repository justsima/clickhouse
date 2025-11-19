CREATE TABLE IF NOT EXISTS analytics.`fenanpay_depositpaymentrequest`
(
    `id` Int64,
    `amount` Decimal64(2),
    `original_amount` Decimal64(2),
    `currency` String,
    `useridentifier` String,
    `phone_number` Int32 DEFAULT 0,
    `transaction_reference` String,
    `comment` String DEFAULT '',
    `description` String DEFAULT '',
    `expiry_date` DateTime64(6, 'UTC'),
    `payment_intent_unique_id` Int32 DEFAULT 0,
    `payment_link_unique_id` Int32 DEFAULT 0,
    `payment_method_code` String DEFAULT '',
    `return_url` String DEFAULT '',
    `callback_url` String DEFAULT '',
    `payment_url` String DEFAULT '',
    `transaction_id` Int32 DEFAULT 0,
    `session_id` Int32 DEFAULT 0,
    `fenan_transaction_status` LowCardinality(String) DEFAULT '',
    `fenan_error` Bool,
    `fenan_message` String DEFAULT '',
    `commission_paid_by_customer` Bool,
    `status` Int32,
    `committed_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `bank_transaction_id` Int32,
    `fenanpay_configuration_id` Int32 DEFAULT 0,
    `payment_method_id` Int64 DEFAULT 0,
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
