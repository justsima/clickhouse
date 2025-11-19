CREATE TABLE IF NOT EXISTS analytics.`unipesa_depositpaymentrequest`
(
    `id` Int64,
    `useridentifier` String,
    `order_id` Int32 DEFAULT 0,
    `customer_id` Int32 DEFAULT 0,
    `merchant_id` Int32 DEFAULT 0,
    `transaction_id` Int32 DEFAULT 0,
    `transaction_ref` String DEFAULT '',
    `result_code` UInt16 DEFAULT 0,
    `result_message` String DEFAULT '',
    `unipesa_status` UInt16 DEFAULT 0,
    `service_date_time` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `service_id` UInt16 DEFAULT 0,
    `provider_id` UInt16 DEFAULT 0,
    `confirm_type` UInt16 DEFAULT 0,
    `destination_id` Int32 DEFAULT 0,
    `provider_result_code` String DEFAULT '',
    `provider_result_message` String DEFAULT '',
    `amount` Decimal64(2),
    `transaction_reference` String,
    `comment` String DEFAULT '',
    `status` Int32,
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
