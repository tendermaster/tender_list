namespace :marketplace do
  desc 'Rewrite marketplace_pages (which pages products.sigmatenders.com serves and indexes)'
  task refresh_pages: :environment do
    puts Marketplace::PageRefresher.call.inspect
  end

  desc 'Re-apply the marketplace.* views (db/marketplace/views.sql)'
  task views: :environment do
    Marketplace::Views.apply!
    puts 'marketplace views applied'
  end

  desc 'Write db/marketplace/contract.json from the current views'
  task dump_contract: :environment do
    Marketplace::Views.dump_contract!
    puts "wrote #{Marketplace::Views::CONTRACT}"
  end

  desc 'Write db/marketplace/lead-request.schema.json from Lead validations'
  task dump_lead_schema: :environment do
    Marketplace::LeadSchema.dump!
    puts "wrote #{Marketplace::LeadSchema::FILE}"
  end

  # The role products-web connects as: read-only, the marketplace views only,
  # short statements, few connections. Password from PRODUCTS_WEB_DB_PASSWORD
  # (put the same value in products-web's DATABASE_URL); run again to change it.
  desc 'Create or update the products_web_ro database role'
  task db_role: :environment do
    password = ENV.fetch('PRODUCTS_WEB_DB_PASSWORD') { abort 'Set PRODUCTS_WEB_DB_PASSWORD' }
    abort 'PRODUCTS_WEB_DB_PASSWORD must be at least 24 characters' if password.size < 24

    conn = ActiveRecord::Base.connection
    quoted = conn.quote(password)
    exists = conn.select_value("SELECT 1 FROM pg_roles WHERE rolname = 'products_web_ro'")
    conn.execute("#{exists ? 'ALTER' : 'CREATE'} ROLE products_web_ro LOGIN PASSWORD #{quoted} CONNECTION LIMIT 10")
    conn.execute('ALTER ROLE products_web_ro SET statement_timeout = 5000')
    conn.execute('ALTER ROLE products_web_ro SET default_transaction_read_only = on')
    conn.execute("ALTER ROLE products_web_ro SET search_path = 'marketplace'")
    conn.execute("REVOKE ALL ON SCHEMA public FROM products_web_ro")
    Marketplace::Views.apply!(conn)
    puts 'products_web_ro ready: SELECT on marketplace.* only'
  end
end
