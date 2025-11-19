CREATE TABLE IF NOT EXISTS analytics.`raffle_raffleconfiguration`
(
    `id` Int64,
    `send_raffle_ticket_generated_sms` Bool,
    `game_filter_strategy` String,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`id`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
