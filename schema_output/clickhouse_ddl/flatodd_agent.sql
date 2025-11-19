CREATE TABLE IF NOT EXISTS analytics.`flatodd_agent`
(
    `id` Int32,
    `user_id` Int32,
    `branch_limit` Int32,
    `brief` String DEFAULT '',
    `credit_limit` Decimal64(2),
    `disabled` Bool,
    `address` String,
    `agent_type` LowCardinality(String),
    `phonenumber` Int32,
    `min_stake` Int32 DEFAULT 0,
    `data_access_period` Int32 DEFAULT 0,
    `deposit_plan` Int32,
    `branch_offlinebet_duplicate_number_limit` Int32 DEFAULT 0,
    `branch_offlinebet_duplicate_stake_limit` Nullable(Decimal(10,2)),
    `created_at` DateTime64(6, 'UTC'),
    `created_by_id` Int32 DEFAULT 0,
    `updated_at` DateTime64(6, 'UTC'),
    `retail_bet_plan` Int32,
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
