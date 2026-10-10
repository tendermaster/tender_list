# frozen_string_literal: true

# Portal dates in tenders are IST wall-clock time and created_at/updated_at are
# UTC. Two scrapers broke that until scrapers/v2 commit d61a71c (deployed
# 2026-10-10 19:14 UTC):
#
# - KPPP and Telangana parsed dates as Asia/Kolkata and stored the true UTC
#   instant, 5.5 h early. Both keep the portal's raw values in full_data, so
#   the dates are recomputed from there (KPPP's corrigendum stage never managed
#   to change a closing date: it wrote columns that don't exist).
# - From 16:26:34 IST to 00:44:43 IST (pm2 log) the worker ran in IST, so the
#   306 KPPP rows it inserted got IST created_at/updated_at.
class RepairScraperDates < ActiveRecord::Migration[8.0]
  KPPP_RAW = "'^\\d{2}-\\d{2}-\\d{4} \\d{2}:\\d{2}:\\d{2}$'"

  def up
    execute <<~SQL
      UPDATE tenders
      SET submission_open_date = CASE WHEN full_data::json->>'publishedDate' ~ #{KPPP_RAW}
            THEN to_timestamp(full_data::json->>'publishedDate', 'DD-MM-YYYY HH24:MI:SS')::timestamp
            ELSE submission_open_date END,
          submission_close_date = CASE WHEN full_data::json->>'tenderClosureDate' ~ #{KPPP_RAW}
            THEN to_timestamp(full_data::json->>'tenderClosureDate', 'DD-MM-YYYY HH24:MI:SS')::timestamp
            ELSE submission_close_date END
      WHERE tender_source = 'karnataka_kppp'
    SQL

    execute <<~SQL
      UPDATE tenders
      SET created_at = created_at - interval '5 hours 30 minutes',
          updated_at = updated_at - interval '5 hours 30 minutes'
      WHERE tender_source = 'karnataka_kppp'
        AND created_at >= '2026-10-10 16:26:34' AND id <= 6265249
    SQL

    # Telangana's full_data.dates hold the true UTC instant ("...T05:30:00Z" for
    # 11:00 IST); rows written after the fix are left alone.
    execute <<~SQL
      UPDATE tenders
      SET submission_open_date = COALESCE(
            (full_data::json->'dates'->>'submission_start')::timestamptz AT TIME ZONE 'Asia/Kolkata',
            submission_open_date),
          submission_close_date = COALESCE(
            (full_data::json->'dates'->>'submission_end')::timestamptz AT TIME ZONE 'Asia/Kolkata',
            submission_close_date)
      WHERE tender_source = 'telangana-eproc'
        AND updated_at < '2026-10-10 19:14:49'
        AND full_data::json->'dates'->>'submission_end' LIKE '%Z'
    SQL

    # One row from an earlier Telangana scraper used a different source name.
    execute <<~SQL
      UPDATE tenders SET tender_source = 'telangana-eproc'
      WHERE tender_source = 'Telangana eProcurement'
        AND NOT EXISTS (SELECT 1 FROM tenders t2
                        WHERE t2.tender_source = 'telangana-eproc' AND t2.tender_id = tenders.tender_id)
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
