CREATE TABLE IF NOT EXISTS analytics.`wheel_spinning_spinchances`
(
    `id` Int64,
    `awarded_chances` Int32,
    `remaining_chances` Int32,
    `used_chances` Int32,
    `award_reason` String,
    `valid_from` DateTime64(6, 'UTC'),
    `valid_until` DateTime64(6, 'UTC'),
    `status` LowCardinality(String),
    `last_time_used_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `cancelled_by_id` Int32 DEFAULT 0,
    `member_id` Int32,
    `spin_id` Int64 DEFAULT 0,
    `wheel_id` Int64,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
