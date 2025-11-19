CREATE TABLE IF NOT EXISTS analytics.`betradar_producer`
(
    `id` Int64,
    `producer_type` UInt16,
    `state` UInt16,
    `last_alive_message_timestamp` DateTime64(6, 'UTC'),
    `last_synched_on` DateTime64(6, 'UTC'),
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `down_tolerance` Int32,
    `last_synched_on_tolerance` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
