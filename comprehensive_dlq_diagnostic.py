#!/usr/bin/env python3
"""
Comprehensive DLQ Diagnostic Tool
Analyzes Kafka DLQ messages to identify root causes of failures
with automatic Docker container management and multi-phase analysis
"""

import json
import re
import subprocess
import time
import sys
from collections import defaultdict, Counter
from datetime import datetime
from typing import Dict, List, Tuple, Optional
import os

# Color codes for output
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    CYAN = '\033[0;36m'
    MAGENTA = '\033[0;35m'
    NC = '\033[0m'  # No Color
    BOLD = '\033[1m'

# Configuration
CLICKHOUSE_PASSWORD = "ClickHouse_Secure_Pass_2024!"
CLICKHOUSE_USER = "default"
CLICKHOUSE_DATABASE = "analytics"
CONNECT_URL = "http://localhost:8085"
DLQ_TOPIC = "clickhouse-dlq"
SAMPLE_SIZE = 1000  # Number of DLQ messages to analyze

# Global flag to track if we need sudo for docker commands
USE_SUDO = False

# Required Docker containers
REQUIRED_CONTAINERS = {
    'redpanda-clickhouse': {'service': 'redpanda', 'wait_time': 30},
    'kafka-connect-clickhouse': {'service': 'kafka-connect', 'wait_time': 20},
    'clickhouse-server': {'service': 'clickhouse', 'wait_time': 15}
}

# Error categorization patterns
EXCEPTION_PATTERNS = {
    'SCHEMA_MISMATCH': [
        r'DataException',
        r'ClassCastException',
        r'SQLException.*conversion',
        r'SQLException.*type',
        r'Cannot convert',
        r'Type mismatch'
    ],
    'MISSING_TABLE': [
        r'SQLException.*Table.*not.*exist',
        r'SQLException.*Unknown table',
        r'table doesn\'t exist',
        r'no such table',
        r'Table .* not found'
    ],
    'PRIMARY_KEY': [
        r'DataException.*key',
        r'ConnectException.*primary',
        r'null key',
        r'key is required',
        r'key cannot be null',
        r'primary key constraint'
    ],
    'CONNECTION': [
        r'SQLException.*timeout',
        r'ConnectException',
        r'SocketTimeoutException',
        r'connection refused',
        r'unable to connect',
        r'network'
    ],
    'TRANSFORM': [
        r'TransformException',
        r'PatternSyntaxException',
        r'transform',
        r'regex.*failed',
        r'route.*error'
    ],
    'DATA_OVERFLOW': [
        r'out of range',
        r'overflow',
        r'exceeds maximum',
        r'too large',
        r'value.*out of bounds'
    ],
    'ENCODING': [
        r'encoding',
        r'charset',
        r'invalid character',
        r'UTF',
        r'character set'
    ]
}

KEYWORD_SCORES = {
    'SCHEMA_MISMATCH': {
        'keywords': ['cannot convert', 'type mismatch', 'incompatible', 'ClassCast', 'conversion'],
        'weight': 10
    },
    'MISSING_TABLE': {
        'keywords': ['table doesn\'t exist', 'unknown table', 'not found', 'no such table'],
        'weight': 15
    },
    'PRIMARY_KEY': {
        'keywords': ['null key', 'key is required', 'primary key', 'key cannot be null'],
        'weight': 12
    },
    'DATA_OVERFLOW': {
        'keywords': ['out of range', 'overflow', 'exceeds', 'too large'],
        'weight': 10
    },
    'ENCODING': {
        'keywords': ['encoding', 'charset', 'invalid character'],
        'weight': 8
    },
    'TRANSFORM': {
        'keywords': ['transform', 'regex', 'route', 'replacement'],
        'weight': 12
    },
    'CONNECTION': {
        'keywords': ['timeout', 'refused', 'unable to connect', 'network'],
        'weight': 10
    }
}


def print_header(text: str):
    """Print colored header"""
    print(f"\n{Colors.CYAN}{'=' * 80}{Colors.NC}")
    print(f"{Colors.CYAN}{Colors.BOLD}  {text}{Colors.NC}")
    print(f"{Colors.CYAN}{'=' * 80}{Colors.NC}\n")


