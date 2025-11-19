CREATE TABLE IF NOT EXISTS analytics.`flatodd_ticketconfirmactivity`
(
    `id` Int32,
    `confirmed_at` DateTime64(6, 'UTC'),
    `ticket_id` Int32,
    `confirmed_by_id` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`confirmed_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
