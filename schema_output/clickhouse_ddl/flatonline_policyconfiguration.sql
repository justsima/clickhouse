CREATE TABLE IF NOT EXISTS analytics.`flatonline_policyconfiguration`
(
    `configuration_ptr_id` Int32,
    `non_withdrawabable_placebet_policy_number_matches` Int32,
    `non_withdrawabable_placebet_policy_total_odd` Float64,
    `placebet_policy` Int32,
    `non_withdrawabable_placebet_policy_individual_odd` Float64,
    `online_agent_placebet_policy` Int32,
    `kiron_virtual_placebet_policy` Int32,
    `non_withdrawabable_placebet_policy_min_stake` Float64,
    `_version` UInt64 DEFAULT 0,
    `_is_deleted` UInt8 DEFAULT 0,
    `_extracted_at` DateTime DEFAULT now()
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (`configuration_ptr_id`)
SETTINGS clean_deleted_rows = 'Always',
         index_granularity = 8192;
