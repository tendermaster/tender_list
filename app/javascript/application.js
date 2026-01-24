// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
// import "@hotwired/turbo-rails";
// import "controllers";

$("#filter-search").on("click", () => {
  console.log("search");
  $("#main-search").val('')

  let q = $("#main-search").val() + ' '
  // let q = ''

  // $("input:checkbox:checked").each(function () {
  //   console.log(this.name);
  //   q += " or " + this.name + " ";
  // });

  $(".state-filter input:checkbox:checked").each(function () {
    console.log(this.name);
    q += "" + this.name + " ";
  });

  let sector = []
  $(".sector-filter input:checkbox:checked").each(function () {
    console.log(this.name);
    // q += "" + this.name + " ";
    sector.push(this.name)
  });

  if (sector.length > 0) {
    q += `(${sector.join(' | ')})`
  }

  let min_value = 0
  let max_value = 0

  const tender_filter = $("#tender-filter").val();
  const tender_value = $("#tender-value").val();
  let tender_value_amt = 0

  switch (tender_value) {
    case 'nil':
      tender_value_amt = 0
      break
    case '50l':
      tender_value_amt = 50 * 100000
      break
    case '1cr':
      tender_value_amt = 100 * 100000
      break
    case '5cr':
      tender_value_amt = 500 * 100000
      break
  }

  switch (tender_filter) {
    case 'lt':
      max_value = tender_value_amt
      break
    case 'gt':
      min_value = tender_value_amt
      max_value = 10 ** 10
  }

  const url = `${window.location.origin}/search?${$.param({
    q,
    min_value,
    max_value,
  })}`;
  window.location = url
  //   console.log(url);
});

$('.state-filter input[type="checkbox"]').on('change', function () {
  $('.state-filter input[type="checkbox"]').not(this).prop('checked', false);
});

if ($('.tlt').length) {
  setTimeout(() => {
    $('.tlt').textillate({ in: { effect: 'bounceIn' } });
  }, 2 * 1000);
}

$('#main-search-btn').on('click', (e) => {
  const query = $('#main-search').val()
  const userEmail = $('#user-email').text().trim()
  if (query.length) {
    // ahoy.track("user_search", {
    //   query: query,
    //   url: window.location.href,
    //   time: new Date().toString(),
    //   email: userEmail.length > 0 ? userEmail : null
    // });
  }
})

$('#nav-search-btn').on('click', (e) => {
  const query = $('#search-navbar').val()
  const userEmail = $('#user-email').text().trim()
  if (query.length) {
    // ahoy.track("user_search_nav", {
    //   query: query,
    //   url: window.location.href,
    //   time: new Date().toString(),
    //   email: userEmail.length > 0 ? userEmail : null
    // });
  }
})

const Toast = Swal.mixin({
  toast: true,
  position: "top-end",
  showConfirmButton: false,
  timer: 3000,
  timerProgressBar: true,
  didOpen: (toast) => {
    toast.onmouseenter = Swal.stopTimer;
    toast.onmouseleave = Swal.resumeTimer;
  }
});

const bookmarkBtn = $('#bookmark-btn')
const csrfToken = $('meta[name=csrf-token]').attr('content')
bookmarkBtn.on('click', (e) => {
  //   ajax like
  const pageId = bookmarkBtn.attr('data-page-id');
  $.ajax({
    url: '/tender/bookmark',
    type: 'POST',
    headers: {
      'X-CSRF-Token': csrfToken,
    },
    data: {
      pageId: pageId,
    },
    dataType: 'json',
    success: (function (data) {
      Toast.fire({
        icon: "success",
        title: data?.message,
        timer: 2000
      });

      // change color
      bookmarkBtn.toggleClass('bg-orange-600 text-white');
    })
  })
    .fail(function (error) {
      const errorMesssage = error?.responseJSON?.error
      Toast.fire({
        icon: "info",
        title: errorMesssage || 'Error'
      });
    })
})

// ─────────────────────────────────────────────────────────────────────────────
// Autocomplete functionality
// ─────────────────────────────────────────────────────────────────────────────

