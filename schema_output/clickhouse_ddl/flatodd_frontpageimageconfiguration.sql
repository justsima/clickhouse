CREATE TABLE IF NOT EXISTS analytics.`flatodd_frontpageimageconfiguration`
(
    `id` Int32,
    `photo` String DEFAULT '',
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `configuration_id` Int32,
    `order` Int32,
    `image_location` UInt16,
    `image_link` String,
    `end_time` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `start_time` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `image_channel` UInt16,
    `locale_id` Int32 DEFAULT 0,
    `provider` UInt16,
    `dialog_name` String,
    `recurrence` UInt16,
    `show_to` UInt16,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
