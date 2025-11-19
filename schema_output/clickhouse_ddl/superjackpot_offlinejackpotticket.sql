CREATE TABLE IF NOT EXISTS analytics.`superjackpot_offlinejackpotticket`
(
    `id` Int32,
    `stake` Float64,
    `ticketID` String DEFAULT '',
    `status` UInt16,
    `lost_count` Int32,
    `is_paid` Bool,
    `won_amount` Nullable(Decimal64(2)),
    `result_updated_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `status_updated_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `jackpot_id` Int32,
    `prize_id` Int32 DEFAULT 0,
    `confirmed_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `confirmed_by_id` Int32 DEFAULT 0,
    `couponID` String,
    `paid_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `paid_by_id` Int32 DEFAULT 0,
    `printed_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `stage` UInt16,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