def print_status(success: bool, message: str):
    """Print status message"""
    symbol = f"{Colors.GREEN}✓{Colors.NC}" if success else f"{Colors.RED}✗{Colors.NC}"
    print(f"{symbol} {message}")


def print_info(message: str):
    """Print info message"""
    print(f"{Colors.BLUE}ℹ{Colors.NC} {message}")


def print_warning(message: str):
    """Print warning message"""
    print(f"{Colors.YELLOW}⚠{Colors.NC} {message}")


def print_error(message: str):
    """Print error message"""
    print(f"{Colors.RED}✗ ERROR:{Colors.NC} {message}")


def run_command(cmd: List[str], capture_output=True, timeout=30, use_sudo=None) -> Tuple[bool, str]:
    """Run shell command and return success status and output"""
    global USE_SUDO

    # Determine if we should use sudo
    if use_sudo is None:
        use_sudo = USE_SUDO

    # Prepend sudo if needed and command is docker-related
    if use_sudo and len(cmd) > 0 and (cmd[0] == 'docker' or 'docker' in cmd[0]):
        cmd = ['sudo'] + cmd

    try:
        if capture_output:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=timeout
            )
            return result.returncode == 0, result.stdout
        else:
            result = subprocess.run(cmd, timeout=timeout)
            return result.returncode == 0, ""
    except subprocess.TimeoutExpired:
        return False, f"Command timed out after {timeout}s"
    except Exception as e:
        return False, str(e)


def detect_sudo_requirement() -> bool:
    """Detect if we need sudo to run docker commands"""
    # Try without sudo first
    result = subprocess.run(
        ['docker', 'ps'],
        capture_output=True,
        text=True,
        timeout=10
    )

    if result.returncode == 0:
        # Docker works without sudo
        return False
    else:
        # Try with sudo
        result = subprocess.run(
            ['sudo', 'docker', 'ps'],
            capture_output=True,
            text=True,
            timeout=10
        )
        if result.returncode == 0:
            # Docker works with sudo
            return True
        else:
            # Docker doesn't work at all
            return False


def check_docker_installed() -> bool:
    """Check if Docker is installed and configure sudo usage"""
    global USE_SUDO

    # First, detect if we need sudo
    USE_SUDO = detect_sudo_requirement()

    # Now check if docker is accessible
    success, _ = run_command(['docker', '--version'])

    if success and USE_SUDO:
        print_info("Docker requires sudo - running all docker commands with sudo")

    return success


def check_container_running(container_name: str) -> bool:
    """Check if a Docker container is running"""
    success, output = run_command(['docker', 'ps', '--filter', f'name={container_name}', '--format', '{{.Names}}'])
    return success and container_name in output


def start_container(container_name: str, wait_time: int) -> bool:
    """Start a Docker container and wait for it to be ready"""
    print_info(f"Starting container: {container_name}")

    success, _ = run_command(['docker', 'start', container_name])
    if not success:
        print_error(f"Failed to start {container_name}")
        return False

    print_info(f"Waiting {wait_time}s for {container_name} to be ready...")
    time.sleep(wait_time)

    return check_container_running(container_name)


def ensure_containers_running() -> bool:
    """Ensure all required Docker containers are running"""
    print_header("Phase 0: Docker Container Health Check")

    if not check_docker_installed():
        print_error("Docker is not installed or not accessible")
        return False

    print_status(True, "Docker is installed")

    all_running = True
    for container_name, config in REQUIRED_CONTAINERS.items():
        if check_container_running(container_name):
            print_status(True, f"{container_name} is running")
        else:
            print_warning(f"{container_name} is not running")
            if not start_container(container_name, config['wait_time']):
                all_running = False
            else:
                print_status(True, f"{container_name} started successfully")

    if not all_running:
        print_error("Some containers could not be started")
        return False

    # Additional health checks
    print_info("Performing health checks...")

    # Check Redpanda
    success, _ = run_command(['docker', 'exec', 'redpanda-clickhouse', 'rpk', 'cluster', 'health'])
    if success:
        print_status(True, "Redpanda cluster is healthy")
    else:
        print_warning("Redpanda cluster health check failed (may still be starting)")

    # Check ClickHouse
    success, _ = run_command([
        'docker', 'exec', 'clickhouse-server',
        'clickhouse-client', '--password', CLICKHOUSE_PASSWORD,
        '--query', 'SELECT 1'
    ])
    if success:
        print_status(True, "ClickHouse is responding")
    else:
        print_warning("ClickHouse health check failed")

    # Check Kafka Connect
    import urllib.request
    try:
        urllib.request.urlopen(f"{CONNECT_URL}/connectors", timeout=10)
        print_status(True, "Kafka Connect API is accessible")
    except:
        print_warning("Kafka Connect API not yet accessible (may still be starting)")
        print_info("Waiting additional 10s for Kafka Connect...")
        time.sleep(10)

    return True


