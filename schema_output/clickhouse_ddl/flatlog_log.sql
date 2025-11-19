CREATE TABLE IF NOT EXISTS analytics.`flatlog_log`
(
    `id` Int64,
    `log_type` UInt16,
    `extra_info` String,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `user_id` Int32 DEFAULT 0,
    `user_agent_id` Int64,
    `last_action_at` DateTime64(6, 'UTC'),
    `remote_addr` String,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
