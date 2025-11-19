CREATE TABLE IF NOT EXISTS analytics.`sales_dailyduplicateslip`
(
    `id` Int32,
    `slip_hash` String,
    `counter` Int32,
    `total_stake` Decimal(10,2),
    `total_payout` Decimal(10,2),
    `last_bet_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `confirmed_date` Date,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `agent_id` Int32,
    `branch_id` Int32,
    `last_bet_id` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
