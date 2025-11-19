CREATE TABLE IF NOT EXISTS analytics.`kironlite_game`
(
    `id` Int64,
    `transaction_count` Int32,
    `service_key` String,
    `game_code` String,
    `game_id` Int32,
    `name` String,
    `description` String DEFAULT '',
    `thumbnail_url` String DEFAULT '',
    `color_scheme` String DEFAULT '',
    `logo_url` String DEFAULT '',
    `url` String DEFAULT '',
    `minimum_stake` Decimal(12,2) DEFAULT 0,
    `maximum_stake` Decimal(12,2) DEFAULT 0,
    `maximum_win` Decimal(12,2) DEFAULT 0,
    `currency` String DEFAULT '',
    `demo_url` String DEFAULT '',
    `launch_url` String DEFAULT '',
    `maintenance_status` Int32,
    `status` Int32,
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
