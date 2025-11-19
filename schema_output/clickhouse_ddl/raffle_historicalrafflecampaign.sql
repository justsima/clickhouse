CREATE TABLE IF NOT EXISTS analytics.`raffle_historicalrafflecampaign`
(
    `id` Int64,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `name` String DEFAULT '',
    `description` String DEFAULT '',
    `start_date` DateTime64(6, 'UTC'),
    `end_date` DateTime64(6, 'UTC'),
    `recurrence` String,
    `status` LowCardinality(String),
    `wallet_type` LowCardinality(String),
    `number_of_winners` Int32,
    `announcement_delay_minutes` UInt32,
    `image` String DEFAULT '',
    `history_id` Int32,
    `history_date` DateTime64(6, 'UTC'),
    `history_change_reason` String DEFAULT '',
    `history_type` LowCardinality(String),
    `history_user_id` Int32 DEFAULT 0,
    `promotion_description_id` Int32 DEFAULT 0,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`history_id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
