CREATE TABLE IF NOT EXISTS analytics.`unayo_depositpaymentrequest`
(
    `id` Int64,
    `voucher_code` String DEFAULT '',
    `destination_trh_line_id` Int32 DEFAULT 0,
    `transaction_unique_id` Int32 DEFAULT 0,
    `origin_mim_control_id` Int32 DEFAULT 0,
    `source_trh_line_id` Int32 DEFAULT 0,
    `transaction_reference` String,
    `source_reference` String DEFAULT '',
    `node_request_id` Int32 DEFAULT 0,
    `status_desc` LowCardinality(String) DEFAULT '',
    `available_balance` Nullable(Decimal64(2)),
    `amount_redeemed` Nullable(Decimal64(2)),
    `current_balance` Nullable(Decimal64(2)),
    `comment` String,
    `status_code` Int32 DEFAULT 0,
    `amount` Decimal64(2),
    `status` UInt16,
    `user_identifier` Int32,
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