const autocomplete = {
  debounceTimer: null,
  debounceDelay: 300,
  minChars: 2,
  selectedIndex: -1,

  init() {
    const input = $('#main-search');
    const dropdown = $('#autocomplete-results');

    if (!input.length || !dropdown.length) return;

    // Input handler with debounce
    input.on('input', (e) => {
      const query = e.target.value.trim();

      clearTimeout(this.debounceTimer);
      this.selectedIndex = -1;

      if (query.length < this.minChars) {
        this.hideDropdown();
        return;
      }

      this.debounceTimer = setTimeout(() => {
        this.fetchSuggestions(query);
      }, this.debounceDelay);
    });

    // Keyboard navigation
    input.on('keydown', (e) => {
      const items = dropdown.find('.autocomplete-item');

      if (!items.length || dropdown.hasClass('hidden')) return;

      switch (e.key) {
        case 'ArrowDown':
          e.preventDefault();
          this.selectedIndex = Math.min(this.selectedIndex + 1, items.length - 1);
          this.highlightItem(items);
          break;
        case 'ArrowUp':
          e.preventDefault();
          this.selectedIndex = Math.max(this.selectedIndex - 1, -1);
          this.highlightItem(items);
          break;
        case 'Enter':
          if (this.selectedIndex >= 0) {
            e.preventDefault();
            const selectedItem = items.eq(this.selectedIndex);
            window.location.href = selectedItem.data('url');
          }
          break;
        case 'Escape':
          this.hideDropdown();
          break;
      }
    });

    // Hide on blur (with delay for click handling)
    input.on('blur', () => {
      setTimeout(() => this.hideDropdown(), 200);
    });

    // Show on focus if has value
    input.on('focus', (e) => {
      if (e.target.value.trim().length >= this.minChars) {
        this.fetchSuggestions(e.target.value.trim());
      }
    });

    // Click outside to close
    $(document).on('click', (e) => {
      if (!$(e.target).closest('#main-search, #autocomplete-results').length) {
        this.hideDropdown();
      }
    });
  },

  async fetchSuggestions(query) {
    try {
      const response = await $.ajax({
        url: '/search/autocomplete',
        data: { q: query },
        dataType: 'json'
      });

      this.renderSuggestions(response);
    } catch (error) {
      console.error('Autocomplete error:', error);
      this.hideDropdown();
    }
  },

  renderSuggestions(results) {
    const dropdown = $('#autocomplete-results');

    if (!results || results.length === 0) {
      this.hideDropdown();
      return;
    }

    const html = results.map((item, index) => {
      const isActive = item.is_active;
      const statusBadge = isActive
        ? '<span class="ml-2 inline-flex items-center rounded-full bg-green-100 px-2 py-0.5 text-xs font-medium text-green-800 dark:bg-green-900 dark:text-green-200">Active</span>'
        : '<span class="ml-2 inline-flex items-center rounded-full bg-gray-100 px-2 py-0.5 text-xs font-medium text-gray-600 dark:bg-gray-700 dark:text-gray-300">Closed</span>';

      return `
        <a href="/tender/${item.slug_uuid}" 
           class="autocomplete-item block px-4 py-3 hover:bg-gray-100 dark:hover:bg-gray-700 cursor-pointer border-b border-gray-100 dark:border-gray-700 last:border-b-0"
           data-url="/tender/${item.slug_uuid}"
           data-index="${index}">
          <div class="flex items-center justify-between">
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium text-gray-900 dark:text-white truncate">${this.escapeHtml(item.title)}</p>
              <p class="text-xs text-gray-500 dark:text-gray-400 truncate">${this.escapeHtml(item.organisation || '')} ${item.state ? '• ' + this.escapeHtml(item.state) : ''}</p>
            </div>
            ${statusBadge}
          </div>
        </a>
      `;
    }).join('');

    dropdown.html(html).removeClass('hidden');
  },

  highlightItem(items) {
    items.removeClass('bg-gray-100 dark:bg-gray-700');
    if (this.selectedIndex >= 0) {
      items.eq(this.selectedIndex).addClass('bg-gray-100 dark:bg-gray-700');
    }
  },

  hideDropdown() {
    $('#autocomplete-results').addClass('hidden').empty();
    this.selectedIndex = -1;
  },

  escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }
};

// Initialize autocomplete on page load
$(document).ready(() => {
  autocomplete.init();
});

