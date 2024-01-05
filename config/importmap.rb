# Pin npm packages by running ./bin/importmap

pin "application", preload: true
# pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
# FIX: problem with google oauth
# https://dev.to/rbazinet/hotwire-fix-for-cors-error-when-using-omniauth-3k36
# cors
#
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"
# pin "flowbite" # @1.6.2
# pin "@popperjs/core", to: "@popperjs--core.js" # @2.11.6
