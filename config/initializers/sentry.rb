if Rails.env.production?
  Sentry.init do |config|
    config.dsn = 'https://cfb34b3025bc9bba8b42032f6ff518c6@o4507283422773248.ingest.us.sentry.io/4507283431227392'
    config.breadcrumbs_logger = %i[active_support_logger http_logger]

    # Errors are always reported. Performance tracing lives in OpenTelemetry, so
    # keep Sentry to errors only: tracing and stackprof-profiling every
    # request meant ~21k uploads a day and real CPU on a 2-vCPU host.
    config.traces_sample_rate = 0.0
    config.profiles_sample_rate = 0.0
  end
end
