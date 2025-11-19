CREATE TABLE IF NOT EXISTS analytics.`tournament_campaign`
(
    `id` String,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `order` UInt16,
    `status` Int32,
    `tournament_type` Int32,
    `start_date` DateTime64(6, 'UTC'),
    `end_date` DateTime64(6, 'UTC'),
    `period_type` Int32,
    `name` String,
    `short_description` String,
    `long_description` String,
    `prize_pool` Decimal(20,2) DEFAULT 0,
    `stake_weight_on_win` Decimal(5,2),
    `stake_weight_on_loss` Decimal(5,2),
    `profit_weight` Decimal(10,2),
    `page_visit_point` Decimal(10,2),
    `winners_count` UInt32,
    `cancelled_by_id` Int32 DEFAULT 0,
    `created_by_id` Int32,
    `streak_weight` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
