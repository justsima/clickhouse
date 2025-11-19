CREATE TABLE IF NOT EXISTS analytics.`flatodd_onlinejackpotpick`
(
    `id` Int32,
    `jackpot_choice` String,
    `jackpot_event_id` Int32,
    `online_jackpot_id` Int32,
    `won_status` LowCardinality(String),
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
