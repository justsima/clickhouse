CREATE TABLE IF NOT EXISTS analytics.`flatodd_frontpageimageconfiguration`
(
    `image_location` String,
    `image_channel` String,
    `provider` String,
    `recurrence` String,
    `show_to` String,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version)
ORDER BY tuple()
SETTINGS index_granularity = 8192;