def check_dlq_exists() -> bool:
    """Check if DLQ topic exists"""
    success, output = run_command([
        'docker', 'exec', 'redpanda-clickhouse',
        'rpk', 'topic', 'list'
    ])
    return success and DLQ_TOPIC in output


class DLQDiagnostic:
    """Main diagnostic class"""

    def __init__(self):
        self.dlq_messages = []
        self.errors_by_category = defaultdict(list)
        self.errors_by_table = defaultdict(list)
        self.errors_by_field = defaultdict(list)
        self.connector_config = {}
        self.clickhouse_tables = {}
        self.statistics = {}
        self.root_causes = []

    def run(self):
        """Run complete diagnostic"""
        print_header("COMPREHENSIVE DLQ DIAGNOSTIC ANALYSIS")
        print_info(f"Analysis started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print_info(f"Sample size: {SAMPLE_SIZE} messages")
        print()

        # Phase 0: Ensure containers are running
        if not ensure_containers_running():
            print_error("Cannot proceed - required containers are not running")
            sys.exit(1)

        # Phase 1: Data Collection
        if not self.phase1_data_collection():
            print_error("Data collection failed")
            return False

        # Phase 2: Error Header Parsing
        self.phase2_error_parsing()

        # Phase 3: Pattern Recognition
        self.phase3_pattern_recognition()

        # Phase 4: Cross-Reference Validation
        self.phase4_cross_validation()

        # Phase 5: Statistical Analysis
        self.phase5_statistical_analysis()

        # Phase 6: Root Cause Determination
        self.phase6_root_cause_determination()

        # Phase 7: Report Generation
        self.phase7_report_generation()

        return True

    def phase1_data_collection(self) -> bool:
        """Phase 1: Collect all necessary data"""
        print_header("Phase 1: Data Collection")

        # 1.1 Check if DLQ exists
        if not check_dlq_exists():
            print_error(f"DLQ topic '{DLQ_TOPIC}' does not exist")
            print_info("This might mean no errors have occurred yet, or DLQ is not configured")
            return False

        print_status(True, f"DLQ topic '{DLQ_TOPIC}' exists")

        # 1.2 Get DLQ topic info
        success, output = run_command([
            'docker', 'exec', 'redpanda-clickhouse',
            'rpk', 'topic', 'describe', DLQ_TOPIC
        ], timeout=60)

        if success:
            print_info("DLQ Topic Information:")
            for line in output.split('\n')[:10]:
                if line.strip():
                    print(f"    {line}")

        # 1.3 Fetch DLQ messages
        print_info(f"Fetching up to {SAMPLE_SIZE} DLQ messages...")
        success, output = run_command([
            'docker', 'exec', 'redpanda-clickhouse',
            'rpk', 'topic', 'consume', DLQ_TOPIC,
            '--num', str(SAMPLE_SIZE),
            '--format', 'json'
        ], timeout=120)

        if not success:
            print_error("Failed to fetch DLQ messages")
            return False

        # Parse messages
        message_count = 0
        for line in output.split('\n'):
            if line.strip():
                try:
                    msg = json.loads(line)
                    self.dlq_messages.append(msg)
                    message_count += 1
                except json.JSONDecodeError:
                    continue

        print_status(True, f"Collected {message_count} DLQ messages")

        if message_count == 0:
            print_error("No messages found in DLQ")
            return False

        # 1.4 Get connector configuration
        print_info("Fetching connector configuration...")
        try:
            import urllib.request
            req = urllib.request.Request(f"{CONNECT_URL}/connectors/clickhouse-sink-connector")
            with urllib.request.urlopen(req, timeout=10) as response:
                self.connector_config = json.loads(response.read())
                print_status(True, "Connector configuration retrieved")
        except Exception as e:
            print_warning(f"Could not fetch connector config: {e}")

        # 1.5 Get ClickHouse table schemas
        print_info("Fetching ClickHouse table schemas...")
        success, output = run_command([
            'docker', 'exec', 'clickhouse-server',
            'clickhouse-client', '--password', CLICKHOUSE_PASSWORD,
            '--query', f"SELECT name, engine FROM system.tables WHERE database = '{CLICKHOUSE_DATABASE}' FORMAT JSON"
        ])

        if success:
            try:
                result = json.loads(output)
                for row in result.get('data', []):
                    table_name = row['name']
                    self.clickhouse_tables[table_name] = {'engine': row['engine']}

                print_status(True, f"Found {len(self.clickhouse_tables)} tables in ClickHouse")
            except:
                print_warning("Could not parse ClickHouse table list")

        # 1.6 Get detailed schema for each table
        for table_name in self.clickhouse_tables.keys():
            success, output = run_command([
                'docker', 'exec', 'clickhouse-server',
                'clickhouse-client', '--password', CLICKHOUSE_PASSWORD,
                '--query', f"DESCRIBE TABLE {CLICKHOUSE_DATABASE}.{table_name} FORMAT JSON"
            ])

            if success:
                try:
                    schema = json.loads(output)
                    self.clickhouse_tables[table_name]['columns'] = schema.get('data', [])
                except:
                    pass

        return True

    def phase2_error_parsing(self):
        """Phase 2: Parse error headers and extract structured information"""
        print_header("Phase 2: Error Header Parsing")

        parsed_count = 0
        for msg in self.dlq_messages:
            headers = msg.get('headers', {})

            error_info = {
                'original_topic': headers.get('__connect.errors.topic', 'unknown'),
                'partition': headers.get('__connect.errors.partition', -1),
                'offset': headers.get('__connect.errors.offset', -1),
                'connector_name': headers.get('__connect.errors.connector.name', 'unknown'),
                'task_id': headers.get('__connect.errors.task.id', -1),
                'stage': headers.get('__connect.errors.stage', 'unknown'),
                'exception_class': headers.get('__connect.errors.exception.class.name', 'unknown'),
                'exception_message': headers.get('__connect.errors.exception.message', ''),
                'stacktrace': headers.get('__connect.errors.exception.stacktrace', ''),
                'value': msg.get('value', {}),
                'key': msg.get('key', {})
            }

            # Extract table name from topic
            if error_info['original_topic'] != 'unknown':
                # Pattern: mysql.database.table_name
                parts = error_info['original_topic'].split('.')
                if len(parts) >= 3:
                    error_info['table_name'] = parts[-1]
                else:
                    error_info['table_name'] = error_info['original_topic']
            else:
                error_info['table_name'] = 'unknown'

            # Extract field names from error message
            field_matches = re.findall(r'field[s]?\s+[\'"`]?(\w+)[\'"`]?', error_info['exception_message'], re.IGNORECASE)
            if field_matches:
                error_info['problematic_fields'] = field_matches
            else:
                error_info['problematic_fields'] = []

            msg['parsed_error'] = error_info
            parsed_count += 1

        print_status(True, f"Parsed {parsed_count} error messages")

    def phase3_pattern_recognition(self):
        """Phase 3: Pattern recognition and categorization"""
        print_header("Phase 3: Pattern Recognition & Categorization")

        categorized = 0
        uncategorized = 0

        for msg in self.dlq_messages:
            error = msg.get('parsed_error', {})
            exception_class = error.get('exception_class', '')
            exception_message = error.get('exception_message', '')
            stage = error.get('stage', '')

            # Combined text for matching
            search_text = f"{exception_class} {exception_message} {stage}"

            # Category scores
            category_scores = defaultdict(int)

            # Level 1: Exception class matching
            for category, patterns in EXCEPTION_PATTERNS.items():
                for pattern in patterns:
                    if re.search(pattern, search_text, re.IGNORECASE):
                        category_scores[category] += 15
                        break

            # Level 2: Keyword matching
            for category, config in KEYWORD_SCORES.items():
                for keyword in config['keywords']:
                    if keyword.lower() in search_text.lower():
                        category_scores[category] += config['weight']

            # Level 3: Stage-based hints
            if stage == 'VALUE_CONVERTER':
                category_scores['SCHEMA_MISMATCH'] += 5
            elif stage == 'TRANSFORMATION':
                category_scores['TRANSFORM'] += 10
            elif stage == 'TASK_PUT':
                # Could be various issues
                pass

            # Determine best category
            if category_scores:
                best_category = max(category_scores.items(), key=lambda x: x[1])
                error['category'] = best_category[0]
                error['confidence'] = min(100, best_category[1] * 5)  # Convert to percentage

                self.errors_by_category[best_category[0]].append(error)
                self.errors_by_table[error.get('table_name', 'unknown')].append(error)

                for field in error.get('problematic_fields', []):
                    self.errors_by_field[field].append(error)

                categorized += 1
            else:
                error['category'] = 'UNKNOWN'
                error['confidence'] = 0
                self.errors_by_category['UNKNOWN'].append(error)
                uncategorized += 1

        print_status(True, f"Categorized {categorized} errors")
        if uncategorized > 0:
            print_warning(f"{uncategorized} errors could not be categorized")

        # Print category breakdown
        print()
        print_info("Category Breakdown:")
        for category, errors in sorted(self.errors_by_category.items(), key=lambda x: len(x[1]), reverse=True):
            percentage = (len(errors) / len(self.dlq_messages)) * 100
            print(f"  {category:20s}: {len(errors):5d} ({percentage:5.1f}%)")

    def phase4_cross_validation(self):
        """Phase 4: Cross-reference validation"""
        print_header("Phase 4: Cross-Reference Validation")

        # 4.1 Validate missing tables
        if 'MISSING_TABLE' in self.errors_by_category:
            print_info("Validating missing tables...")
            missing_tables = set()
            for error in self.errors_by_category['MISSING_TABLE']:
                table_name = error.get('table_name', 'unknown')
                if table_name != 'unknown' and table_name not in self.clickhouse_tables:
                    missing_tables.add(table_name)

            if missing_tables:
                print_status(False, f"Confirmed {len(missing_tables)} missing tables:")
                for table in sorted(missing_tables):
                    print(f"    - {table}")
            else:
                print_warning("Tables exist but errors still occur - may be transform issue")

        # 4.2 Validate schema mismatches
        if 'SCHEMA_MISMATCH' in self.errors_by_category:
            print_info("Validating schema mismatches...")
            schema_issues = defaultdict(list)

            for error in self.errors_by_category['SCHEMA_MISMATCH']:
                table_name = error.get('table_name', 'unknown')
                fields = error.get('problematic_fields', [])

                if table_name in self.clickhouse_tables and fields:
                    for field in fields:
                        schema_issues[f"{table_name}.{field}"].append(error['exception_message'][:100])

            if schema_issues:
                print_status(False, f"Confirmed {len(schema_issues)} field-level schema issues:")
                for field_name, messages in list(schema_issues.items())[:10]:
                    print(f"    - {field_name}: {messages[0]}...")

        # 4.3 Validate primary key issues
        if 'PRIMARY_KEY' in self.errors_by_category:
            print_info("Validating primary key configuration...")
            config = self.connector_config.get('config', {})
            pk_mode = config.get('primary.key.mode', 'unknown')
            pk_fields = config.get('primary.key.fields', 'unknown')

            print(f"    Primary key mode: {pk_mode}")
            print(f"    Primary key fields: {pk_fields}")

            if pk_mode == 'record_key':
                print_warning("Using 'record_key' mode - this can cause issues with DELETE operations")

        # 4.4 Validate transforms
        if 'TRANSFORM' in self.errors_by_category:
            print_info("Validating transform configuration...")
            config = self.connector_config.get('config', {})
            transforms = config.get('transforms', '')

            if transforms:
                print(f"    Transforms configured: {transforms}")
                # Get transform configuration
                for key, value in config.items():
                    if key.startswith('transforms.'):
                        print(f"    {key}: {value}")

    def phase5_statistical_analysis(self):
        """Phase 5: Statistical analysis"""
        print_header("Phase 5: Statistical Analysis")

        total_errors = len(self.dlq_messages)

        # Top categories
        category_stats = []
        for category, errors in self.errors_by_category.items():
            count = len(errors)
            percentage = (count / total_errors) * 100
            category_stats.append({
                'category': category,
                'count': count,
                'percentage': percentage
            })

        category_stats.sort(key=lambda x: x['count'], reverse=True)

        # Top tables
        table_stats = []
        for table, errors in self.errors_by_table.items():
            count = len(errors)
            # Get primary category for this table
            categories = [e.get('category', 'UNKNOWN') for e in errors]
            primary_category = Counter(categories).most_common(1)[0][0] if categories else 'UNKNOWN'

            table_stats.append({
                'table': table,
                'count': count,
                'primary_category': primary_category
            })

        table_stats.sort(key=lambda x: x['count'], reverse=True)

        # Top fields
        field_stats = []
        for field, errors in self.errors_by_field.items():
            count = len(errors)
            field_stats.append({
                'field': field,
                'count': count
            })

        field_stats.sort(key=lambda x: x['count'], reverse=True)

        self.statistics = {
            'total_errors': total_errors,
            'categories': category_stats,
            'tables': table_stats[:20],  # Top 20
            'fields': field_stats[:20]    # Top 20
        }

        # Print statistics
        print_info(f"Total DLQ Messages Analyzed: {total_errors}")
        print()

        print(f"{Colors.BOLD}Top Error Categories:{Colors.NC}")
        print(f"{'Category':<25s} {'Count':>10s} {'Percentage':>12s}")
        print("-" * 50)
        for stat in category_stats[:5]:
            print(f"{stat['category']:<25s} {stat['count']:>10d} {stat['percentage']:>11.1f}%")
        print()

        print(f"{Colors.BOLD}Top Affected Tables:{Colors.NC}")
        print(f"{'Table':<30s} {'Count':>10s} {'Primary Error':>20s}")
        print("-" * 65)
        for stat in table_stats[:10]:
            print(f"{stat['table']:<30s} {stat['count']:>10d} {stat['primary_category']:>20s}")
        print()

        if field_stats:
            print(f"{Colors.BOLD}Top Problematic Fields:{Colors.NC}")
            print(f"{'Field Name':<30s} {'Count':>10s}")
            print("-" * 45)
            for stat in field_stats[:10]:
                print(f"{stat['field']:<30s} {stat['count']:>10d}")

    def phase6_root_cause_determination(self):
        """Phase 6: Determine root causes and rank by impact"""
        print_header("Phase 6: Root Cause Determination")

        root_causes = []

        # Analyze each category
        for category, errors in self.errors_by_category.items():
            if category == 'UNKNOWN' or len(errors) == 0:
                continue

            # Get affected tables
            tables = set(e.get('table_name', 'unknown') for e in errors)

            # Get sample error messages
            sample_messages = [e.get('exception_message', '')[:200] for e in errors[:3]]

            # Get affected fields
            fields = set()
            for e in errors:
                fields.update(e.get('problematic_fields', []))

            # Calculate impact score
            impact_score = len(errors) * len(tables)

            # Determine fix complexity
            fix_complexity = self._determine_fix_complexity(category, errors)

            root_cause = {
                'category': category,
                'error_count': len(errors),
                'percentage': (len(errors) / len(self.dlq_messages)) * 100,
                'affected_tables': sorted(tables),
                'affected_fields': sorted(fields),
                'sample_messages': sample_messages,
                'impact_score': impact_score,
                'fix_complexity': fix_complexity,
                'priority': self._calculate_priority(len(errors), len(tables), fix_complexity)
            }

            root_causes.append(root_cause)

        # Sort by priority (high to low)
        root_causes.sort(key=lambda x: x['priority'], reverse=True)

        self.root_causes = root_causes

        # Print top root causes
        print(f"{Colors.BOLD}TOP ROOT CAUSES (Ranked by Priority):{Colors.NC}\n")

        for i, cause in enumerate(root_causes[:5], 1):
            severity = self._get_severity_label(cause['percentage'])
            print(f"{Colors.BOLD}{i}. {severity}: {cause['category']}{Colors.NC} [{cause['percentage']:.1f}% of errors]")
            print(f"   Error Count: {cause['error_count']}")
            print(f"   Affected Tables: {len(cause['affected_tables'])} tables")
            if cause['affected_tables']:
                print(f"     - {', '.join(cause['affected_tables'][:5])}")
            if cause['affected_fields']:
                print(f"   Affected Fields: {', '.join(cause['affected_fields'][:10])}")
            print(f"   Fix Complexity: {cause['fix_complexity']}")
            print(f"   Sample Error: {cause['sample_messages'][0] if cause['sample_messages'] else 'N/A'}")
            print()

    def _determine_fix_complexity(self, category: str, errors: List) -> str:
        """Determine fix complexity"""
        if category == 'MISSING_TABLE':
            return 'EASY (Create tables)'
        elif category == 'PRIMARY_KEY':
            return 'EASY (Config change)'
        elif category == 'TRANSFORM':
            return 'MEDIUM (Fix transform pattern)'
        elif category == 'SCHEMA_MISMATCH':
            # Check if it's a common pattern
            messages = [e.get('exception_message', '') for e in errors]
            if any('DateTime' in m or 'Date' in m for m in messages):
                return 'MEDIUM (Alter column types)'
            return 'MEDIUM-HARD (Schema alignment)'
        elif category == 'CONNECTION':
            return 'MEDIUM (Config/network fix)'
        else:
            return 'UNKNOWN'

    def _calculate_priority(self, error_count: int, table_count: int, fix_complexity: str) -> float:
        """Calculate priority score"""
        complexity_weights = {
            'EASY (Create tables)': 1.5,
            'EASY (Config change)': 1.5,
            'MEDIUM (Fix transform pattern)': 1.0,
            'MEDIUM (Alter column types)': 1.0,
            'MEDIUM-HARD (Schema alignment)': 0.7,
            'MEDIUM (Config/network fix)': 1.0,
            'UNKNOWN': 0.5
        }

        weight = complexity_weights.get(fix_complexity, 0.5)
        return (error_count * table_count) * weight

    def _get_severity_label(self, percentage: float) -> str:
        """Get severity label based on percentage"""
        if percentage >= 50:
            return f"{Colors.RED}CRITICAL{Colors.NC}"
        elif percentage >= 20:
            return f"{Colors.YELLOW}HIGH{Colors.NC}"
        elif percentage >= 5:
            return f"{Colors.BLUE}MEDIUM{Colors.NC}"
        else:
            return "LOW"

    def phase7_report_generation(self):
        """Phase 7: Generate comprehensive report"""
        print_header("Phase 7: Report Generation")

        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        report_file = f"dlq_diagnostic_report_{timestamp}.txt"
        json_file = f"dlq_diagnostic_data_{timestamp}.json"

        # Generate text report
        with open(report_file, 'w') as f:
            f.write("=" * 80 + "\n")
            f.write("DLQ DIAGNOSTIC REPORT\n")
            f.write("=" * 80 + "\n\n")
            f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Total Messages Analyzed: {self.statistics['total_errors']}\n\n")

            f.write("EXECUTIVE SUMMARY\n")
            f.write("-" * 80 + "\n")
            f.write(f"Root Cause Breakdown:\n")
            for stat in self.statistics['categories'][:5]:
                f.write(f"  {stat['percentage']:5.1f}% - {stat['category']} ({stat['count']} errors)\n")
            f.write("\n")

            f.write("TOP ROOT CAUSES (Detailed)\n")
            f.write("-" * 80 + "\n\n")
            for i, cause in enumerate(self.root_causes[:5], 1):
                f.write(f"{i}. {cause['category']}\n")
                f.write(f"   Error Count: {cause['error_count']} ({cause['percentage']:.1f}%)\n")
                f.write(f"   Affected Tables: {', '.join(cause['affected_tables'][:10])}\n")
                if cause['affected_fields']:
                    f.write(f"   Affected Fields: {', '.join(cause['affected_fields'][:10])}\n")
                f.write(f"   Fix Complexity: {cause['fix_complexity']}\n")
                f.write(f"   Sample Error:\n")
                for msg in cause['sample_messages'][:2]:
                    f.write(f"     - {msg}\n")
                f.write("\n")

            # Recommendations
            f.write("RECOMMENDED ACTIONS\n")
            f.write("-" * 80 + "\n\n")
            for i, cause in enumerate(self.root_causes[:3], 1):
                f.write(f"{i}. Fix {cause['category']}\n")
                recommendations = self._generate_recommendations(cause)
                for rec in recommendations:
                    f.write(f"   {rec}\n")
                f.write("\n")

        print_status(True, f"Text report saved: {report_file}")

        # Generate JSON data export
        export_data = {
            'timestamp': datetime.now().isoformat(),
            'total_errors': self.statistics['total_errors'],
            'statistics': self.statistics,
            'root_causes': self.root_causes,
            'connector_config': self.connector_config.get('config', {})
        }

        with open(json_file, 'w') as f:
            json.dump(export_data, f, indent=2)

        print_status(True, f"JSON data saved: {json_file}")

        # Generate fix scripts
        self._generate_fix_scripts(timestamp)

        print()
        print_info(f"All reports saved in current directory")
        print_info(f"Review {report_file} for detailed analysis")

    def _generate_recommendations(self, cause: Dict) -> List[str]:
        """Generate specific recommendations for a root cause"""
        category = cause['category']
        recommendations = []

        if category == 'SCHEMA_MISMATCH':
            recommendations.append("→ Review ClickHouse table schemas and compare with MySQL")
            recommendations.append("→ Common fix: Change DateTime to DateTime64(3) for wider range")
            recommendations.append("→ Use String type for problematic fields temporarily")
            recommendations.append("→ Enable schema.evolution: 'basic' in connector config")

        elif category == 'MISSING_TABLE':
            recommendations.append("→ Create missing tables in ClickHouse before restarting connector")
            recommendations.append(f"→ Missing tables: {', '.join(cause['affected_tables'][:5])}")
            recommendations.append("→ Or: Enable auto.create.tables if supported")

        elif category == 'PRIMARY_KEY':
            recommendations.append("→ Change primary.key.mode from 'record_key' to 'record_value'")
            recommendations.append("→ Set primary.key.fields to your actual PK column (e.g., 'id')")
            recommendations.append("→ Update connector configuration and redeploy")

        elif category == 'TRANSFORM':
            recommendations.append("→ Review RegexRouter transform pattern")
            recommendations.append("→ Test pattern against actual topic names")
            recommendations.append("→ Example: 'mysql\\.([^.]+)\\.(.*)' -> '$2'")

        elif category == 'CONNECTION':
            recommendations.append("→ Increase connection timeout in JDBC URL")
            recommendations.append("→ Add connection pooling parameters")
            recommendations.append("→ Check ClickHouse server health and capacity")

        return recommendations

    def _generate_fix_scripts(self, timestamp: str):
        """Generate executable fix scripts"""

        # Generate SQL fix script
        sql_file = f"fix_schema_issues_{timestamp}.sql"
        with open(sql_file, 'w') as f:
            f.write("-- Auto-generated SQL fixes\n")
            f.write("-- Review before executing!\n\n")

            for cause in self.root_causes:
                if cause['category'] == 'SCHEMA_MISMATCH':
                    f.write("-- Fix DateTime range issues\n")
                    for table in cause['affected_tables'][:10]:
                        for field in cause['affected_fields']:
                            if 'date' in field.lower() or 'time' in field.lower():
                                f.write(f"ALTER TABLE {CLICKHOUSE_DATABASE}.{table} ")
                                f.write(f"MODIFY COLUMN {field} DateTime64(3);\n")
                    f.write("\n")

        print_status(True, f"SQL fix script saved: {sql_file}")

        # Generate connector config suggestions
        config_file = f"suggested_connector_config_{timestamp}.json"
        suggested_config = self.connector_config.get('config', {}).copy()

        for cause in self.root_causes:
            if cause['category'] == 'PRIMARY_KEY':
                suggested_config['primary.key.mode'] = 'record_value'
                suggested_config['primary.key.fields'] = 'id'
            elif cause['category'] == 'SCHEMA_MISMATCH':
                suggested_config['schema.evolution'] = 'basic'

        with open(config_file, 'w') as f:
            json.dump({'config': suggested_config}, f, indent=2)

        print_status(True, f"Suggested config saved: {config_file}")


def main():
    """Main entry point"""
    try:
        diagnostic = DLQDiagnostic()
        success = diagnostic.run()

        if success:
            print()
            print_header("DIAGNOSTIC COMPLETE")
            print_status(True, "Analysis completed successfully")
            print_info("Review the generated reports for detailed findings and recommendations")
            sys.exit(0)
        else:
            print_error("Diagnostic failed")
            sys.exit(1)

    except KeyboardInterrupt:
        print()
        print_warning("Diagnostic interrupted by user")
        sys.exit(130)
    except Exception as e:
        print_error(f"Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
