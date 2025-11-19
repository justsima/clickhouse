CREATE TABLE IF NOT EXISTS analytics.`flatodd_agenttwofactorauth`
(
    `id` Int32,
    `otp_secret` String,
    `otp_created_at` DateTime64(6, 'UTC'),
    `failed_attempts` Int32,
    `lockout_until` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `resend_count` Int32,
    `user_id` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`otp_created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
