CREATE TABLE IF NOT EXISTS analytics.`super_jackpot_offlinesuperjackpotticket`
(
    `id` Int64,
    `stake` Float64,
    `won_amount` Nullable(Decimal64(2)),
    `lost_count` Int32,
    `is_paid` Bool,
    `result_updated_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `status_updated_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `status` Int32,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `ticket_hash` String DEFAULT '',
    `ticket_id` Int32,
    `coupon_id` Int32,
    `stage` UInt16,
    `confirmed_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `printed_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `paid_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `confirmed_by_id` Int32 DEFAULT 0,
    `paid_by_id` Int32 DEFAULT 0,
    `prize_id` Int64 DEFAULT 0,
    `super_jackpot_id` Int64,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
