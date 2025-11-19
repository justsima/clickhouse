CREATE TABLE IF NOT EXISTS analytics.`bonus_historicalfreebetsetting`
(
    `id` String,
    `start_time` DateTime64(6, 'UTC'),
    `end_time` DateTime64(6, 'UTC'),
    `validity_period` Int64,
    `sms_notification` Bool,
    `quantity` Int32,
    `unit_value` Float64,
    `promo_code` String,
    `award_type` UInt16,
    `activation_type` UInt16,
    `sms_notification_template` String,
    `status` UInt16,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `history_id` Int32,
    `history_date` DateTime64(6, 'UTC'),
    `history_change_reason` String DEFAULT '',
    `history_type` LowCardinality(String),
    `history_user_id` Int32 DEFAULT 0,
    `promotion_description_id` Int32 DEFAULT 0,
    `wagering_policy_id` Int32 DEFAULT 0,
    `game_id` Int32 DEFAULT 0,
    `supported_platform` UInt16,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`history_id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
