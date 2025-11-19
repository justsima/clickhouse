CREATE TABLE IF NOT EXISTS analytics.`flatodd_branch`
(
    `id` Int32,
    `city` LowCardinality(String),
    `address` String,
    `agent_id` Int32,
    `disabled` Bool,
    `branchID` String,
    `branchSecret` String,
    `credit_limit` Decimal64(2),
    `min_stake` Int32 DEFAULT 0,
    `offlinebet_sales_limit` Nullable(Decimal(10,2)),
    `branch_deposit_limit` Nullable(Decimal(10,2)),
    `offlinebet_duplicate_number_limit` Int32 DEFAULT 0,
    `offlinebet_duplicate_stake_limit` Nullable(Decimal(10,2)),
    `created_at` DateTime64(6, 'UTC'),
    `created_by_id` Int32 DEFAULT 0,
    `updated_at` DateTime64(6, 'UTC'),
    `channel` Int32,
    `basic_cashback_valid_duration` Int32 DEFAULT 0,
    `cashback_rule` UInt16 DEFAULT 0,
    `operating_end_time` String DEFAULT '',
    `operating_start_time` String DEFAULT '',
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
