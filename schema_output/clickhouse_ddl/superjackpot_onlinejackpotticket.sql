CREATE TABLE IF NOT EXISTS analytics.`superjackpot_onlinejackpotticket`
(
    `id` Int32,
    `ticketID` String,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `jackpot_id` Int32,
    `stake` Float64,
    `status` UInt16,
    `user_id` Int32,
    `nonwithdrawable` Float64,
    `payable` Float64,
    `result_updated_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `lost_count` Int32,
    `prize_id` Int32 DEFAULT 0,
    `status_updated_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `won_amount` Nullable(Decimal64(2)),
    `is_paid` Bool,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
