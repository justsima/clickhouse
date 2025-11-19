CREATE TABLE IF NOT EXISTS analytics.`flatodd_promotiondescription`
(
    `id` Int32,
    `bonus_type` Int32,
    `created_at` DateTime64(6, 'UTC'),
    `description` String,
    `title` String,
    `updated_at` DateTime64(6, 'UTC'),
    `thumbnail` String DEFAULT '',
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
