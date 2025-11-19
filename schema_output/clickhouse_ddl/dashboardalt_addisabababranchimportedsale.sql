CREATE TABLE IF NOT EXISTS analytics.`dashboardalt_addisabababranchimportedsale`
(
    `id` Int64,
    `file_name` String,
    `bet_date` Date,
    `before_tax` Float64,
    `fs_number` Int32,
    `tax` Float64,
    `total` Float64,
    `processed` Bool,
    `message` String DEFAULT '',
    `created_at` DateTime64(6, 'UTC'),
    `updated_at` DateTime64(6, 'UTC'),
    `branch_id` Int32,
    `offline_ticket_id` Int32 DEFAULT 0,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
