CREATE TABLE IF NOT EXISTS analytics.`hulusport_ticketpurchase`
(
    `id` Int32,
    `bettingTxnRef` String,
    `remote_txn_ref` String DEFAULT '',
    `status` Int32,
    `quantity` UInt32,
    `amount` Decimal(10,2),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `member_id` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
