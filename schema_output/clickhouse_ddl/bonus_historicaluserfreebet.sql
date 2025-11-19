CREATE TABLE IF NOT EXISTS analytics.`bonus_historicaluserfreebet`
(
    `id` String,
    `expires_on` DateTime64(6, 'UTC'),
    `bets` Int32,
    `quantity` Int32,
    `unit_value` Float64,
    `last_used_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `first_used_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `created_tickets` String,
    `status` UInt16,
    `award_type` UInt16,
    `cancelled_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `history_id` Int32,
    `history_date` DateTime64(6, 'UTC'),
    `history_change_reason` String DEFAULT '',
    `history_type` LowCardinality(String),
    `cancelled_by_id` Int32 DEFAULT 0,
    `free_bet_setting_id` Int32 DEFAULT 0,
    `history_user_id` Int32 DEFAULT 0,
    `member_id` Int32 DEFAULT 0,
    `promotion_description_id` Int32 DEFAULT 0,
    `wagering_policy_id` Int32 DEFAULT 0,
    `wallet_id` Int32 DEFAULT 0,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`history_id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
