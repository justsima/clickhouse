CREATE TABLE IF NOT EXISTS analytics.`santimpay_depositpaymentrequest`
(
    `id` Int64,
    `tx_ref` String,
    `amount` Decimal64(2),
    `original_amount` Decimal64(2),
    `state` UInt16,
    `charge` Float64,
    `comment` String,
    `commited_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `bank_transaction_id` Int32,
    `user_id` Int32,
    `method` String,
    `santim_refid` String,
    `santim_txnId` String,
    `useridentifier` String,
    `bank_id` Int64 DEFAULT 0,
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
