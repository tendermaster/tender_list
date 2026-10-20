# frozen_string_literal: true

# Checks new migrations for operations that would lock big tables while they
# run (tenders is ~20 GB): e.g. adding an index without CONCURRENTLY.
# Migrations up to this one were written before the checks.
StrongMigrations.start_after = 20261020220000
StrongMigrations.target_version = 18
# Give up quickly on a lock instead of queueing every query behind it
StrongMigrations.lock_timeout = 10.seconds
