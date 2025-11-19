CREATE TABLE IF NOT EXISTS analytics.`flatodd_otp`
(
    `id` Int32,
    `code` String,
    `unique_id` Int32,
    `confirmation_id` Int32,
    `otp_type` UInt16,
    `otp_sent_to` String,
    `expires_in` Int64 DEFAULT 0,
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `state` UInt16,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
