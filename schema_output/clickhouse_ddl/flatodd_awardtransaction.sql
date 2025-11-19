CREATE TABLE IF NOT EXISTS analytics.`flatodd_awardtransaction`
(
    `id` Int32,
    `amount` Decimal64(2),
    `transaction_date` DateTime64(6, 'UTC'),
    `jackpot_id` Int32 DEFAULT 0,
    `ticket_id` Int32 DEFAULT 0,
    `wallet_id` Int32,
    `note` String DEFAULT '',
    `dropped` Bool,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
