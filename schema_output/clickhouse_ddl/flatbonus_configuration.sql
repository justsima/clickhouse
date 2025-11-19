CREATE TABLE IF NOT EXISTS analytics.`flatbonus_configuration`
(
    `configuration_ptr_id` Int32,
    `new_member_first_deposit_bonus_enable` Bool,
    `new_member_first_deposit_bonus_criteria` Int32,
    `new_member_first_deposit_bonus_min_amount_criteria` Nullable(Decimal64(2)),
    `new_member_first_deposit_bonus_max_amount_criteria` Nullable(Decimal64(2)),
    `new_member_first_deposit_bonus_amount` Decimal64(2),
    `new_member_first_deposit_bonus_award_rule` Int32,
    `new_member_first_deposit_bonus_expires_on` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`configuration_ptr_id`)
PARTITION BY toYYYYMM(`new_member_first_deposit_bonus_expires_on`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
