CREATE TABLE IF NOT EXISTS analytics.`bonus_historicaluserbonus`
(
    `id` String,
    `expires_on` DateTime64(6, 'UTC'),
    `awarded_amount` Decimal64(2),
    `rollover_amount` Decimal64(2),
    `contributed_amount` Decimal64(2),
    `status` UInt16,
    `cancelled_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `history_id` Int32,
    `history_date` DateTime64(6, 'UTC'),
    `history_change_reason` String DEFAULT '',
    `history_type` LowCardinality(String),
    `cancelled_by_id` Int32 DEFAULT 0,
    `deposit_bonus_setting_id` Int32 DEFAULT 0,
    `history_user_id` Int32 DEFAULT 0,
    `member_id` Int32 DEFAULT 0,
    `wagering_policy_id` Int32 DEFAULT 0,
    `wallet_id` Int32 DEFAULT 0,
    `contributed_amount_percentage` Decimal64(2),
    `promotion_description_id` Int32 DEFAULT 0,
    `contributed_tickets` String,
    `bonus_type` UInt16,
    `contribution_fulfilled_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`history_id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
