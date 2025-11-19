CREATE TABLE IF NOT EXISTS analytics.`harifsport_retailcoupon`
(
    `id` Int64,
    `bet_date` DateTime64(6, 'UTC'),
    `bet_id` Int32,
    `bet_type` LowCardinality(String),
    `bet_code` String,
    `coupon_id` Int32,
    `mobile_phone` String,
    `ticket_link` String DEFAULT '',
    `number_of_matches` Int32,
    `possible_win` Float64,
    `total_odds` Float64,
    `bet_amount` Decimal64(2),
    `net_amount` Decimal64(2),
    `winnings` Float64,
    `win_tax` Float64,
    `bet_tax` Float64,
    `bonus` Float64,
    `paid_amount` Decimal64(2),
    `is_paid` Bool,
    `paid_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `status` LowCardinality(String),
    `paid_at_branch_id` Int32 DEFAULT 0,
    `paid_by_id` Int32 DEFAULT 0,
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
