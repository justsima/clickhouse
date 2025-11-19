CREATE TABLE IF NOT EXISTS analytics.`cms_ug_playerregistration`
(
    `id` Int64,
    `player_id` Int32,
    `birth_date` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `id_number` Int32 DEFAULT 0,
    `given_names` String DEFAULT '',
    `family_names` String DEFAULT '',
    `sub_division` String DEFAULT '',
    `issue_date` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `verified_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `expiration_date` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `phone_number` Int32,
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
