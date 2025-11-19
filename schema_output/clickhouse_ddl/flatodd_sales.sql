CREATE TABLE IF NOT EXISTS analytics.`flatodd_sales`
(
    `id` Int32,
    `user_id` Int32,
    `agent_id` Int32,
    `disabled` Bool,
    `last_seen` DateTime64(6, 'UTC'),
    `last_loggedin_branch_id` Int32 DEFAULT 0,
    `created_at` DateTime64(6, 'UTC'),
    `is_supersales` Bool,
    `updated_at` DateTime64(6, 'UTC'),
    `data_access_period` Int32 DEFAULT 0,
    `credit_limit` Decimal64(2),
    `last_confirmed_ticket_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `last_deposit_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `last_payout_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `last_withdraw_at` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `last_login` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `first_login` DateTime64(6, 'UTC') DEFAULT toDateTime(0),
    `offlinebet_sales_limit` Nullable(Decimal(10,2)),
    `branch_deposit_limit` Nullable(Decimal(10,2)),
    `is_mainstaff` Bool,
    `created_by_id` Int32 DEFAULT 0,
    `address` String DEFAULT '',
    `attached_document` String DEFAULT '',
    `city` LowCardinality(String) DEFAULT '',
    `note` String DEFAULT '',
    `phonenumber` Int32 DEFAULT 0,
    `state` String DEFAULT '',
    `branch_id` Int32 DEFAULT 0,
    `channel` Int32,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
PARTITION BY toYYYYMM(`created_at`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
