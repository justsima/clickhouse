CREATE TABLE IF NOT EXISTS analytics.`bonus_userfreebet`
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
    `cancelled_by_id` Int32 DEFAULT 0,
    `free_bet_setting_id` Int32,
    `member_id` Int32,
    `promotion_description_id` Int32,
    `wagering_policy_id` Int32,
    `wallet_id` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
