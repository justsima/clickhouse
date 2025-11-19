CREATE TABLE IF NOT EXISTS analytics.`lenco_bank`
(
    `id` Int64,
    `name` String,
    `code` String,
    `country` Int32,
    `status` UInt32,
    `transaction_support` UInt32,
    `is_mobile_money` Bool,
    `withdraw_transaction_fee` Float64,
    `deposit_transaction_fee` Float64,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
