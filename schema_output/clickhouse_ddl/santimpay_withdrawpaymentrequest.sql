CREATE TABLE IF NOT EXISTS analytics.`santimpay_withdrawpaymentrequest`
(
    `id` Int64,
    `amount` Decimal64(2),
    `charge` Float64,
    `comment` String,
    `commited_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `created_at` DateTime64(6, 'UTC'),
    `original_amount` Decimal64(2),
    `tx_ref` String,
    `updated_at` DateTime64(6, 'UTC'),
    `useridentifier` String,
    `bank_transaction_id` Int32,
    `santim_txnId` String,
    `user_id` Int32,
    `state` UInt16,
    `bank_id` Int64,
    `santim_refid` String,
    `account_number` Int32 DEFAULT 0,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
