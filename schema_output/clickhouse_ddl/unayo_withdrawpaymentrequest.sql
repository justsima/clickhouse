CREATE TABLE IF NOT EXISTS analytics.`unayo_withdrawpaymentrequest`
(
    `id` Int64,
    `transaction_reference` String,
    `source_account_number` Int32 DEFAULT 0,
    `source_reference` String DEFAULT '',
    `destination_account_number` Int32,
    `user_identifier` Int32,
    `destination_reference` String DEFAULT '',
    `transaction_unique_id` Int32 DEFAULT 0,
    `cash_out_fee_type` LowCardinality(String) DEFAULT '',
    `cash_out_fee` Float64 DEFAULT 0.0,
    `request_id` Int32 DEFAULT 0,
    `qr_code` String DEFAULT '',
    `voucher_code` String DEFAULT '',
    `destination_type` LowCardinality(String) DEFAULT '',
    `current_balance` Nullable(Decimal64(2)),
    `available_balance` Nullable(Decimal64(2)),
    `hold_expiry_date` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `status_code` Int32 DEFAULT 0,
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
