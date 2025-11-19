CREATE TABLE IF NOT EXISTS analytics.`superjackpot_jackpotprize`
(
    `id` Int32,
    `amount` Decimal(10,2),
    `rule` Int32,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `jackpot_id` Int32,
    `awarded_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `is_awarded` Bool,
    `payable_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `winner_count` Int32 DEFAULT 0,
    `winners_identified` Bool,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
