CREATE TABLE IF NOT EXISTS analytics.`mpesa_et_depositpaymentrequest`
(
    `id` Int64,
    `transaction_reference` String,
    `receipt_number` Int32,
    `result_code` String DEFAULT '',
    `response_description` String,
    `merchant_request_id` Int32,
    `checkout_request_id` Int32,
    `business_short_code` String,
    `result_description` String,
    `account_reference` Int32,
    `transaction_type` LowCardinality(String),
    `transaction_time` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `transaction_date` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `response_code` String,
    `phone_number` Int32,
    `msisdn` String,
    `user_identifier` Int32,
    `comment` String,
    `amount` Decimal64(2),
    `status` UInt16,
    `committed_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
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
