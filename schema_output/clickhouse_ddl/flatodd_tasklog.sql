CREATE TABLE IF NOT EXISTS analytics.`flatodd_tasklog`
(
    `id` Int32,
    `task_name` String,
    `start_time` DateTime64(6, 'UTC'),
    `end_time` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `elapsed_second` Int32,
    `is_running` Bool,
    `error_msg` String,
    `finished_with_error` Bool,
    `rate_10min` Float64,
    `rate_1min` Float64,
    `rate_5min` Float64,
    `state` String,
    `percentage` Float64,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `last_timestamp` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
