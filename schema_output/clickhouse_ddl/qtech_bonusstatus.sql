CREATE TABLE IF NOT EXISTS analytics.`qtech_bonusstatus`
(
    `id` Int64,
    `bonus_id` Int32,
    `game_ids` Int32,
    `total_bet_value` Float64,
    `total_payout` Float64 DEFAULT 0.0,
    `round_options` String,
    `currency` String,
    `promo_code` String,
    `status` UInt16,
    `validity_days` Int32,
    `promoted_date_time` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `claimed_date_time` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `failed_date_time` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `completed_date_time` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `cancelled_date_time` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `deleted_date_time` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `expired_date_time` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `claimed_round_option` Int32 DEFAULT 0,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `claimed_game_id` Int64 DEFAULT 0,
    `player_id` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
