CREATE TABLE IF NOT EXISTS analytics.`kacha_historicalkachaconfiguration`
(
    `id` Int32,
    `configuration_ptr_id` Int32 DEFAULT 0,
    `config_name` String,
    `updated_at` DateTime64(6, 'UTC'),
    `created_at` DateTime64(6, 'UTC'),
    `base_url` String,
    `username` String,
    `password` String,
    `shortcode` String,
    `history_id` Int32,
    `history_date` DateTime64(6, 'UTC'),
    `history_change_reason` String DEFAULT '',
    `history_type` LowCardinality(String),
    `history_user_id` Int32 DEFAULT 0,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`history_id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
